import Foundation
import Darwin

/// Usage of a finite resource (RAM or disk).
struct ResourceUsage {
    let usedBytes: Int64
    let totalBytes: Int64

    var percent: Double {
        totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100 : 0
    }
}

/// Reads system-wide CPU, memory and disk usage from the kernel.
final class SystemStats {
    private struct CPUTicks {
        let busy: UInt64
        let idle: UInt64
    }

    private var previousTicks: CPUTicks?

    /// Percentage of total CPU capacity used since the previous call (0 on the first call).
    func cpuUsage() -> Double {
        guard let ticks = Self.readCPUTicks() else { return 0 }
        defer { previousTicks = ticks }
        guard let previous = previousTicks else { return 0 }

        let busy = Double(ticks.busy - previous.busy)
        let total = busy + Double(ticks.idle - previous.idle)
        return total > 0 ? busy / total * 100 : 0
    }

    /// Same formula as Activity Monitor's "Memory Used": app memory + wired + compressed.
    func memoryUsage() -> ResourceUsage {
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return ResourceUsage(usedBytes: 0, totalBytes: total) }

        let appPages = Int64(stats.internal_page_count) - Int64(stats.purgeable_count)
        let usedPages = appPages + Int64(stats.wire_count) + Int64(stats.compressor_page_count)
        return ResourceUsage(usedBytes: usedPages * Int64(vm_kernel_page_size), totalBytes: total)
    }

    /// Startup volume usage. Purgeable space counts as free, matching Finder.
    func diskUsage() -> ResourceUsage {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let free = values.volumeAvailableCapacityForImportantUsage
        else { return ResourceUsage(usedBytes: 0, totalBytes: 0) }
        return ResourceUsage(usedBytes: Int64(total) - free, totalBytes: Int64(total))
    }

    private static func readCPUTicks() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let (user, system, idle, nice) = info.cpu_ticks
        return CPUTicks(busy: UInt64(user) + UInt64(system) + UInt64(nice), idle: UInt64(idle))
    }
}
