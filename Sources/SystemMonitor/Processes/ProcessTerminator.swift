import AppKit

/// Quits process groups. Both functions return how many processes could not be signaled.
enum ProcessTerminator {
    /// Asks politely: apps get the same request as ⌘Q (and may ask to save), other processes get SIGTERM.
    static func quit(_ group: ProcessGroup) -> Int {
        let pids = Set(livePIDs(of: group))
        let apps = NSWorkspace.shared.runningApplications.filter { pids.contains($0.processIdentifier) }
        guard apps.isEmpty else {
            return apps.filter { !$0.terminate() }.count  // helpers exit together with their app
        }
        return send(SIGTERM, to: pids)
    }

    /// Ends every process of the group immediately. Unsaved changes are lost.
    static func forceQuit(_ group: ProcessGroup) -> Int {
        send(SIGKILL, to: livePIDs(of: group))
    }

    /// Skips PIDs that were reused by another program since the group was sampled.
    private static func livePIDs(of group: ProcessGroup) -> [pid_t] {
        group.pids.filter { ProcessIdentity.of(pid: $0).key == group.key }
    }

    private static func send<PIDs: Sequence>(_ signal: Int32, to pids: PIDs) -> Int where PIDs.Element == pid_t {
        pids.filter { kill($0, signal) != 0 }.count
    }
}
