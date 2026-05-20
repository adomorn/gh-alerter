#!/usr/bin/env swift

import AppKit
import Foundation

let resourcesDirectory = URL(fileURLWithPath: "Sources/GHAlerterApp/Resources")
let iconsetDirectory = resourcesDirectory.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: iconsetDirectory)
try FileManager.default.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

let iconSizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (fileName, size) in iconSizes {
    try savePNG(size: NSSize(width: size, height: size), style: .app, to: iconsetDirectory.appendingPathComponent(fileName))
}

try savePNG(size: NSSize(width: 36, height: 36), style: .template, to: resourcesDirectory.appendingPathComponent("StatusBarIcon.png"))

enum IconStyle {
    case app
    case template
}

func drawIcon(size: NSSize, style: IconStyle) {
    let bounds = NSRect(origin: .zero, size: size)
    NSColor.clear.setFill()
    bounds.fill()

    let scale = size.width / 1024.0
    func r(_ value: CGFloat) -> CGFloat { value * scale }
    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(x: r(x), y: r(y), width: r(width), height: r(height))
    }

    let foreground: NSColor
    let accent: NSColor
    switch style {
    case .app:
        let background = NSBezierPath(roundedRect: bounds.insetBy(dx: r(72), dy: r(72)), xRadius: r(210), yRadius: r(210))
        NSGradient(colors: [
            NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.16, alpha: 1.0),
            NSColor(calibratedRed: 0.04, green: 0.05, blue: 0.07, alpha: 1.0)
        ])?.draw(in: background, angle: 315)

        NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.30, alpha: 1.0).setStroke()
        background.lineWidth = r(18)
        background.stroke()

        foreground = .white
        accent = NSColor(calibratedRed: 0.28, green: 0.78, blue: 0.50, alpha: 1.0)
    case .template:
        foreground = .black
        accent = .black
    }

    drawBell(in: bounds, scale: scale, color: foreground)
    drawBranch(in: bounds, scale: scale, color: accent)
}

func drawBell(in bounds: NSRect, scale: CGFloat, color: NSColor) {
    func r(_ value: CGFloat) -> CGFloat { value * scale }
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: r(x), y: r(y))
    }
    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(x: r(x), y: r(y), width: r(width), height: r(height))
    }

    color.setFill()
    color.setStroke()

    let body = NSBezierPath()
    body.move(to: point(310, 405))
    body.curve(to: point(408, 270), controlPoint1: point(318, 330), controlPoint2: point(350, 288))
    body.line(to: point(616, 270))
    body.curve(to: point(714, 405), controlPoint1: point(674, 288), controlPoint2: point(706, 330))
    body.curve(to: point(648, 668), controlPoint1: point(714, 548), controlPoint2: point(678, 628))
    body.curve(to: point(512, 722), controlPoint1: point(616, 700), controlPoint2: point(572, 722))
    body.curve(to: point(376, 668), controlPoint1: point(452, 722), controlPoint2: point(408, 700))
    body.curve(to: point(310, 405), controlPoint1: point(346, 628), controlPoint2: point(310, 548))
    body.close()
    body.fill()

    let clapper = NSBezierPath(ovalIn: rect(450, 188, 124, 124))
    clapper.fill()

    let crown = NSBezierPath(roundedRect: rect(454, 724, 108, 72), xRadius: r(36), yRadius: r(36))
    crown.fill()

    let alertDot = NSBezierPath(ovalIn: rect(658, 640, 126, 126))
    alertDot.fill()
}

func drawBranch(in bounds: NSRect, scale: CGFloat, color: NSColor) {
    func r(_ value: CGFloat) -> CGFloat { value * scale }
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: r(x), y: r(y))
    }
    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(x: r(x), y: r(y), width: r(width), height: r(height))
    }

    color.setFill()
    color.setStroke()

    let line = NSBezierPath()
    line.lineWidth = r(58)
    line.lineCapStyle = .round
    line.lineJoinStyle = .round
    line.move(to: point(318, 356))
    line.curve(to: point(512, 472), controlPoint1: point(390, 354), controlPoint2: point(458, 382))
    line.curve(to: point(706, 528), controlPoint1: point(562, 522), controlPoint2: point(624, 534))
    line.stroke()

    NSBezierPath(ovalIn: rect(250, 308, 116, 116)).fill()
    NSBezierPath(ovalIn: rect(470, 418, 116, 116)).fill()
    NSBezierPath(ovalIn: rect(674, 478, 116, 116)).fill()
}

func savePNG(size: NSSize, style: IconStyle, to url: URL) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "IconGenerator", code: 1)
    }

    bitmap.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    drawIcon(size: size, style: style)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 2)
    }

    try data.write(to: url)
}
