import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum Config {
        static let refreshInterval: TimeInterval = 2
        static let memoryRows = 8
        static let cpuRows = 5
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let stats = SystemStats()
    private let sampler = ProcessSampler()

    private let summaryItem = NSMenuItem()
    private let launchAtLoginItem = NSMenuItem()
    private var memoryItems: [NSMenuItem] = []
    private var cpuItems: [NSMenuItem] = []
    private var isMenuOpen = false
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.menu = buildMenu()
        refresh()

        let timer = Timer(timeInterval: Config.refreshInterval, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)  // .common keeps it ticking while the menu is open
        self.timer = timer
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        summaryItem.image = NSImage(systemSymbolName: "chart.bar", accessibilityDescription: nil)
        menu.addItem(summaryItem)

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: L10n.topMemoryHeader))
        memoryItems = (0..<Config.memoryRows).map { _ in makeProcessItem() }
        memoryItems.forEach(menu.addItem)

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: L10n.topCPUHeader))
        cpuItems = (0..<Config.cpuRows).map { _ in makeProcessItem() }
        cpuItems.forEach(menu.addItem)

        menu.addItem(.separator())
        launchAtLoginItem.title = L10n.launchAtLogin
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        launchAtLoginItem.target = self
        launchAtLoginItem.image = NSImage(systemSymbolName: "power.circle", accessibilityDescription: nil)
        menu.addItem(launchAtLoginItem)
        menu.addItem(buildLanguageMenu())

        let quitItem = NSMenuItem(title: L10n.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)
        return menu
    }

    private func buildLanguageMenu() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.languageMenu, action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        let submenu = NSMenu()
        for language in Language.allCases {
            let option = NSMenuItem(title: language.displayName, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            option.target = self
            option.representedObject = language.rawValue
            option.state = language == L10n.language ? .on : .off
            submenu.addItem(option)
        }
        item.submenu = submenu
        return item
    }

    private func makeProcessItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.target = self
        item.isHidden = true
        return item
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        refreshMenu()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }

    // MARK: - Refresh

    private func refresh() {
        let cpu = stats.cpuUsage()
        let memory = stats.memoryUsage()
        let disk = stats.diskUsage()

        statusItem.button?.attributedTitle = Formatting.statusTitle([
            ("cpu", cpu),
            ("memorychip", memory.percent),
            ("internaldrive", disk.percent),
        ])
        summaryItem.title = L10n.summary(memoryUsed: Formatting.memory(memory.usedBytes),
                                         memoryTotal: Formatting.memory(memory.totalBytes),
                                         diskUsed: Formatting.disk(disk.usedBytes),
                                         diskTotal: Formatting.disk(disk.totalBytes))

        sampler.sample()
        if isMenuOpen { refreshMenu() }  // update items in place, so the menu never flickers
    }

    private func refreshMenu() {
        fill(memoryItems, with: sampler.topByMemory(limit: Config.memoryRows)) {
            Formatting.memory(Int64($0.memoryBytes))
        }
        fill(cpuItems, with: sampler.topByCPU(limit: Config.cpuRows)) {
            Formatting.cpu($0.cpuPercent)
        }
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    private func fill(_ items: [NSMenuItem], with groups: [ProcessGroup], value: (ProcessGroup) -> String) {
        for (item, group) in zip(items, groups) {
            item.isHidden = false
            item.image = group.icon
            item.attributedTitle = Formatting.processTitle(name: group.name, value: value(group))
            item.representedObject = group
            item.action = group.canForceQuit ? #selector(confirmForceQuit(_:)) : nil
            item.toolTip = group.canForceQuit ? L10n.forceQuitTooltip(processCount: group.pids.count) : L10n.protectedTooltip
        }
        items.dropFirst(groups.count).forEach { $0.isHidden = true }
    }

    // MARK: - Actions

    @objc private func confirmForceQuit(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? ProcessGroup else { return }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.icon = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
        alert.messageText = L10n.forceQuitTitle(group.name)
        alert.informativeText = L10n.forceQuitMessage(processCount: group.pids.count)
        alert.addButton(withTitle: L10n.forceQuitButton)
        alert.addButton(withTitle: L10n.cancelButton)

        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let failures = sampler.forceQuit(group)
        if failures > 0 {
            showMessage(L10n.forceQuitFailed(count: failures, name: group.name))
        }
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            showMessage(L10n.launchAtLoginFailed(error.localizedDescription))
        }

        if service.status == .requiresApproval {
            showMessage(L10n.launchAtLoginApproval)
            SMAppService.openSystemSettingsLoginItems()
        }
        launchAtLoginItem.state = service.status == .enabled ? .on : .off
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String, let language = Language(rawValue: code) else { return }
        L10n.language = language
        statusItem.menu?.removeAllItems()  // reused items can't belong to two menus
        statusItem.menu = buildMenu()  // titles are set when items are built
        refresh()
    }

    private func showMessage(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        NSApp.activate()
        alert.runModal()
    }
}
