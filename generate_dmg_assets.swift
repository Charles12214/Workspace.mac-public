import AppKit
import Foundation

// Dimensions for the DMG window
let width: CGFloat = 660
let height: CGFloat = 420

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(width * 2),
    pixelsHigh: Int(height * 2),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = NSSize(width: width, height: height)

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("Could not create graphics context")
}
NSGraphicsContext.current = context
let cg = context.cgContext

// 1. Sleek Modern Dark Background with subtle ambient glow
let bgGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0).cgColor,
        NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1.0).cgColor
    ] as CFArray,
    locations: [0.0, 1.0]
)!
cg.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])

// 2. Subtle ambient glows (Gemini blue & purple)
cg.saveGState()
let blueGlow = NSColor(red: 0.0, green: 0.643, blue: 0.976, alpha: 0.15).cgColor
cg.setFillColor(blueGlow)
cg.setShadow(offset: .zero, blur: 80, color: blueGlow)
cg.fillEllipse(in: CGRect(x: 100, y: 150, width: 140, height: 140))

let purpleGlow = NSColor(red: 0.545, green: 0.361, blue: 0.965, alpha: 0.15).cgColor
cg.setFillColor(purpleGlow)
cg.setShadow(offset: .zero, blur: 80, color: purpleGlow)
cg.fillEllipse(in: CGRect(x: 420, y: 150, width: 140, height: 140))
cg.restoreGState()

// 3. Central Sleek Drag Arrow
cg.saveGState()
let arrowGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(red: 0.0, green: 0.643, blue: 0.976, alpha: 0.7).cgColor,
        NSColor(red: 0.545, green: 0.361, blue: 0.965, alpha: 0.7).cgColor
    ] as CFArray,
    locations: [0.0, 1.0]
)!

// Draw curved / stylized arrow line between (230, 230) and (430, 230)
let startX: CGFloat = 250
let endX: CGFloat = 410
let centerY: CGFloat = 230

cg.setLineWidth(3.0)
cg.setLineCap(.round)
cg.setStrokeColor(NSColor(white: 1.0, alpha: 0.25).cgColor)

// Dashed guide path
cg.setLineDash(phase: 0, lengths: [6, 5])
cg.beginPath()
cg.move(to: CGPoint(x: startX, y: centerY))
cg.addLine(to: CGPoint(x: endX - 10, y: centerY))
cg.strokePath()

// Arrow Head
cg.setLineDash(phase: 0, lengths: [])
cg.setFillColor(NSColor(red: 0.0, green: 0.643, blue: 0.976, alpha: 0.8).cgColor)
cg.beginPath()
cg.move(to: CGPoint(x: endX, y: centerY))
cg.addLine(to: CGPoint(x: endX - 14, y: centerY + 8))
cg.addLine(to: CGPoint(x: endX - 14, y: centerY - 8))
cg.closePath()
cg.fillPath()
cg.restoreGState()

// 4. Instructional Typography
let titleText = "Workspace.mac"
let titleFont = NSFont.systemFont(ofSize: 22, weight: .bold)
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor(white: 0.95, alpha: 1.0)
]
let titleSize = titleText.size(withAttributes: titleAttrs)
titleText.draw(at: CGPoint(x: (width - titleSize.width) / 2, y: 350), withAttributes: titleAttrs)

let subText = "Drag Workspace.mac into your Applications folder to install"
let subFont = NSFont.systemFont(ofSize: 13, weight: .medium)
let subAttrs: [NSAttributedString.Key: Any] = [
    .font: subFont,
    .foregroundColor: NSColor(white: 0.6, alpha: 1.0)
]
let subSize = subText.size(withAttributes: subAttrs)
subText.draw(at: CGPoint(x: (width - subSize.width) / 2, y: 325), withAttributes: subAttrs)

// Bottom tag
let versionText = "Version 1.2.1 • Native Google Workspace Client for macOS"
let versionFont = NSFont.systemFont(ofSize: 11, weight: .regular)
let versionAttrs: [NSAttributedString.Key: Any] = [
    .font: versionFont,
    .foregroundColor: NSColor(white: 0.35, alpha: 1.0)
]
let versionSize = versionText.size(withAttributes: versionAttrs)
versionText.draw(at: CGPoint(x: (width - versionSize.width) / 2, y: 35), withAttributes: versionAttrs)

NSGraphicsContext.restoreGraphicsState()

let pngData = rep.representation(using: .png, properties: [:])!
try! pngData.write(to: URL(fileURLWithPath: "dmg_background.png"))
print("Generated dmg_background.png (\(Int(width * 2))x\(Int(height * 2))) successfully.")
