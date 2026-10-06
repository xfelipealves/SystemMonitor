import AppKit

enum Alerts {
    enum QuitChoice {
        case quit, forceQuit, cancel
    }

    /// "Quit" asks the app to close like ⌘Q; "Force Quit" ends it immediately.
    static func askHowToQuit(_ group: ProcessGroup) -> QuitChoice {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.icon = group.icon.copy() as? NSImage
        alert.icon?.size = NSSize(width: 64, height: 64)
        alert.messageText = L10n.quitTitle(group.name)
        alert.informativeText = L10n.quitMessage(processCount: group.pids.count)
        alert.addButton(withTitle: L10n.quitButton)
        alert.addButton(withTitle: L10n.forceQuitButton).hasDestructiveAction = true
        alert.addButton(withTitle: L10n.cancelButton).keyEquivalent = "\u{1b}"

        switch run(alert) {
        case .alertFirstButtonReturn: return .quit
        case .alertSecondButtonReturn: return .forceQuit
        default: return .cancel
        }
    }

    static func show(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        _ = run(alert)
    }

    /// Menu bar apps are never active, so bring the alert to the front first.
    private static func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApp.activate()
        return alert.runModal()
    }
}
