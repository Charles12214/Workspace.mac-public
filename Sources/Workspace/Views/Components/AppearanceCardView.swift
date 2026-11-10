import SwiftUI
import AppKit

public struct AppearancePickerView: View {
    @Binding public var selection: AppearanceMode
    
    public init(selection: Binding<AppearanceMode>) {
        self._selection = selection
    }
    
    public var body: some View {
        HStack(spacing: 24) {
            ForEach(AppearanceMode.allCases) { mode in
                AppearanceOptionCard(
                    mode: mode,
                    isSelected: selection == mode
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selection = mode
                    }
                }
            }
        }
    }
}

public struct AppearanceOptionCard: View {
    public let mode: AppearanceMode
    public let isSelected: Bool
    public let onSelect: () -> Void
    
    @State private var isHovered = false
    
    public var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 10) {
                // Professional Vector Replica Card
                ProfessionalAppearancePreview(mode: mode)
                    .frame(width: 130, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isSelected ? Color(hex: "FF9500") : (isHovered ? Color.primary.opacity(0.25) : Color.primary.opacity(0.1)),
                                lineWidth: isSelected ? 3 : 1
                            )
                            .padding(-3)
                    )
                    .shadow(
                        color: isSelected ? Color(hex: "FF9500").opacity(0.3) : Color.black.opacity(0.12),
                        radius: isSelected ? 8 : 3,
                        x: 0,
                        y: 2
                    )
                
                // Clean single label (Fix duplicate label bug)
                Text(mode.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            .scaleEffect(isSelected ? 1.02 : (isHovered ? 1.01 : 1.0))
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.16)) {
                isHovered = h
            }
        }
    }
}

// MARK: - Professional macOS Vector Replica
public struct ProfessionalAppearancePreview: View {
    public let mode: AppearanceMode
    
    public var body: some View {
        ZStack {
            // Elegant subtle desktop background
            LinearGradient(
                colors: [
                    Color(hex: "173A66"),
                    Color(hex: "1F5F9E"),
                    Color(hex: "2775C4")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Mini macOS top bar with Apple logo
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "applelogo")
                        .font(.system(size: 6))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(.leading, 7)
                        .padding(.top, 4)
                    Spacer()
                }
                Spacer()
            }
            
            // Mode-specific window graphics
            switch mode {
            case .light:
                miniWindow(isDark: false)
            case .dark:
                miniWindow(isDark: true)
            case .auto:
                HStack(spacing: 0) {
                    miniWindow(isDark: false)
                        .frame(width: 65)
                        .clipped()
                    miniWindow(isDark: true)
                        .frame(width: 65)
                        .clipped()
                }
            }
        }
    }
    
    @ViewBuilder
    private func miniWindow(isDark: Bool) -> some View {
        VStack(spacing: 0) {
            // Floating mini preview banner
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isDark ? Color(hex: "242A35") : Color(hex: "E8EEF5"))
                .frame(width: 86, height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color(hex: "FF9500"))
                        .frame(width: 66, height: 7)
                )
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                .padding(.top, 12)
            
            Spacer()
            
            // Main window lower frame with traffic lights
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isDark ? Color(hex: "1E222A") : Color(hex: "FFFFFF"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.1), lineWidth: 0.8)
                    )
                
                // Traffic light dots
                HStack(spacing: 3.5) {
                    Circle().fill(Color(hex: "FF5F56")).frame(width: 5, height: 5)
                    Circle().fill(Color(hex: "FFBD2E")).frame(width: 5, height: 5)
                    Circle().fill(Color(hex: "27C93F")).frame(width: 5, height: 5)
                }
                .padding(.leading, 8)
                .padding(.top, 8)
            }
            .frame(width: 104, height: 38)
            .offset(y: 8)
        }
    }
}
