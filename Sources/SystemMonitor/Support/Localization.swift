import Foundation

enum Language: String, CaseIterable {
    case english = "en"
    case portuguese = "pt-BR"

    /// Shown in each language's own name, so it is recognizable whatever language is active.
    var displayName: String {
        switch self {
        case .english: "English"
        case .portuguese: "Português (Brasil)"
        }
    }

    /// Used to format numbers: "84.2%" in English, "84,2%" in Portuguese.
    var locale: Locale {
        switch self {
        case .english: Locale(identifier: "en_US")
        case .portuguese: Locale(identifier: "pt_BR")
        }
    }
}

/// User-facing strings. English is the default; the choice is saved in UserDefaults.
enum L10n {
    private static let languageKey = "language"

    static var language: Language {
        get { UserDefaults.standard.string(forKey: languageKey).flatMap(Language.init) ?? .english }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: languageKey) }
    }

    // MARK: Menu

    static func summary(memoryUsed: String, memoryTotal: String, diskUsed: String, diskTotal: String) -> String {
        "RAM \(memoryUsed) / \(memoryTotal)   ·   \(text("Disk", "Disco")) \(diskUsed) / \(diskTotal)"
    }

    static var topMemoryHeader: String { text("Top memory — click to quit", "Mais usam memória — clique para encerrar") }
    static var topCPUHeader: String { text("Top CPU", "Mais usam CPU") }
    static var launchAtLogin: String { text("Open at Login", "Abrir ao iniciar o Mac") }
    static var languageMenu: String { text("Language", "Idioma") }
    static var quit: String { text("Quit", "Sair") }
    static var webPages: String { text("Web pages", "Páginas web") }

    static func quitTooltip(processCount: Int) -> String {
        text("Click to quit (\(processCount) process(es))", "Clique para encerrar (\(processCount) processo(s))")
    }

    static var protectedTooltip: String { text("System process — can't be quit", "Processo do sistema — não pode ser encerrado") }

    // MARK: Alerts

    static func quitTitle(_ name: String) -> String {
        text("Quit “\(name)”?", "Encerrar “\(name)”?")
    }

    static func quitMessage(processCount: Int) -> String {
        let scope = processCount > 1
            ? text("This affects \(processCount) processes. ", "Isso afeta \(processCount) processos. ")
            : ""
        return scope + text(
            "Quit closes it normally, like ⌘Q. Force Quit ends it immediately and unsaved changes are lost.",
            "Encerrar fecha normalmente, como o ⌘Q. Forçar Encerramento fecha na hora e perde o que não foi salvo.")
    }

    static var quitButton: String { text("Quit", "Encerrar") }
    static var forceQuitButton: String { text("Force Quit", "Forçar Encerramento") }
    static var cancelButton: String { text("Cancel", "Cancelar") }

    static func quitFailed(count: Int, name: String) -> String {
        text("Couldn't quit \(count) process(es) of “\(name)”.",
             "Não foi possível encerrar \(count) processo(s) de “\(name)”.")
    }

    static func launchAtLoginFailed(_ reason: String) -> String {
        text("Couldn't change Open at Login: \(reason)", "Não foi possível alterar o início automático: \(reason)")
    }

    static var launchAtLoginApproval: String {
        text("Allow SystemMonitor in System Settings → General → Login Items.",
             "Aprove o SystemMonitor em Ajustes do Sistema → Geral → Itens de Início.")
    }

    private static func text(_ english: String, _ portuguese: String) -> String {
        language == .portuguese ? portuguese : english
    }
}
