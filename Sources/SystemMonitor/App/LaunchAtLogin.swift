import ServiceManagement

enum LaunchAtLogin {
    enum Result {
        case done, needsApproval
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Turns opening at login on or off. macOS may ask the user to approve it first.
    static func toggle() throws -> Result {
        let service = SMAppService.mainApp
        if service.status == .enabled {
            try service.unregister()
        } else {
            try service.register()
        }
        return service.status == .requiresApproval ? .needsApproval : .done
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
