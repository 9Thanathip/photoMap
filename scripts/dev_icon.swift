// Stamps a DEV band across the bottom of the app icon.
//
// No ImageMagick or PIL on this machine; CoreGraphics ships with Xcode.
// Usage: swift dev_icon.swift <src.png> <dst.png>
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count == 3,
      let image = NSImage(contentsOfFile: args[1]),
      let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    FileHandle.standardError.write("usage: dev_icon.swift <src> <dst>\n".data(using: .utf8)!)
    exit(1)
}

let side = 1024
let sideF = CGFloat(side)
let space = CGColorSpaceCreateDeviceRGB()
let layout = CGImageAlphaInfo.premultipliedLast.rawValue

// ── Read the source back, to take its shape and its accent from the art
// itself rather than from numbers that drift when the icon is redrawn.
var pixels = [UInt8](repeating: 0, count: side * side * 4)
let probe = CGContext(data: &pixels, width: side, height: side,
                      bitsPerComponent: 8, bytesPerRow: side * 4,
                      space: space, bitmapInfo: layout)!
probe.draw(source, in: CGRect(x: 0, y: 0, width: sideF, height: sideF))

/// Row 0 is the bottom in CoreGraphics; this indexes from the top.
func pixel(_ x: Int, _ yFromTop: Int) -> (r: Int, g: Int, b: Int, a: Int) {
    let i = ((side - 1 - yFromTop) * side + x) * 4
    return (Int(pixels[i]), Int(pixels[i + 1]), Int(pixels[i + 2]), Int(pixels[i + 3]))
}

// Along the very top row a rounded square first becomes opaque at x = radius.
var radius: CGFloat = 0
for x in 0..<side where pixel(x, 0).a > 128 {
    radius = CGFloat(x)
    break
}
if radius < 1 { radius = sideF * 0.2237 } // squared-off source: use the iOS figure

// The most saturated colour in the icon — the red dot, here.
var accent = (r: 237, g: 45, b: 42)
var bestScore = -1
for y in stride(from: 0, to: side, by: 4) {
    for x in stride(from: 0, to: side, by: 4) {
        let p = pixel(x, y)
        guard p.a > 200 else { continue }
        let score = p.r - max(p.g, p.b)
        if score > bestScore {
            bestScore = score
            accent = (p.r, p.g, p.b)
        }
    }
}

// ── Compose
let canvas = CGContext(data: nil, width: side, height: side,
                       bitsPerComponent: 8, bytesPerRow: 0,
                       space: space, bitmapInfo: layout)!
canvas.draw(source, in: CGRect(x: 0, y: 0, width: sideF, height: sideF))

// Clears the bottom of the J: the hook ends about 0.19 up from the base, and
// a band any taller crops the logo instead of labelling it.
let bandHeight = sideF * 0.175
canvas.saveGState()
// Clipped to the icon's own silhouette, or the band squares off the two
// bottom corners that the artwork rounds.
canvas.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: sideF, height: sideF),
                      cornerWidth: radius, cornerHeight: radius, transform: nil))
canvas.clip()
canvas.setFillColor(CGColor(red: CGFloat(accent.r) / 255,
                            green: CGFloat(accent.g) / 255,
                            blue: CGFloat(accent.b) / 255,
                            alpha: 1))
canvas.fill(CGRect(x: 0, y: 0, width: sideF, height: bandHeight))
canvas.restoreGState()

let context = NSGraphicsContext(cgContext: canvas, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let label = NSAttributedString(string: "DEV", attributes: [
    .font: NSFont.systemFont(ofSize: sideF * 0.108, weight: .black),
    .foregroundColor: NSColor.white,
    .kern: sideF * 0.011,
])
let textSize = label.size()
label.draw(at: NSPoint(x: (sideF - textSize.width) / 2 + sideF * 0.007,
                       y: (bandHeight - textSize.height) / 2))
NSGraphicsContext.restoreGraphicsState()

guard let out = canvas.makeImage(),
      let png = NSBitmapImageRep(cgImage: out).representation(using: .png, properties: [:])
else { exit(1) }
try png.write(to: URL(fileURLWithPath: args[2]))

print("radius=\(Int(radius)) accent=#\(String(format: "%02X%02X%02X", accent.r, accent.g, accent.b))")
