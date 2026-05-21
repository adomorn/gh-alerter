#!/usr/bin/env swift

import AppKit
import Foundation

let scriptURL = URL(fileURLWithPath: #filePath)
let rootURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let outputURL = rootURL.appendingPathComponent("Sources/GHAlerterApp/Resources/DmgBackground.png")
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try savePNG(size: NSSize(width: 720, height: 460), to: outputURL)

func drawBackground(size: NSSize) {
    let bounds = NSRect(origin: .zero, size: size)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.055, green: 0.066, blue: 0.086, alpha: 1),
        NSColor(calibratedRed: 0.025, green: 0.030, blue: 0.040, alpha: 1)
    ])?.draw(in: bounds, angle: 315)

    let panel = NSBezierPath(roundedRect: bounds.insetBy(dx: 26, dy: 24), xRadius: 22, yRadius: 22)
    NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.15, alpha: 0.78).setFill()
    panel.fill()
    NSColor(calibratedRed: 0.22, green: 0.27, blue: 0.34, alpha: 0.60).setStroke()
    panel.lineWidth = 1
    panel.stroke()

    drawArrow(from: NSPoint(x: 286, y: 228), to: NSPoint(x: 436, y: 228))
}

func drawArrow(from start: NSPoint, to end: NSPoint) {
    let path = NSBezierPath()
    path.lineWidth = 4
    path.lineCapStyle = .round
    NSColor(calibratedRed: 0.28, green: 0.78, blue: 0.50, alpha: 1).setStroke()
    path.move(to: start)
    path.line(to: end)
    path.stroke()

    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: end.x - 18, y: end.y + 14))
    arrow.line(to: end)
    arrow.line(to: NSPoint(x: end.x - 18, y: end.y - 14))
    arrow.lineWidth = 4
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.stroke()
}

func drawText(
    _ text: String,
    at point: NSPoint,
    size: CGFloat,
    weight: NSFont.Weight,
    color: NSColor
) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color
    ]
    text.draw(at: point, withAttributes: attributes)
}

func savePNG(size: NSSize, to url: URL) throws {
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
        throw NSError(domain: "DMGBackgroundGenerator", code: 1)
    }

    bitmap.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    drawBackground(size: size)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "DMGBackgroundGenerator", code: 2)
    }

    try data.write(to: url)
}
