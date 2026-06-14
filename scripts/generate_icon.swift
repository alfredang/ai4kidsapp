// Generates the 1024x1024 App Store marketing icon for AI4Kids.
// Full-bleed (no transparency / no rounded corners — Apple applies the mask).
//
// Usage:  swift scripts/generate_icon.swift [output.png]
// Default output: Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

import AppKit
import CoreGraphics
import Foundation

let side = 1024
let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

let cs = CGColorSpaceCreateDeviceRGB()
// noneSkipLast => opaque image with NO alpha channel (App Store requirement).
guard let ctx = CGContext(
    data: nil, width: side, height: side,
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Could not create CGContext")
}

// Diagonal purple → pink gradient background (the AI4Kids brand).
let colors = [
    CGColor(red: 0.45, green: 0.30, blue: 0.92, alpha: 1),
    CGColor(red: 0.98, green: 0.35, blue: 0.62, alpha: 1),
] as CFArray
if let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1]) {
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: side),
                           end: CGPoint(x: side, y: 0), options: [])
}

// Helper: draw a 5-point star centered at `c`.
func star(center c: CGPoint, outer r: CGFloat, inner ri: CGFloat) -> CGPath {
    let path = CGMutablePath()
    for i in 0..<10 {
        let radius = i % 2 == 0 ? r : ri
        let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
        let p = CGPoint(x: c.x + radius * cos(angle), y: c.y + radius * sin(angle))
        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
    }
    path.closeSubpath()
    return path
}

let mid = CGPoint(x: CGFloat(side) / 2, y: CGFloat(side) / 2 + 40)

// Soft white glow behind the star.
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.18))
ctx.fillEllipse(in: CGRect(x: mid.x - 360, y: mid.y - 360, width: 720, height: 720))

// Big friendly sunny-yellow star.
ctx.addPath(star(center: mid, outer: 300, inner: 130))
ctx.setFillColor(CGColor(red: 1, green: 0.84, blue: 0.16, alpha: 1))
ctx.fillPath()

// Small sparkle stars around it.
for (dx, dy, s) in [(-330.0, 300.0, 70.0), (340.0, 250.0, 55.0), (300.0, -300.0, 60.0), (-320.0, -260.0, 45.0)] {
    ctx.addPath(star(center: CGPoint(x: mid.x + CGFloat(dx), y: mid.y + CGFloat(dy)),
                     outer: CGFloat(s), inner: CGFloat(s) * 0.45))
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
    ctx.fillPath()
}

// "AI" wordmark on the star.
let astr = NSAttributedString(string: "AI", attributes: [
    .font: NSFont.systemFont(ofSize: 230, weight: .black),
    .foregroundColor: NSColor(red: 0.45, green: 0.30, blue: 0.92, alpha: 1),
])
let line = CTLineCreateWithAttributedString(astr)
let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
ctx.textPosition = CGPoint(x: mid.x - bounds.width / 2,
                           y: mid.y - bounds.height / 2 + 10)
CTLineDraw(line, ctx)

guard let img = ctx.makeImage() else { fatalError("makeImage failed") }
let rep = NSBitmapImageRep(cgImage: img)
guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG encode failed")
}
try! data.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath) (\(side)x\(side), no alpha)")
