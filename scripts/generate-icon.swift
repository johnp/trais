#!/usr/bin/env swift
import AppKit
import Foundation

struct IconRepresentation {
    let filename: String
    let pixels: Int
}

let representations = [
    IconRepresentation(filename: "icon_16x16.png", pixels: 16),
    IconRepresentation(filename: "icon_16x16@2x.png", pixels: 32),
    IconRepresentation(filename: "icon_32x32.png", pixels: 32),
    IconRepresentation(filename: "icon_32x32@2x.png", pixels: 64),
    IconRepresentation(filename: "icon_128x128.png", pixels: 128),
    IconRepresentation(filename: "icon_128x128@2x.png", pixels: 256),
    IconRepresentation(filename: "icon_256x256.png", pixels: 256),
    IconRepresentation(filename: "icon_256x256@2x.png", pixels: 512),
    IconRepresentation(filename: "icon_512x512.png", pixels: 512),
    IconRepresentation(filename: "icon_512x512@2x.png", pixels: 1_024),
]

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-icon.swift <output.iconset>\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

for representation in representations {
    let data = try renderIcon(pixels: representation.pixels)
    try data.write(to: outputURL.appendingPathComponent(representation.filename), options: .atomic)
}

func renderIcon(pixels: Int) throws -> Data {
    let size = CGFloat(pixels)
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else {
        throw IconError.couldNotCreateBitmap
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.shouldAntialias = true
    context.imageInterpolation = .high

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let inset = size * 0.065
    let tileRect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let tile = NSBezierPath(roundedRect: tileRect, xRadius: size * 0.21, yRadius: size * 0.21)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.12, green: 0.34, blue: 0.96, alpha: 1),
        NSColor(red: 0.35, green: 0.12, blue: 0.78, alpha: 1),
    ])!
    gradient.draw(in: tile, angle: -48)
    tile.addClip()

    let glowRect = NSRect(
        x: size * 0.36,
        y: size * 0.32,
        width: size * 0.72,
        height: size * 0.72
    )
    NSColor.white.withAlphaComponent(0.08).setFill()
    NSBezierPath(ovalIn: glowRect).fill()

    let chart = NSBezierPath()
    chart.lineWidth = max(1.5, size * 0.072)
    chart.lineCapStyle = .round
    chart.lineJoinStyle = .round
    chart.move(to: CGPoint(x: size * 0.20, y: size * 0.34))
    chart.line(to: CGPoint(x: size * 0.38, y: size * 0.50))
    chart.line(to: CGPoint(x: size * 0.53, y: size * 0.43))
    chart.line(to: CGPoint(x: size * 0.77, y: size * 0.70))

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = size * 0.025
    shadow.shadowOffset = CGSize(width: 0, height: -size * 0.014)
    shadow.set()
    NSColor.white.setStroke()
    chart.stroke()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw IconError.couldNotEncodePNG
    }
    return data
}

enum IconError: LocalizedError {
    case couldNotCreateBitmap
    case couldNotEncodePNG

    var errorDescription: String? {
        switch self {
        case .couldNotCreateBitmap:
            "Could not create the icon bitmap."
        case .couldNotEncodePNG:
            "Could not encode the icon as PNG."
        }
    }
}
