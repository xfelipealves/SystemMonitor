// Draws the app icon (1024x1024 PNG). Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "icon.png"

let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    // macOS icon grid: 824pt rounded square centered on a 1024pt canvas.
    let inset: CGFloat = 100
    let tile = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 30
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [NSColor(srgbRed: 0.10, green: 0.11, blue: 0.20, alpha: 1),
                        NSColor(srgbRed: 0.20, green: 0.16, blue: 0.42, alpha: 1)])!
        .draw(in: shape, angle: 90)

    // Three bars = CPU, RAM, disk, in the app's alert colors.
    let bars: [(height: CGFloat, color: NSColor)] = [
        (0.42, NSColor(srgbRed: 0.30, green: 0.85, blue: 0.55, alpha: 1)),
        (0.68, NSColor(srgbRed: 1.00, green: 0.80, blue: 0.20, alpha: 1)),
        (0.88, NSColor(srgbRed: 1.00, green: 0.33, blue: 0.33, alpha: 1)),
    ]
    let barWidth: CGFloat = 140, gap: CGFloat = 70
    let baseY = tile.minY + 170, maxHeight: CGFloat = 480
    var x = tile.midX - (3 * barWidth + 2 * gap) / 2
    for bar in bars {
        let track = NSRect(x: x, y: baseY, width: barWidth, height: maxHeight)
        NSColor.white.withAlphaComponent(0.08).setFill()
        NSBezierPath(roundedRect: track, xRadius: 40, yRadius: 40).fill()
        let fill = NSRect(x: x, y: baseY, width: barWidth, height: maxHeight * bar.height)
        NSGradient(colors: [bar.color.withAlphaComponent(0.75), bar.color])!
            .draw(in: NSBezierPath(roundedRect: fill, xRadius: 40, yRadius: 40), angle: 90)
        x += barWidth + gap
    }

    // Base line under the bars.
    NSColor.white.withAlphaComponent(0.85).setFill()
    NSBezierPath(roundedRect: NSRect(x: tile.minX + 150, y: baseY - 60, width: tile.width - 300, height: 22),
                 xRadius: 11, yRadius: 11).fill()
    return true
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
