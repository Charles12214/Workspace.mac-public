import SwiftUI

// MARK: - Liquid Glass Card Modifier
public struct LiquidGlassCard: ViewModifier {
    public var cornerRadius: CGFloat
    public var tintColor: Color?
    public var isHighlighted: Bool
    public var interactive: Bool
    
    public init(
        cornerRadius: CGFloat = 16,
        tintColor: Color? = nil,
        isHighlighted: Bool = false,
        interactive: Bool = true
    ) {
        self.cornerRadius = cornerRadius
        self.tintColor = tintColor
        self.isHighlighted = isHighlighted
        self.interactive = interactive
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Frosted Glass material base
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    // Subtle dynamic color tint
                    if let tint = tintColor {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(isHighlighted ? 0.16 : 0.07))
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.primary.opacity(0.02))
                    }
                    
                    // Ambient Top-to-Bottom reflection highlight (Liquid Glass specularity)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.04),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: isHighlighted
                                ? [Color.white.opacity(0.6), Color.white.opacity(0.2), (tintColor ?? .blue).opacity(0.5)]
                                : [Color.white.opacity(0.28), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHighlighted ? 1.5 : 1
                    )
            )
            .shadow(
                color: (tintColor ?? Color.black).opacity(isHighlighted ? 0.18 : 0.08),
                radius: isHighlighted ? 14 : 8,
                x: 0,
                y: isHighlighted ? 6 : 3
            )
    }
}

extension View {
    public func liquidGlass(
        cornerRadius: CGFloat = 16,
        tintColor: Color? = nil,
        isHighlighted: Bool = false
    ) -> some View {
        self.modifier(LiquidGlassCard(
            cornerRadius: cornerRadius,
            tintColor: tintColor,
            isHighlighted: isHighlighted
        ))
    }
}

// MARK: - Material You Pill Button
public struct MaterialYouPillButton: View {
    public let title: String
    public let icon: String?
    public let primaryColor: Color
    public let action: () -> Void
    
    @State private var isHovered = false
    
    public init(
        title: String,
        icon: String? = nil,
        primaryColor: Color = Color(hex: "1A73E8"),
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.primaryColor = primaryColor
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [primaryColor, primaryColor.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: primaryColor.opacity(isHovered ? 0.45 : 0.25), radius: isHovered ? 10 : 5, x: 0, y: isHovered ? 4 : 2)
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = h
            }
        }
    }
}
