import XCTest
@testable import SystemMonitor

final class FormattingTests: XCTestCase {
    private let english = Locale(identifier: "en_US")
    private let portuguese = Locale(identifier: "pt_BR")

    func testAlertColorThresholds() {
        XCTAssertNil(Formatting.alertColor(for: 74.9))
        XCTAssertEqual(Formatting.alertColor(for: 75), .systemYellow)
        XCTAssertEqual(Formatting.alertColor(for: 89.9), .systemYellow)
        XCTAssertEqual(Formatting.alertColor(for: 90), .systemRed)
    }

    func testCPUFollowsAppLanguage() {
        XCTAssertEqual(Formatting.cpu(84.25, locale: english), "84.2%")
        XCTAssertEqual(Formatting.cpu(84.25, locale: portuguese), "84,2%")
        XCTAssertEqual(Formatting.cpu(150, locale: english), "150.0%")  // more than one core
    }

    func testBytesUseDecimalSeparatorOfAppLanguage() {
        let bytes: Int64 = 1_610_612_736  // 1.5 GiB
        XCTAssertTrue(Formatting.memory(bytes, locale: english).contains("1.5"))
        XCTAssertTrue(Formatting.memory(bytes, locale: portuguese).contains("1,5"))
    }

    func testTruncation() {
        XCTAssertEqual(Formatting.truncated("Short", to: 10), "Short")
        XCTAssertEqual(Formatting.truncated("A very long process name", to: 10), "A very lo…")
    }

    func testStatusTitleShowsEveryMetric() {
        let title = Formatting.statusTitle([("cpu", 5), ("memorychip", 81), ("internaldrive", 92)]).string
        XCTAssertTrue(title.contains(" 5%"))
        XCTAssertTrue(title.contains("81%"))
        XCTAssertTrue(title.contains("92%"))
    }
}
