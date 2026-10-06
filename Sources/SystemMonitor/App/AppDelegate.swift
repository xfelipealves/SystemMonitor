import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusMenuController()
        controller?.start()
    }
}
