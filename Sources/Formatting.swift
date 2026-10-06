import AppKit

/// Text and colors shown in the menu bar and in the dropdown menu.
enum Formatting {
    static let warningThreshold = 75.0
    static let criticalThreshold = 90.0

    private static let memoryFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()

    private static let diskFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    static func memory(_ bytes: Int64) -> String { memoryFormatter.string(fromByteCount: bytes) }
    static func disk(_ bytes: Int64) -> String { diskFormatter.string(fromByteCount: bytes) }
    static func cpu(_ percent: Double) -> String { String(format: "%.1f%%", percent) }

    /// Yellow from 75%, red from 90%, `nil` (menu bar default) below that.
    static func alertColor(for percent: Double) -> NSColor? {
        if percent >= criticalThreshold { return .systemRed }
        if percent >= warningThreshold { return .systemYellow }
        return nil
    }

    /// "[icon] 42%   [icon] 81%   [icon] 90%" for the status item.
    static func statusTitle(_ metrics: [(symbol: String, percent: Double)]) -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let title = NSMutableAttributedString()

        for (index, metric) in metrics.enumerated() {
            let color = alertColor(for: metric.percent)
            if let icon = symbol(metric.symbol, config: symbolConfig, color: color) {
                let attachment = NSTextAttachment()
                attachment.image = icon
                attachment.bounds = NSRect(x: 0, y: (font.capHeight - icon.size.height) / 2,
                                           width: icon.size.width, height: icon.size.height)
                title.append(NSAttributedString(attachment: attachment))
            }

            var attributes: [NSAttributedString.Key: Any] = [.font: font]
            if let color { attributes[.foregroundColor] = color }
            let separator = index < metrics.count - 1 ? "   " : ""
            title.append(NSAttributedString(string: String(format: " %2.0f%%", metric.percent) + separator,
                                            attributes: attributes))
        }
        return title
    }

    /// "Name ........ value" with the value right-aligned and dimmed.
    static func processTitle(name: String, value: String) -> NSAttributedString {
        let maxNameLength = 30
        let shortName = name.count > maxNameLength ? String(name.prefix(maxNameLength - 1)) + "…" : name
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .right, location: 300)]

        let title = NSMutableAttributedString(string: shortName + "\t", attributes: [
            .font: NSFont.menuFont(ofSize: 0),
            .paragraphStyle: style,
        ])
        title.append(NSAttributedString(string: value, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: style,
        ]))
        return title
    }

    /// Template symbols follow the menu bar color; colored ones are drawn as-is.
    private static func symbol(_ name: String, config: NSImage.SymbolConfiguration, color: NSColor?) -> NSImage? {
        let finalConfig = color.map { config.applying(.init(paletteColors: [$0])) } ?? config
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(finalConfig)
        image?.isTemplate = color == nil
        return image
    }
}
