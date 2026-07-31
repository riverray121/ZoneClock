// Renders the app icon: globe glyph over a clock-hand accent on near-black.
// Usage: swift scripts/make_icon.swift <output.png>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let px = 1024

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
rep.size = NSSize(width: px, height: px)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Background: near-black, full bleed (iOS applies its own corner mask).
NSColor(calibratedRed: 0.043, green: 0.047, blue: 0.07, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: px, height: px).fill()

let teal = NSColor(calibratedRed: 0.25, green: 0.78, blue: 0.82, alpha: 1)
let config = NSImage.SymbolConfiguration(pointSize: 420, weight: .medium)
    .applying(.init(paletteColors: [teal]))
guard let symbol = NSImage(systemSymbolName: "globe.asia.australia.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config)
else {
    fatalError("symbol unavailable")
}

let targetW = CGFloat(px) * 0.66
let scale = targetW / symbol.size.width
let targetH = symbol.size.height * scale
let origin = NSPoint(x: (CGFloat(px) - targetW) / 2, y: (CGFloat(px) - targetH) / 2)
symbol.draw(
    in: NSRect(origin: origin, size: NSSize(width: targetW, height: targetH)),
    from: .zero, operation: .sourceOver, fraction: 1
)

// Clock hands overlaid at center, white for contrast.
let center = NSPoint(x: CGFloat(px) / 2, y: CGFloat(px) / 2)
let hands = NSBezierPath()
hands.lineWidth = 30
hands.lineCapStyle = .round
hands.move(to: center)
hands.line(to: NSPoint(x: center.x, y: center.y + 190))
hands.move(to: center)
hands.line(to: NSPoint(x: center.x + 135, y: center.y - 60))
NSColor.white.setStroke()
hands.stroke()
NSColor.white.setFill()
NSBezierPath(ovalIn: NSRect(x: center.x - 26, y: center.y - 26, width: 52, height: 52)).fill()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("png encode failed")
}
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(px)x\(px))")
