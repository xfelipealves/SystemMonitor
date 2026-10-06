import AppKit
import Darwin

/// One app with all its helper processes, or all same-named command-line processes.
struct ProcessGroup {
    let key: String
    let name: String
    let icon: NSImage
    var pids: [pid_t] = []
    /// Physical footprint in bytes, the "Memory" column of Activity Monitor.
    var memoryBytes: UInt64 = 0
    /// Percent of one core, so it can exceed 100% like in Activity Monitor.
    var cpuPercent: Double = 0
    var canQuit = true
}

/// Samples memory and CPU of every process the current user can read, grouped by app.
final class ProcessSampler {
    /// Quitting these logs the user out or breaks the session.
    private static let protectedNames: Set<String> = ["loginwindow", "WindowServer", "launchd", "kernel_task"]

    private(set) var groups: [ProcessGroup] = []

    private var previousCPUTime: [pid_t: UInt64] = [:]
    private var previousSampleTime: UInt64 = 0
    private var iconCache: [String: NSImage] = [:]
    private let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// Refreshes `groups`. CPU usage is measured between consecutive calls, so it is 0 on the first one.
    func sample() {
        let now = mach_absolute_time()
        let elapsedNanos = previousSampleTime == 0 ? 0 : Double(nanoseconds(now - previousSampleTime))
        let currentUser = getuid()
        let ownPID = getpid()

        var groupsByKey: [String: ProcessGroup] = [:]
        var cpuTimes: [pid_t: UInt64] = [:]

        for pid in LibProc.allPIDs() where pid != ownPID {
            guard let usage = LibProc.resourceUsage(of: pid) else { continue }

            let cpuTime = nanoseconds(usage.ri_user_time + usage.ri_system_time)
            cpuTimes[pid] = cpuTime
            var cpuPercent = 0.0
            if let previous = previousCPUTime[pid], elapsedNanos > 0, cpuTime >= previous {
                cpuPercent = Double(cpuTime - previous) / elapsedNanos * 100
            }

            let identity = ProcessIdentity.of(pid: pid)
            var group = groupsByKey[identity.key]
                ?? ProcessGroup(key: identity.key, name: identity.name, icon: icon(for: identity))
            group.pids.append(pid)
            group.memoryBytes += usage.ri_phys_footprint
            group.cpuPercent += cpuPercent
            if LibProc.owner(of: pid) != currentUser || Self.protectedNames.contains(LibProc.name(of: pid)) {
                group.canQuit = false
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

    private func nanoseconds(_ machTicks: UInt64) -> UInt64 {
        machTicks * UInt64(timebase.numer) / UInt64(timebase.denom)
    }

    private func icon(for identity: ProcessIdentity) -> NSImage {
        if let cached = iconCache[identity.key] { return cached }

        let icon: NSImage
        switch identity.kind {
        case .app(let bundlePath):
            icon = NSWorkspace.shared.icon(forFile: bundlePath).copy() as! NSImage
        case .commandLine:
            icon = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil) ?? NSImage()
        case .system:
            icon = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil) ?? NSImage()
        }
        icon.size = NSSize(width: 16, height: 16)
        iconCache[identity.key] = icon
        return icon
    }
}
