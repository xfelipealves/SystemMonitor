import XCTest
@testable import SystemMonitor

final class LocalizationTests: XCTestCase {
    private var savedLanguage: Language!

    override func setUp() {
        savedLanguage = L10n.language
    }

    override func tearDown() {
        L10n.language = savedLanguage
    }

    func testSwitchingLanguageChangesStrings() {
        L10n.language = .english
        XCTAssertEqual(L10n.quitButton, "Quit")
        XCTAssertEqual(L10n.quitTitle("Safari"), "Quit “Safari”?")

        L10n.language = .portuguese
        XCTAssertEqual(L10n.quitButton, "Encerrar")
        XCTAssertEqual(L10n.quitTitle("Safari"), "Encerrar “Safari”?")
    }

    func testQuitMessageMentionsProcessCountOnlyForGroups() {
        L10n.language = .english
        XCTAssertFalse(L10n.quitMessage(processCount: 1).contains("processes"))
        XCTAssertTrue(L10n.quitMessage(processCount: 3).contains("3 processes"))
    }
}
