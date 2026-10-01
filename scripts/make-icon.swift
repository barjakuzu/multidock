// Draws the MultiDock icon (two screens, a dock bar on each) and writes prototype/AppIcon.icns.
// Run from the repo root: swift scripts/make-icon.swift
import AppKit

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024

    // Background squircle, inset like Apple's icon grid
    let bg = NSBezierPath(roundedRect: NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s),
                          xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(starting: NSColor(red: 0.20, green: 0.55, blue: 1.00, alpha: 1),
               ending: NSColor(red: 0.36, green: 0.22, blue: 0.85, alpha: 1))!.draw(in: bg, angle: -60)

    // Two screens side by side, each with a dock bar of three icons
    for (i, x) in [175, 527].enumerated() {
        let screen = NSRect(x: CGFloat(x) * s, y: 390 * s, width: 322 * s, height: 230 * s)
        NSColor(white: 1, alpha: 0.95).setFill()
        NSBezierPath(roundedRect: screen, xRadius: 26 * s, yRadius: 26 * s).fill()
        NSColor(red: 0.12, green: 0.16, blue: 0.30, alpha: 1).setFill()
        NSBezierPath(roundedRect: screen.insetBy(dx: 14 * s, dy: 14 * s), xRadius: 14 * s, yRadius: 14 * s).fill()
        let bar = NSRect(x: screen.midX - 100 * s, y: screen.minY + 30 * s, width: 200 * s, height: 48 * s)
        NSColor(white: 1, alpha: 0.85).setFill()
        NSBezierPath(roundedRect: bar, xRadius: 16 * s, yRadius: 16 * s).fill()
        let colors: [NSColor] = [.systemBlue, .systemOrange, i == 0 ? .systemGreen : .systemPink]
        for (j, c) in colors.enumerated() {
            c.setFill()
            NSBezierPath(roundedRect: NSRect(x: bar.minX + CGFloat(22 + j * 56) * s, y: bar.minY + 8 * s,
                                             width: 44 * s, height: 32 * s), xRadius: 8 * s, yRadius: 8 * s).fill()
        }
        // Stand
        NSColor(white: 1, alpha: 0.95).setFill()
        NSRect(x: screen.midX - 18 * s, y: 330 * s, width: 36 * s, height: 60 * s).fill()
        NSBezierPath(roundedRect: NSRect(x: screen.midX - 70 * s, y: 310 * s, width: 140 * s, height: 26 * s),
                     xRadius: 13 * s, yRadius: 13 * s).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let set = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: set)
try! FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
for pt in [16, 32, 128, 256, 512] {
    try! render(pt).write(to: set.appendingPathComponent("icon_\(pt)x\(pt).png"))
    try! render(pt * 2).write(to: set.appendingPathComponent("icon_\(pt)x\(pt)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set.path, "-o", "prototype/AppIcon.icns"]
try! p.run(); p.waitUntilExit()
print(p.terminationStatus == 0 ? "Wrote prototype/AppIcon.icns" : "iconutil failed")
