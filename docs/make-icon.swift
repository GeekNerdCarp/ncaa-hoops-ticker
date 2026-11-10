// Draws the Hoops Ticker app icon (1024×1024 PNG).
// Usage: swift docs/make-icon.swift <output.png>
import AppKit

let S: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

// Tile: macOS icon grid (824pt square, 100pt margin), dark like the ticker.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = rgb(0, 0, 0, 0.45)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
rgb(14, 15, 24).setFill()
tilePath.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: rgb(36, 38, 58), ending: rgb(10, 10, 16))!.draw(in: tilePath, angle: -90)

// LED ticker dots along the bottom.
let dotY: CGFloat = 196
for i in 0..<11 {
    let x = 232 + CGFloat(i) * 56
    let lit = [1, 2, 3, 5, 6, 8, 9].contains(i)
    (lit ? rgb(255, 200, 70) : rgb(70, 60, 40)).setFill()
    NSBezierPath(ovalIn: NSRect(x: x - 13, y: dotY - 13, width: 26, height: 26)).fill()
}

// Ball.
let c = NSPoint(x: 512, y: 560)
let r: CGFloat = 278
let ballRect = NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
let ball = NSBezierPath(ovalIn: ballRect)

NSGraphicsContext.saveGraphicsState()
let ballShadow = NSShadow()
ballShadow.shadowColor = rgb(0, 0, 0, 0.55)
ballShadow.shadowBlurRadius = 30
ballShadow.shadowOffset = NSSize(width: 0, height: -14)
ballShadow.set()
rgb(230, 100, 30).setFill()
ball.fill()
NSGraphicsContext.restoreGraphicsState()

NSGradient(colors: [rgb(255, 170, 90), rgb(240, 115, 35), rgb(190, 70, 20)],
           atLocations: [0, 0.55, 1], colorSpace: .deviceRGB)!
    .draw(in: ball, relativeCenterPosition: NSPoint(x: -0.35, y: 0.4))

// Seams, clipped to the ball.
NSGraphicsContext.saveGraphicsState()
ball.addClip()
let seam = rgb(40, 18, 10)
seam.setStroke()
let w: CGFloat = 15

let vertical = NSBezierPath()
vertical.move(to: NSPoint(x: c.x, y: c.y - r)); vertical.line(to: NSPoint(x: c.x, y: c.y + r))
let horizontal = NSBezierPath()
horizontal.move(to: NSPoint(x: c.x - r, y: c.y)); horizontal.line(to: NSPoint(x: c.x + r, y: c.y))
for p in [vertical, horizontal] { p.lineWidth = w; p.stroke() }

for side: CGFloat in [-1, 1] {
    // Large circles off to each side give the classic curved seams.
    let rr = r * 0.95
    let cx = c.x + side * r * 1.2
    let arc = NSBezierPath(ovalIn: NSRect(x: cx - rr, y: c.y - rr, width: 2 * rr, height: 2 * rr))
    arc.lineWidth = w
    arc.stroke()
}
NSGraphicsContext.restoreGraphicsState()

// Subtle rim.
rgb(120, 45, 10, 0.6).setStroke()
ball.lineWidth = 4
ball.stroke()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
