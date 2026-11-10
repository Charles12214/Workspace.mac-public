import SwiftUI

// MARK: - Official Gemini 4-Color Palette (From User Reference)
// Top: Coral Red (#F7646F)
// Right: Electric Blue (#00A4F9)
// Bottom: Emerald Green (#00C688)
// Left: Golden Yellow (#FCC800)
public struct GeminiPalette {
    public static let red = Color(hex: "F7646F")
    public static let blue = Color(hex: "00A4F9")
    public static let green = Color(hex: "00C688")
    public static let yellow = Color(hex: "FCC800")
    
    public static let allColors = [red, yellow, green, blue]
    
    // Conic / Angular gradient aligned exactly with the star's 4 points:
    // -90deg is Top (Red), 0deg is Right (Blue), 90deg is Bottom (Green), 180deg is Left (Yellow)
    public static let starGradient = AngularGradient(
        colors: [red, blue, green, yellow, red],
        center: .center,
        startAngle: .degrees(-90),
        endAngle: .degrees(270)
    )
    
    public static let linearGradient = LinearGradient(
        colors: [red, yellow, green, blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let horizontalGradient = LinearGradient(
        colors: [red, yellow, green, blue],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    public static let borderGradient = LinearGradient(
        colors: [red.opacity(0.8), blue.opacity(0.8), green.opacity(0.8), yellow.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

public struct GeminiHomeIcon: View {
    public let isSelected: Bool
    public let action: () -> Void
    
    @State private var isHovered = false
    
    public init(isSelected: Bool, action: @escaping () -> Void) {
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack {
                // Background container (Clean solid Material - NO gradient)
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        isSelected
                            ? Color(hex: "1A73E8").opacity(0.16)
                            : (isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                
                // Border (Clean solid highlight - NO gradient)
                if isSelected {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color(hex: "1A73E8").opacity(0.65), lineWidth: 1.5)
                } else {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(isHovered ? Color.primary.opacity(0.20) : Color.primary.opacity(0.08), lineWidth: 1)
                }
                
                // Icon: Clean solid home icon (NO gradient)
                Image(systemName: "house.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(
                        isSelected
                            ? Color(hex: "1A73E8")
                            : (isHovered ? Color.primary : Color.secondary)
                    )
                    .scaleEffect(isSelected ? 1.04 : (isHovered ? 1.02 : 1.0))
            }
            .frame(width: 44, height: 44)
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.16)) {
                isHovered = h
            }
        }
        .help("Workspace Home & Overview")
    }
}

// MARK: - Gemini 4-Point Curved Sparkle Shape
public struct GeminiSparkleShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let w = rect.width
        let h = rect.height
        let r = min(w, h) / 2.0
        let cRatio: CGFloat = 0.28 // curvature pull
        
        // Top tip (Red)
        path.move(to: CGPoint(x: center.x, y: center.y - r))
        
        // Curve to Right tip (Blue)
        path.addQuadCurve(to: CGPoint(x: center.x + r, y: center.y),
                          control: CGPoint(x: center.x + r * cRatio, y: center.y - r * cRatio))
        
        // Curve to Bottom tip (Green)
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + r),
                          control: CGPoint(x: center.x + r * cRatio, y: center.y + r * cRatio))
        
        // Curve to Left tip (Yellow)
        path.addQuadCurve(to: CGPoint(x: center.x - r, y: center.y),
                          control: CGPoint(x: center.x - r * cRatio, y: center.y + r * cRatio))
        
        // Curve back to Top tip
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - r),
                          control: CGPoint(x: center.x - r * cRatio, y: center.y - r * cRatio))
        
        path.closeSubpath()
        return path
    }
}
