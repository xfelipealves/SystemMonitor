import AppKit

/// Text and colors shown in the menu bar and in the menu.
enum Formatting {
    static let warningThreshold = 75.0
    static let criticalThreshold = 90.0

    // MARK: - Numbers (in the app's language, not the system's)

    static func memory(_ bytes: Int64, locale: Locale = L10n.language.locale) -> String {
        bytes.formatted(.byteCount(style: .memory).locale(locale))
    }

    static func disk(_ bytes: Int64, locale: Locale = L10n.language.locale) -> String {
        bytes.formatted(.byteCount(style: .file).locale(locale))
    }

    /// 84.2 → "84.2%" in English, "84,2%" in Portuguese.
    static func cpu(_ percent: Double, locale: Locale = L10n.language.locale) -> String {
        (percent / 100).formatted(.percent.precision(.fractionLength(1)).locale(locale))
    }

    // MARK: - Alert colors

    /// Yellow from 75%, red from 90%, `nil` (menu bar default color) below that.
    static func alertColor(for percent: Double) -> NSColor? {
        if percent >= criticalThreshold { return .systemRed }
        if percent >= warningThreshold { return .systemYellow }
        return nil
    }

    // MARK: - Attributed titles

    /// "[icon] 42%   [icon] 81%   [icon] 90%" for the menu bar item.
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
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .right, location: 300)]

        let title = NSMutableAttributedString(string: truncated(name, to: 30) + "\t", attributes: [
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

    static func truncated(_ text: String, to maxLength: Int) -> String {
        text.count > maxLength ? String(text.prefix(maxLength - 1)) + "…" : text
    }

    /// Template symbols follow the menu bar color; colored ones are drawn as-is.
    private static func symbol(_ name: String, config: NSImage.SymbolConfiguration, color: NSColor?) -> NSImage? {
        let finalConfig = color.map { config.applying(.init(paletteColors: [$0])) } ?? config
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(finalConfig)
        image?.isTemplate = color == nil
        return image
    }
}
