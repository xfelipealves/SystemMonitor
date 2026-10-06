import AppKit
import Darwin
import UniformTypeIdentifiers

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

    /// Friendly names for processes whose binary name means little to users.
    private static let displayNames = ["com.apple.WebKit.WebContent": "Páginas web (Safari e apps)"]

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
                ?? ProcessGroup(key: identity.key, name: identity.name, icon: icon(forBundle: identity.bundlePath))
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

    private func icon(forBundle bundlePath: String?) -> NSImage {
        let cacheKey = bundlePath ?? ""
        if let cached = iconCache[cacheKey] { return cached }

        let source = bundlePath.map { NSWorkspace.shared.icon(forFile: $0) }
            ?? NSWorkspace.shared.icon(for: .unixExecutable)
        let icon = source.copy() as! NSImage
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

    /// Groups helpers with their app: Chrome helpers live inside "Google Chrome.app".
    private static func identity(of pid: pid_t) -> (key: String, name: String, bundlePath: String?) {
        let path = executablePath(of: pid)
        if let appRange = path.range(of: ".app/") {
            let bundlePath = String(path[..<appRange.lowerBound]) + ".app"
            var name = FileManager.default.displayName(atPath: bundlePath)
            if name.hasSuffix(".app") { name.removeLast(4) }
            return (bundlePath, name, bundlePath)
        }

        let binaryName = path.isEmpty ? name(of: pid) : (path as NSString).lastPathComponent
        return ("proc:" + binaryName, displayNames[binaryName] ?? binaryName, nil)
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
