#!/usr/bin/env swift
import Cocoa

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }
let s = CGFloat(size)

// === Background: Apple-style white/light gray with subtle gradient ===
// Soft frosted glass feel — warm white to cool white
let bgColors = [
    CGColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1.0),
    CGColor(red: 0.90, green: 0.91, blue: 0.93, alpha: 1.0)
]
let bgGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bgGrad, start: CGPoint(x: s/2, y: s), end: CGPoint(x: s/2, y: 0), options: [])

// Frosted glass texture — very subtle noise-like dots
for _ in 0..<800 {
    let rx = CGFloat.random(in: 0...s)
    let ry = CGFloat.random(in: 0...s)
    let ra = CGFloat.random(in: 0.02...0.06)
    ctx.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.55, alpha: ra))
    ctx.fillEllipse(in: CGRect(x: rx, y: ry, width: 2, height: 2))
}

// === Notch shape — large, prominent, centered ===
let notchW: CGFloat = s * 0.62
let notchH: CGFloat = s * 0.22
let notchX = (s - notchW) / 2
let notchBottomY = s * 0.48
let notchRect = CGRect(x: notchX, y: notchBottomY, width: notchW, height: notchH)
let notchRadius = notchH * 0.5
let notchPath = CGPath(roundedRect: notchRect, cornerWidth: notchRadius, cornerHeight: notchRadius, transform: nil)

// Notch shadow (Apple-style soft shadow)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 20, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.15))
ctx.addPath(notchPath)
ctx.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0))
ctx.fillPath()
ctx.restoreGState()

// Notch fill — deep black with slight gradient for depth
let notchColors = [
    CGColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0),
    CGColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1.0)
]
ctx.saveGState()
ctx.addPath(notchPath)
ctx.clip()
let notchGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: notchColors as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(notchGrad, start: CGPoint(x: s/2, y: notchBottomY + notchH), end: CGPoint(x: s/2, y: notchBottomY), options: [])
ctx.restoreGState()

// Subtle inner highlight on notch top edge
ctx.saveGState()
ctx.addPath(notchPath)
ctx.clip()
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.06))
ctx.fill(CGRect(x: notchX, y: notchBottomY + notchH - 3, width: notchW, height: 3))
ctx.restoreGState()

// === Pixel Crab — larger, peeking from bottom of notch ===
enum P { case C, B, D, E }
let sprite: [[P]] = [
    [.C, .C, .B, .B, .C, .C, .C, .B, .B, .C, .B],
    [.C, .B, .B, .B, .B, .B, .B, .B, .B, .B, .B],
    [.C, .B, .B, .E, .B, .B, .B, .E, .B, .B, .C],
    [.C, .B, .B, .B, .B, .B, .B, .B, .B, .B, .C],
    [.C, .B, .B, .B, .D, .D, .D, .B, .B, .B, .C],
    [.C, .B, .B, .B, .B, .B, .B, .B, .B, .B, .C],
    [.C, .D, .C, .D, .C, .C, .C, .D, .C, .D, .C],
]

let bodyColor = CGColor(red: 0.84, green: 0.48, blue: 0.35, alpha: 1.0)
let bodyHi = CGColor(red: 0.92, green: 0.56, blue: 0.42, alpha: 1.0)
let darkColor = CGColor(red: 0.28, green: 0.16, blue: 0.12, alpha: 1.0)
let eyeColor = CGColor(red: 0.08, green: 0.05, blue: 0.03, alpha: 1.0)
let eyeShine = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95)

let px: CGFloat = s * 0.034
let crabCols = 11
let crabRows = 7
let crabW = CGFloat(crabCols) * px
let crabX = (s - crabW) / 2
let crabBaseY = notchBottomY - px * 3.0

// Crab shadow on the white background
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -3), blur: 8, color: CGColor(red: 0.6, green: 0.3, blue: 0.2, alpha: 0.2))

for row in 0..<crabRows {
    for col in 0..<crabCols {
        let pixel = sprite[row][col]
        guard pixel != .C else { continue }

        let color: CGColor
        switch pixel {
        case .B: color = (row <= 1) ? bodyHi : bodyColor
        case .D: color = darkColor
        case .E: color = eyeColor
        case .C: continue
        }

        let pxX = crabX + CGFloat(col) * px
        let pxY = crabBaseY + CGFloat(crabRows - 1 - row) * px
        let gap: CGFloat = 1.5
        let rect = CGRect(x: pxX, y: pxY, width: px - gap, height: px - gap)
        let path = CGPath(roundedRect: rect, cornerWidth: px * 0.14, cornerHeight: px * 0.14, transform: nil)
        ctx.setFillColor(color)
        ctx.addPath(path)
        ctx.fillPath()
    }
}
ctx.restoreGState()

// Eye shine
let eyePositions: [(Int, Int)] = [(3, 2), (7, 2)]
for (ecol, erow) in eyePositions {
    let shineX = crabX + CGFloat(ecol) * px + px * 0.5
    let shineY = crabBaseY + CGFloat(crabRows - 1 - erow) * px + px * 0.5
    let shineSize = px * 0.3
    ctx.setFillColor(eyeShine)
    ctx.fillEllipse(in: CGRect(x: shineX, y: shineY, width: shineSize, height: shineSize))
}

// === "AINotch" text below — clean Apple-style typography ===
let textY = notchBottomY - px * 7 - s * 0.06
let textRect = CGRect(x: 0, y: textY, width: s, height: s * 0.06)
let paraStyle = NSMutableParagraphStyle()
paraStyle.alignment = .center

let textAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: s * 0.048, weight: .semibold),
    .foregroundColor: NSColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 0.7),
    .paragraphStyle: paraStyle,
    .kern: 1.5
]
"AINotch Island".draw(in: textRect, withAttributes: textAttrs)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bmp = NSBitmapImageRep(data: tiff),
      let png = bmp.representation(using: .png, properties: [:]) else { exit(1) }

// Output next to where the script is run from so the repo location
// doesn't matter. Pass an absolute path as the first arg to override.
let out = CommandLine.arguments.dropFirst().first
    ?? FileManager.default.currentDirectoryPath + "/AppIcon.png"
try! png.write(to: URL(fileURLWithPath: out))
print("Icon saved: \(out)")
