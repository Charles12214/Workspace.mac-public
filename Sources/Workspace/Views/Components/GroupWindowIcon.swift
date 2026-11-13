import SwiftUI

/// Grey rounded window frame icon representing "Groups" / multi-window layouts.
public struct GroupWindowIcon: View {
    public let size: CGFloat
    public var isHighlighted: Bool = false
    public var paneCount: Int = 2
    
    public init(size: CGFloat = 20, isHighlighted: Bool = false, paneCount: Int = 2) {
        self.size = size
        self.isHighlighted = isHighlighted
        self.paneCount = paneCount
    }
    
    public var body: some View {
        let frameCornerRadius = size * 0.22
        let borderWidth = max(1.1, size * 0.065)
        let strokeColor = isHighlighted ? Color(hex: "1A73E8") : Color.secondary.opacity(0.45)
        let fillColor = isHighlighted ? Color(hex: "1A73E8").opacity(0.12) : Color.primary.opacity(0.04)
        let titlebarColor = isHighlighted ? Color(hex: "1A73E8").opacity(0.65) : Color.secondary.opacity(0.4)
        let paneColor = isHighlighted ? Color(hex: "1A73E8").opacity(0.3) : Color.secondary.opacity(0.2)
        
        ZStack {
            // Window Outer Rounded Frame
            RoundedRectangle(cornerRadius: frameCornerRadius, style: .continuous)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: frameCornerRadius, style: .continuous)
                        .stroke(strokeColor, lineWidth: borderWidth)
                )
            
            // Window Inner Structure (Header titlebar line + split panes)
            VStack(spacing: max(1.5, size * 0.08)) {
                // Top Titlebar
                HStack(spacing: max(1.5, size * 0.06)) {
                    // Window dot
                    Circle()
                        .fill(titlebarColor)
                        .frame(width: max(2, size * 0.1), height: max(2, size * 0.1))
                    
                    Rectangle()
                        .fill(titlebarColor)
                        .frame(height: max(1.5, size * 0.08))
                        .clipShape(Capsule())
                }
                .padding(.top, max(1, size * 0.06))
                
                // Panes representation
                if paneCount >= 3 {
                    // Split with right stack or quad
                    HStack(spacing: max(1.5, size * 0.07)) {
                        RoundedRectangle(cornerRadius: max(1, size * 0.06), style: .continuous)
                            .fill(paneColor)
                        
                        VStack(spacing: max(1.5, size * 0.07)) {
                            RoundedRectangle(cornerRadius: max(1, size * 0.06), style: .continuous)
                                .fill(paneColor)
                            RoundedRectangle(cornerRadius: max(1, size * 0.06), style: .continuous)
                                .fill(paneColor)
                        }
                    }
                } else {
                    // 2 Panes Split
                    HStack(spacing: max(1.5, size * 0.07)) {
                        RoundedRectangle(cornerRadius: max(1, size * 0.06), style: .continuous)
                            .fill(paneColor)
                        RoundedRectangle(cornerRadius: max(1, size * 0.06), style: .continuous)
                            .fill(paneColor)
                    }
                }
            }
            .padding(.horizontal, max(2.5, size * 0.14))
            .padding(.bottom, max(2.5, size * 0.14))
            .padding(.top, max(1.5, size * 0.08))
        }
        .frame(width: size, height: size * 0.78)
    }
}
