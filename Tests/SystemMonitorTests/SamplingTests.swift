import XCTest
@testable import SystemMonitor

/// Reads the real machine, so only sanity checks.
final class SamplingTests: XCTestCase {
    func testSystemStatsAreWithinRange() {
        let stats = SystemStats()
        _ = stats.cpuUsage()
        Thread.sleep(forTimeInterval: 0.2)

        XCTAssert((0...100).contains(stats.cpuUsage()))
        XCTAssert((0...100).contains(stats.memoryUsage().percent))
        XCTAssertGreaterThan(stats.memoryUsage().totalBytes, 0)
        XCTAssertGreaterThan(stats.diskUsage().totalBytes, 0)
    }

    func testResourceUsagePercent() {
        XCTAssertEqual(ResourceUsage(usedBytes: 25, totalBytes: 100).percent, 25)
        XCTAssertEqual(ResourceUsage(usedBytes: 10, totalBytes: 0).percent, 0)
    }

    func testSamplerFindsProcessesSortedByMemory() {
        let sampler = ProcessSampler()
        sampler.sample()
        let top = sampler.topByMemory(limit: 5)

        XCTAssertFalse(top.isEmpty)
        XCTAssertEqual(top.map(\.memoryBytes), top.map(\.memoryBytes).sorted(by: >))
        XCTAssertTrue(top.allSatisfy { !$0.pids.isEmpty })
    }
}
