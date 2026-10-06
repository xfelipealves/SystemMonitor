import AppKit
import Darwin

/// One app (with all its helper processes) or one group of same-named command-line processes.
struct ProcessGroup {
    /// Outermost `.app` bundle path, or `proc:<name>` for processes outside an app bundle.
    let key: String
    let name: String
    let icon: NSImage
    var pids: [pid_t] = []
    /// Physical footprint in bytes, the "Memory" column of Activity Monitor.
    var memoryBytes: UInt64 = 0
    /// Percent of one core, so it can exceed 100% like in Activity Monitor.
    var cpuPercent: Double = 0
    var canForceQuit = true
}

/// Samples memory and CPU of every process the current user can read, grouped by app.
final class ProcessSampler {
    /// Killing these logs the user out or breaks the session.
    private static let protectedNames: Set<String> = ["loginwindow", "WindowServer", "launchd", "kernel_task"]

    /// Private libsystem function that maps an XPC service to the app it works for.
    /// Looked up at runtime so the app keeps working if Apple ever removes it.
    private static let responsiblePID: ((pid_t) -> pid_t)? = {
        typealias Function = @convention(c) (pid_t) -> pid_t
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid")
        else { return nil }
        let function = unsafeBitCast(symbol, to: Function.self)
        return { function($0) }
    }()

    private(set) var groups: [ProcessGroup] = []

    private var previousCPUTime: [pid_t: UInt64] = [:]
    private var previousSampleTime: UInt64 = 0
    private var iconCache: [String: NSImage] = [:]
    private let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// Refreshes `groups`. CPU usage is measured between consecutive calls.
    func sample() {
        let now = mach_absolute_time()
        let elapsedNanos = previousSampleTime == 0 ? 0 : Double(nanoseconds(now - previousSampleTime))
        let currentUser = getuid()
        let ownPID = getpid()

        var groupsByKey: [String: ProcessGroup] = [:]
        var cpuTimes: [pid_t: UInt64] = [:]

        for pid in Self.allPIDs() where pid != ownPID {
            guard let usage = Self.resourceUsage(of: pid) else { continue }  // not readable: another user's process

            let cpuTime = nanoseconds(usage.ri_user_time + usage.ri_system_time)
            cpuTimes[pid] = cpuTime
            var cpuPercent = 0.0
            if let previous = previousCPUTime[pid], elapsedNanos > 0, cpuTime >= previous {
                cpuPercent = Double(cpuTime - previous) / elapsedNanos * 100
            }

            let identity = Self.identity(of: pid)
            var group = groupsByKey[identity.key]
                ?? ProcessGroup(key: identity.key, name: identity.name, icon: icon(for: identity))
            group.pids.append(pid)
            group.memoryBytes += usage.ri_phys_footprint
            group.cpuPercent += cpuPercent
            if Self.owner(of: pid) != currentUser || Self.protectedNames.contains(Self.name(of: pid)) {
                group.canForceQuit = false
            }
            groupsByKey[identity.key] = group
        }

        previousCPUTime = cpuTimes
        previousSampleTime = now
        groups = Array(groupsByKey.values)
    }

    func topByMemory(limit: Int) -> [ProcessGroup] {
        Array(groups.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(limit))
    }

    func topByCPU(limit: Int) -> [ProcessGroup] {
        Array(groups.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(limit))
    }

    /// Sends SIGKILL to every process still in the group. Returns how many could not be killed.
    func forceQuit(_ group: ProcessGroup) -> Int {
        // Re-check identity so a PID reused since the last sample is never killed.
        let targets = group.pids.filter { Self.identity(of: $0).key == group.key }
        return targets.filter { kill($0, SIGKILL) != 0 }.count
    }

    // MARK: - Helpers

    private func nanoseconds(_ machTicks: UInt64) -> UInt64 {
        machTicks * UInt64(timebase.numer) / UInt64(timebase.denom)
    }

    private func icon(for identity: Identity) -> NSImage {
        let cacheKey = identity.bundlePath ?? identity.symbolName
        if let cached = iconCache[cacheKey] { return cached }

        let icon: NSImage
        if let bundlePath = identity.bundlePath {
            icon = NSWorkspace.shared.icon(forFile: bundlePath).copy() as! NSImage
        } else {
            icon = NSImage(systemSymbolName: identity.symbolName, accessibilityDescription: nil) ?? NSImage()
        }
        icon.size = NSSize(width: 16, height: 16)
        iconCache[cacheKey] = icon
        return icon
    }

    // MARK: - libproc wrappers

    private static func allPIDs() -> [pid_t] {
        let estimate = Int(proc_listallpids(nil, 0)) + 64  // headroom for processes spawned meanwhile
        var pids = [pid_t](repeating: 0, count: estimate)
        let count = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        return pids.prefix(Int(max(count, 0))).filter { $0 > 0 }
    }

    private static func resourceUsage(of pid: pid_t) -> rusage_info_v4? {
        var usage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &usage) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return result == 0 ? usage : nil
    }

    private struct Identity {
        let key: String
        let name: String
        /// App bundle whose icon represents the group, if any.
        let bundlePath: String?
        /// SF Symbol used when there is no bundle.
        var symbolName = "terminal"
    }

    /// Groups processes with the app they belong to:
    /// - helpers inside the bundle ("Google Chrome.app/.../Google Chrome Helper")
    /// - XPC services working for the app (Safari's WebKit web page processes)
    private static func identity(of pid: pid_t) -> Identity {
        let path = executablePath(of: pid)
        if let bundlePath = appBundlePath(in: path) {
            return appIdentity(bundlePath)
        }
        if path.contains(".xpc/"), let owner = responsiblePID?(pid), owner > 0, owner != pid,
           let bundlePath = appBundlePath(in: executablePath(of: owner)) {
            return appIdentity(bundlePath)
        }

        let binaryName = path.isEmpty ? name(of: pid) : (path as NSString).lastPathComponent
        let isSystem = path.isEmpty || ["/System/", "/usr/", "/Library/Apple/"].contains { path.hasPrefix($0) }
        let displayName = binaryName == "com.apple.WebKit.WebContent" ? L10n.webPages : binaryName
        return Identity(key: "proc:" + binaryName, name: displayName, bundlePath: nil,
                        symbolName: isSystem ? "gearshape" : "terminal")
    }

    private static func appIdentity(_ bundlePath: String) -> Identity {
        var name = FileManager.default.displayName(atPath: bundlePath)
        if name.hasSuffix(".app") { name.removeLast(4) }
        return Identity(key: bundlePath, name: name, bundlePath: bundlePath)
    }

    /// "/Applications/Foo.app/Contents/..." -> "/Applications/Foo.app" (outermost bundle).
    private static func appBundlePath(in path: String) -> String? {
        guard let range = path.range(of: ".app/") else { return nil }
        return String(path[..<range.lowerBound]) + ".app"
    }

    private static func executablePath(of pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        return proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 ? String(cString: buffer) : ""
    }

    private static func name(of pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        proc_name(pid, &buffer, UInt32(buffer.count))
        return String(cString: buffer)
    }

    private static func owner(of pid: pid_t) -> uid_t? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        return proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size ? info.pbi_uid : nil
    }
}
