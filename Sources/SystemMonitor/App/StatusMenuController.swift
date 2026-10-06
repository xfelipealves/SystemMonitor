import AppKit

/// Owns the menu bar item and its menu, and refreshes both on a timer.
final class StatusMenuController: NSObject, NSMenuDelegate {
    private enum Config {
        static let refreshInterval: TimeInterval = 2
        static let memoryRows = 8
        static let cpuRows = 5
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let stats = SystemStats()
    private let sampler = ProcessSampler()
    private var timer: Timer?

    private var summaryItem = NSMenuItem()
    private var launchAtLoginItem = NSMenuItem()
    private var memoryItems: [NSMenuItem] = []
    private var cpuItems: [NSMenuItem] = []
    private var isMenuOpen = false

    func start() {
        statusItem.menu = buildMenu()
        refresh()

        let timer = Timer(timeInterval: Config.refreshInterval, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)  // .common keeps it ticking while the menu is open
        self.timer = timer
    }

    // MARK: - Building

    /// Builds the whole menu with the current language. Called again when the language changes.
    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        summaryItem = NSMenuItem()
        summaryItem.image = symbol("chart.bar")
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
        launchAtLoginItem = NSMenuItem(title: L10n.launchAtLogin, action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.image = symbol("power.circle")
        menu.addItem(launchAtLoginItem)
        menu.addItem(buildLanguageItem())

        let quitItem = NSMenuItem(title: L10n.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.image = symbol("power")
        menu.addItem(quitItem)
        return menu
    }

    private func buildLanguageItem() -> NSMenuItem {
        let submenu = NSMenu()
        for language in Language.allCases {
            let option = NSMenuItem(title: language.displayName, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            option.target = self
            option.representedObject = language
            option.state = language == L10n.language ? .on : .off
            submenu.addItem(option)
        }

        let item = NSMenuItem(title: L10n.languageMenu, action: nil, keyEquivalent: "")
        item.image = symbol("globe")
        item.submenu = submenu
        return item
    }

    private func makeProcessItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.target = self
        item.isHidden = true
        return item
    }

    private func symbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    // MARK: - Refreshing

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        refreshMenu()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }

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
        if isMenuOpen { refreshMenu() }
    }

    /// Updates items in place instead of rebuilding them, so the open menu never flickers.
    private func refreshMenu() {
        fill(memoryItems, with: sampler.topByMemory(limit: Config.memoryRows)) { Formatting.memory(Int64($0.memoryBytes)) }
        fill(cpuItems, with: sampler.topByCPU(limit: Config.cpuRows)) { Formatting.cpu($0.cpuPercent) }
        launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    private func fill(_ items: [NSMenuItem], with groups: [ProcessGroup], value: (ProcessGroup) -> String) {
        for (item, group) in zip(items, groups) {
            item.isHidden = false
            item.image = group.icon
            item.attributedTitle = Formatting.processTitle(name: group.name, value: value(group))
            item.representedObject = group
            item.action = group.canQuit ? #selector(quitProcessGroup(_:)) : nil
            item.toolTip = group.canQuit ? L10n.quitTooltip(processCount: group.pids.count) : L10n.protectedTooltip
        }
        items.dropFirst(groups.count).forEach { $0.isHidden = true }
    }

    // MARK: - Actions

    @objc private func quitProcessGroup(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? ProcessGroup else { return }

        let failures: Int
        switch Alerts.askHowToQuit(group) {
        case .quit: failures = ProcessTerminator.quit(group)
        case .forceQuit: failures = ProcessTerminator.forceQuit(group)
        case .cancel: return
        }
        if failures > 0 {
            Alerts.show(L10n.quitFailed(count: failures, name: group.name))
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if try LaunchAtLogin.toggle() == .needsApproval {
                Alerts.show(L10n.launchAtLoginApproval)
                LaunchAtLogin.openSystemSettings()
            }
        } catch {
            Alerts.show(L10n.launchAtLoginFailed(error.localizedDescription))
        }
        launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let language = sender.representedObject as? Language else { return }
        L10n.language = language
        statusItem.menu = buildMenu()
        refresh()
    }
}
