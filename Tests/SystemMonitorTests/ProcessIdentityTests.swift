import XCTest
@testable import SystemMonitor

final class ProcessIdentityTests: XCTestCase {
    func testHelperIsGroupedUnderOutermostApp() {
        let identity = ProcessIdentity.classify(
            path: "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/"
                + "Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)",
            processName: "Google Chrome He",
            responsiblePath: nil)

        XCTAssertEqual(identity.key, "/Applications/Google Chrome.app")
        XCTAssertEqual(identity.name, "Google Chrome")
        XCTAssertEqual(identity.kind, .app(bundlePath: "/Applications/Google Chrome.app"))
    }

    func testXPCServiceIsGroupedUnderResponsibleApp() {
        let identity = ProcessIdentity.classify(
            path: "/System/Library/Frameworks/WebKit.framework/Versions/A/XPCServices/"
                + "com.apple.WebKit.WebContent.xpc/Contents/MacOS/com.apple.WebKit.WebContent",
            processName: "com.apple.WebKi",
            responsiblePath: "/System/Applications/Calculator.app/Contents/MacOS/Calculator")

        XCTAssertEqual(identity.key, "/System/Applications/Calculator.app")
        XCTAssertEqual(identity.name, "Calculator")
    }

    func testWebContentWithoutResponsibleAppGetsFriendlyName() {
        let identity = ProcessIdentity.classify(
            path: "/System/Library/Frameworks/WebKit.framework/Versions/A/XPCServices/"
                + "com.apple.WebKit.WebContent.xpc/Contents/MacOS/com.apple.WebKit.WebContent",
            processName: "com.apple.WebKi",
            responsiblePath: nil)

        XCTAssertEqual(identity.key, "proc:com.apple.WebKit.WebContent")
        XCTAssertEqual(identity.name, L10n.webPages)
        XCTAssertEqual(identity.kind, .system)
    }

    func testCommandLineToolsAreGroupedByBinaryName() {
        let identity = ProcessIdentity.classify(path: "/opt/homebrew/bin/node", processName: "node", responsiblePath: nil)

        XCTAssertEqual(identity.key, "proc:node")
        XCTAssertEqual(identity.name, "node")
        XCTAssertEqual(identity.kind, .commandLine)
    }

    func testSystemProcesses() {
        XCTAssertEqual(ProcessIdentity.classify(path: "/usr/libexec/trustd", processName: "trustd", responsiblePath: nil).kind,
                       .system)
        XCTAssertEqual(ProcessIdentity.classify(path: "", processName: "kernel_task", responsiblePath: nil).name,
                       "kernel_task")
    }

    func testAppBundlePath() {
        XCTAssertEqual(ProcessIdentity.appBundlePath(in: "/Applications/Foo.app/Contents/MacOS/Foo"), "/Applications/Foo.app")
        XCTAssertNil(ProcessIdentity.appBundlePath(in: "/usr/bin/apparent"))
    }
}
