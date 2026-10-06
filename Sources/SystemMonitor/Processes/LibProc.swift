import Darwin

/// Thin wrappers over libproc for reading information about other processes.
enum LibProc {
    static func allPIDs() -> [pid_t] {
        let estimate = Int(proc_listallpids(nil, 0)) + 64  // headroom for processes spawned meanwhile
        var pids = [pid_t](repeating: 0, count: estimate)
        let count = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        return pids.prefix(Int(max(count, 0))).filter { $0 > 0 }
    }

    /// `nil` when the process can't be read, e.g. it belongs to another user.
    static func resourceUsage(of pid: pid_t) -> rusage_info_v4? {
        var usage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &usage) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return result == 0 ? usage : nil
    }

    static func executablePath(of pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        return proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 ? String(cString: buffer) : ""
    }

    static func name(of pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        proc_name(pid, &buffer, UInt32(buffer.count))
        return String(cString: buffer)
    }

    static func owner(of pid: pid_t) -> uid_t? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        return proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size ? info.pbi_uid : nil
    }

    /// The process an XPC service works for, e.g. Safari for its web page processes.
    static func responsiblePID(for pid: pid_t) -> pid_t? {
        guard let responsible = responsibilityFunction?(pid), responsible > 0, responsible != pid else { return nil }
        return responsible
    }

    /// Private libsystem function, looked up at runtime so the app keeps working if Apple removes it.
    private static let responsibilityFunction: ((pid_t) -> pid_t)? = {
        typealias Function = @convention(c) (pid_t) -> pid_t
        let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2)  // RTLD_DEFAULT
        guard let symbol = dlsym(defaultHandle, "responsibility_get_pid_responsible_for_pid") else { return nil }
        let function = unsafeBitCast(symbol, to: Function.self)
        return { function($0) }
    }()
}
