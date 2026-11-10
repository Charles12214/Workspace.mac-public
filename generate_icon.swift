import AppKit
import Foundation

let sizes: [(String, Int)] = [
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

let iconsetDir = "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

// User Reference Image Colors:
// Top (Coral Red): #F7646F
// Right (Electric Cyan/Blue): #00A4F9
// Bottom (Emerald Green): #00C688
// Left (Golden Amber/Yellow): #FCC800
let cRed = NSColor(red: 0.969, green: 0.392, blue: 0.435, alpha: 1.0)
let cBlue = NSColor(red: 0.0, green: 0.643, blue: 0.976, alpha: 1.0)
let cGreen = NSColor(red: 0.0, green: 0.776, blue: 0.533, alpha: 1.0)
let cYellow = NSColor(red: 0.988, green: 0.784, blue: 0.0, alpha: 1.0)

for (filename, size) in sizes {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { continue }
    
    // Inset macOS squircle
    let inset = s * 0.08
    let rect = CGRect(x: inset, y: inset, width: s - (inset * 2), height: s - (inset * 2))
    let radius = rect.width * 0.224
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    
    // Background: Crisp Apple Pure White to slight Pearl Off-White (as in reference image)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        NSColor(white: 1.0, alpha: 1.0).cgColor,
        NSColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0).cgColor
    ] as CFArray
    if let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(bgGrad, start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.minY), options: [])
    }
    
    ctx.restoreGState()
    
    // Subtle border
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setLineWidth(max(0.5, s * 0.008))
    ctx.setStrokeColor(NSColor(white: 0.0, alpha: 0.08).cgColor)
    ctx.strokePath()
    ctx.restoreGState()
    
    // Geometry for Gemini 4-pointed Sparkle Shape in center
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let starRadius = rect.width * 0.36
    let cRatio: CGFloat = 0.285
    
    let starPath = CGMutablePath()
    // In CGContext (macOS default coordinates: 0,0 is bottom-left):
    // Top tip: y + starRadius
    starPath.move(to: CGPoint(x: center.x, y: center.y + starRadius))
    starPath.addQuadCurve(to: CGPoint(x: center.x + starRadius, y: center.y),
                          control: CGPoint(x: center.x + starRadius * cRatio, y: center.y + starRadius * cRatio))
    starPath.addQuadCurve(to: CGPoint(x: center.x, y: center.y - starRadius),
                          control: CGPoint(x: center.x + starRadius * cRatio, y: center.y - starRadius * cRatio))
    starPath.addQuadCurve(to: CGPoint(x: center.x - starRadius, y: center.y),
                          control: CGPoint(x: center.x - starRadius * cRatio, y: center.y - starRadius * cRatio))
    starPath.addQuadCurve(to: CGPoint(x: center.x, y: center.y + starRadius),
                          control: CGPoint(x: center.x - starRadius * cRatio, y: center.y + starRadius * cRatio))
    starPath.closeSubpath()
    
    // Star Drop Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.02), blur: s * 0.06, color: NSColor(red: 0.0, green: 0.35, blue: 0.7, alpha: 0.22).cgColor)
    ctx.addPath(starPath)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    
    // Draw Gemini Gradient fill inside the star
    ctx.saveGState()
    ctx.addPath(starPath)
    ctx.clip()
    
    // Base fill with blue/green
    let baseColors = [
        cBlue.cgColor,
        cGreen.cgColor
    ] as CFArray
    if let baseGrad = CGGradient(colorsSpace: colorSpace, colors: baseColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(baseGrad,
                               start: CGPoint(x: center.x + starRadius * 0.5, y: center.y),
                               end: CGPoint(x: center.x, y: center.y - starRadius * 0.8),
                               options: [])
    }
    
    // Top tip: Coral Red radial glow
    ctx.saveGState()
    ctx.setBlendMode(.normal)
    let redGlow = [cRed.cgColor, cRed.withAlphaComponent(0.0).cgColor] as CFArray
    if let redGrad = CGGradient(colorsSpace: colorSpace, colors: redGlow, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(redGrad,
                               startCenter: CGPoint(x: center.x, y: center.y + starRadius * 0.85),
                               startRadius: 0,
                               endCenter: CGPoint(x: center.x, y: center.y),
                               endRadius: starRadius * 1.05,
                               options: [])
    }
    ctx.restoreGState()
    
    // Left tip: Golden Yellow radial glow
    ctx.saveGState()
    ctx.setBlendMode(.normal)
    let yellowGlow = [cYellow.cgColor, cYellow.withAlphaComponent(0.0).cgColor] as CFArray
    if let yellowGrad = CGGradient(colorsSpace: colorSpace, colors: yellowGlow, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(yellowGrad,
                               startCenter: CGPoint(x: center.x - starRadius * 0.85, y: center.y),
                               startRadius: 0,
                               endCenter: CGPoint(x: center.x, y: center.y),
                               endRadius: starRadius * 1.05,
                               options: [])
    }
    ctx.restoreGState()
    
    // Bottom tip: Emerald Green radial glow
    ctx.saveGState()
    let greenGlow = [cGreen.cgColor, cGreen.withAlphaComponent(0.0).cgColor] as CFArray
    if let greenGrad = CGGradient(colorsSpace: colorSpace, colors: greenGlow, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(greenGrad,
                               startCenter: CGPoint(x: center.x, y: center.y - starRadius * 0.85),
                               startRadius: 0,
                               endCenter: CGPoint(x: center.x, y: center.y),
                               endRadius: starRadius * 1.05,
                               options: [])
    }
    ctx.restoreGState()
    
    // Right tip: Electric Blue radial glow
    ctx.saveGState()
    let blueGlow = [cBlue.cgColor, cBlue.withAlphaComponent(0.0).cgColor] as CFArray
    if let blueGrad = CGGradient(colorsSpace: colorSpace, colors: blueGlow, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(blueGrad,
                               startCenter: CGPoint(x: center.x + starRadius * 0.85, y: center.y),
                               startRadius: 0,
                               endCenter: CGPoint(x: center.x, y: center.y),
                               endRadius: starRadius * 1.05,
                               options: [])
    }
    ctx.restoreGState()
    
    ctx.restoreGState() // restore from starPath clip
    
    image.unlockFocus()
    
    if let tiff = image.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        let dest = URL(fileURLWithPath: "\(iconsetDir)/\(filename)")
        try? png.write(to: dest)
    }
}

print("Iconset created successfully at \(iconsetDir)")
