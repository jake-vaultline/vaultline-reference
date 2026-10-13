// Deterministic original synthetic media; no client or stock assets.
import AppKit
import Foundation
let root = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
func image(_ name: String, sky: NSColor, land: NSColor, sun: NSColor, city: Bool = false) throws {
    let image = NSImage(size: NSSize(width: 960, height: 540))
    image.lockFocus()
    sky.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: 960, height: 540)).fill()
    sun.setFill(); NSBezierPath(ovalIn: NSRect(x: 655, y: 315, width: 115, height: 115)).fill()
    land.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: 960, height: 225)).fill()
    if city {
        for x in stride(from: 80, to: 880, by: 95) {
            NSColor(white: 0.14, alpha: 1).setFill()
            NSBezierPath(rect: NSRect(x: x, y: 180, width: 65, height: 110 + (x % 120))).fill()
        }
    } else {
        let path = NSBezierPath(); path.move(to: NSPoint(x: 0,y: 190)); path.curve(to: NSPoint(x: 960,y: 110), controlPoint1: NSPoint(x: 220,y: 330), controlPoint2: NSPoint(x: 550,y: 15)); path.line(to: NSPoint(x: 960,y: 0)); path.line(to: NSPoint(x: 0,y: 0)); path.close()
        NSColor(red: 0.72,green: 0.54,blue: 0.35,alpha: 1).setFill(); path.fill()
    }
    let text = "SYNTHETIC DEMO / " + name.uppercased()
    text.draw(at: NSPoint(x: 28,y: 28), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 18, weight: .medium), .foregroundColor: NSColor.white])
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(name + ".png"))
}
try image("warm-coast", sky: NSColor(red: 0.85,green: 0.49,blue: 0.30,alpha: 1), land: NSColor(red: 0.14,green: 0.35,blue: 0.40,alpha: 1), sun: NSColor(red: 1,green: 0.82,blue: 0.47,alpha: 1))
try image("blue-city", sky: NSColor(red: 0.19,green: 0.28,blue: 0.43,alpha: 1), land: NSColor(red: 0.15,green: 0.19,blue: 0.27,alpha: 1), sun: NSColor(red: 0.48,green: 0.62,blue: 0.74,alpha: 1), city: true)
try image("day-coast", sky: NSColor(red: 0.35,green: 0.66,blue: 0.83,alpha: 1), land: NSColor(red: 0.13,green: 0.47,blue: 0.56,alpha: 1), sun: NSColor(red: 1,green: 0.95,blue: 0.68,alpha: 1))
