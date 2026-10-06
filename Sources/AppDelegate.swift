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
    private let launchAtLoginItem = NSMenuItem(title: "Abrir ao iniciar o Mac",
                                               action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
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
        menu.addItem(.sectionHeader(title: "Mais usam memória — clique para forçar encerramento"))
        memoryItems = (0..<Config.memoryRows).map { _ in makeProcessItem() }
        memoryItems.forEach(menu.addItem)

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Mais usam CPU"))
        cpuItems = (0..<Config.cpuRows).map { _ in makeProcessItem() }
        cpuItems.forEach(menu.addItem)

        menu.addItem(.separator())
        launchAtLoginItem.target = self
        launchAtLoginItem.image = NSImage(systemSymbolName: "power.circle", accessibilityDescription: nil)
        menu.addItem(launchAtLoginItem)

        let quitItem = NSMenuItem(title: "Sair", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)
        return menu
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
        summaryItem.title = "RAM \(Formatting.memory(memory.usedBytes)) / \(Formatting.memory(memory.totalBytes))"
            + "   ·   Disco \(Formatting.disk(disk.usedBytes)) / \(Formatting.disk(disk.totalBytes))"

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
            item.toolTip = group.canForceQuit
                ? "Clique para forçar o encerramento (\(group.pids.count) processo(s))"
                : "Processo do sistema — não pode ser encerrado"
        }
        items.dropFirst(groups.count).forEach { $0.isHidden = true }
    }

    // MARK: - Actions

    @objc private func confirmForceQuit(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? ProcessGroup else { return }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.icon = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
        alert.messageText = "Forçar encerramento de \"\(group.name)\"?"
        alert.informativeText = group.pids.count > 1
            ? "\(group.pids.count) processos serão encerrados. Alterações não salvas serão perdidas."
            : "Alterações não salvas serão perdidas."
        alert.addButton(withTitle: "Forçar Encerramento")
        alert.addButton(withTitle: "Cancelar")

        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let failures = sampler.forceQuit(group)
        if failures > 0 {
            showMessage("Não foi possível encerrar \(failures) processo(s) de \"\(group.name)\".")
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
            showMessage("Não foi possível alterar o início automático: \(error.localizedDescription)")
        }

        if service.status == .requiresApproval {
            showMessage("Aprove o SystemMonitor em Ajustes do Sistema → Geral → Itens de Início.")
            SMAppService.openSystemSettingsLoginItems()
        }
        launchAtLoginItem.state = service.status == .enabled ? .on : .off
    }

    private func showMessage(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        NSApp.activate()
        alert.runModal()
    }
}
