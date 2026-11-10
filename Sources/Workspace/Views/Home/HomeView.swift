import SwiftUI
import AppKit

public struct HomeView: View {
    @ObservedObject var state: AppState
    @ObservedObject var greetingManager: GreetingManager
    @Environment(\.colorScheme) private var colorScheme
    
    private let geminiGradient = LinearGradient(
        colors: [
            GeminiPalette.red,
            GeminiPalette.yellow,
            GeminiPalette.green,
            GeminiPalette.blue
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    private var gridColumns: [GridItem] {
        if state.hideTileTitles {
            return [GridItem(.adaptive(minimum: 64, maximum: 74), spacing: 12)]
        } else {
            return [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 14)]
        }
    }
    
    public init(state: AppState, greetingManager: GreetingManager = .shared) {
        self.state = state
        self.greetingManager = greetingManager
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 26) {
                // MARK: - Double-Click Top Window Header (Windowed Fullscreen Zoom)
                Color.clear
                    .frame(height: 20)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if let window = NSApp.keyWindow ?? NSApp.windows.first {
                            window.zoom(nil)
                        }
                    }
                
                // MARK: - Animated Gemini Greeting Section
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        GeminiSparkleShape()
                            .fill(GeminiPalette.starGradient)
                            .frame(width: 17, height: 17)
                        
                        Text("GEMINI WORKSPACE.MAC")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(geminiGradient)
                            .tracking(1.0)
                        
                        Spacer()
                    }
                    
                    AnimatedUpriseBlurText(
                        greetingManager.currentGreeting(for: state.userProfile.greetingName),
                        font: .system(size: 30, weight: .bold, design: .rounded),
                        color: Color.primary
                    )
                    .id(greetingManager.animationTrigger)
                    .padding(.vertical, 2)
                    
                    Text(state.userProfile.tier.summaryText(name: state.userProfile.greetingName))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                // MARK: - Recently Used Section (Collapsible!)
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            state.isRecentlyUsedCollapsed.toggle()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text("Recently Used")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(state.isRecentlyUsedCollapsed ? 0 : 90))
                            
                            Spacer()
                            
                            if state.isRecentlyUsedCollapsed && !state.recentlyUsedApps.isEmpty {
                                Text("\(state.recentlyUsedApps.count) apps")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.primary.opacity(0.05)))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    if !state.isRecentlyUsedCollapsed {
                        if state.recentlyUsedApps.isEmpty {
                            HStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.secondary)
                                
                                Text("No recently used apps")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.primary.opacity(0.03))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            LazyVGrid(columns: gridColumns, spacing: 12) {
                                ForEach(state.recentlyUsedApps.prefix(state.hideTileTitles ? 8 : 4)) { app in
                                    ModernQuarterIconTile(
                                        app: app,
                                        hideTitle: state.hideTileTitles,
                                        onLaunch: { state.launchApp(app) },
                                        onTogglePin: { state.togglePin(appId: app.id) }
                                    )
                                }
                            }
                            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: state.hideTileTitles)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                
                // MARK: - Pinned Apps Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Pinned Apps")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        if !state.pinnedApps.isEmpty {
                            Text("\(state.pinnedApps.count) pinned")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if state.pinnedApps.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "pin")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                            
                            Text("Pin your favorite apps from the sidebar to access them quickly here.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.primary.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(state.pinnedApps) { app in
                                ModernQuarterIconTile(
                                    app: app,
                                    hideTitle: state.hideTileTitles,
                                    onLaunch: { state.launchApp(app) },
                                    onTogglePin: { state.togglePin(appId: app.id) }
                                )
                            }
                        }
                        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: state.hideTileTitles)
                    }
                }
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 32)
        }
        .background(
            colorScheme == .dark
                ? Color.black
                : Color.white
        )
    }
}

// MARK: - Modern App Tile (Shortens to Icon Only when hideTitle is true)
public struct ModernQuarterIconTile: View {
    public let app: WorkspaceAppItem
    public let hideTitle: Bool
    public let onLaunch: () -> Void
    public let onTogglePin: () -> Void
    
    @State private var isHovered = false
    
    public init(
        app: WorkspaceAppItem,
        hideTitle: Bool,
        onLaunch: @escaping () -> Void,
        onTogglePin: @escaping () -> Void
    ) {
        self.app = app
        self.hideTitle = hideTitle
        self.onLaunch = onLaunch
        self.onTogglePin = onTogglePin
    }
    
    public var body: some View {
        Button(action: onLaunch) {
            if hideTitle {
                // MARK: - Compact Shortened Icon-Only Tile
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    app.primaryColor.opacity(isHovered ? 0.24 : 0.12),
                                    app.secondaryColor.opacity(isHovered ? 0.16 : 0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Centered App Icon
                    VStack {
                        Spacer()
                        Image(systemName: app.iconSymbol)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(app.primaryColor)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Small Pin Badge
                    if app.isPinned || isHovered {
                        Button(action: onTogglePin) {
                            Image(systemName: app.isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 9))
                                .foregroundStyle(app.isPinned ? Color(hex: "F4B400") : Color.secondary.opacity(0.4))
                                .padding(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 66, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isHovered ? app.primaryColor.opacity(0.5) : Color.primary.opacity(0.08),
                            lineWidth: isHovered ? 1.5 : 1
                        )
                )
                .shadow(color: isHovered ? app.primaryColor.opacity(0.2) : Color.clear, radius: 6, y: 2)
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .help(app.name)
            } else {
                // MARK: - Full Wide Tile with Enlarged Quarter Watermark
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    app.primaryColor.opacity(isHovered ? 0.18 : 0.08),
                                    app.secondaryColor.opacity(isHovered ? 0.12 : 0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Enlarged icon in bottom right corner (quarter preview watermark)
                    // Placed via GeometryReader so it never affects the top layout or text alignment
                    // Features a playful "Peek out" animation on hover (angles up & slides into view)
                    GeometryReader { geo in
                        Image(systemName: app.iconSymbol)
                            .font(.system(size: 78, weight: .bold))
                            .foregroundStyle(
                                app.primaryColor.opacity(isHovered ? 0.45 : 0.22)
                            )
                            .rotationEffect(.degrees(isHovered ? -14 : 0))
                            .offset(x: isHovered ? -12 : 0, y: isHovered ? -12 : 0)
                            .scaleEffect(isHovered ? 1.06 : 1.0)
                            .position(x: geo.size.width + 12, y: geo.size.height + 12)
                            .allowsHitTesting(false)
                            .animation(.spring(response: 0.38, dampingFraction: 0.65), value: isHovered)
                    }
                    .clipped()
                    
                    // Title and Pin Controls - Perfectly anchored at top
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.name)
                                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.primary)
                                    .lineLimit(1)
                                
                                Text(app.category.rawValue)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Pin button
                            Button(action: onTogglePin) {
                                Image(systemName: app.isPinned ? "pin.fill" : "pin")
                                    .font(.system(size: 11))
                                    .foregroundStyle(app.isPinned ? Color(hex: "F4B400") : Color.secondary.opacity(0.35))
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                }
                .frame(height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isHovered ? app.primaryColor.opacity(0.45) : Color.primary.opacity(0.08),
                            lineWidth: isHovered ? 1.5 : 1
                        )
                )
                .shadow(color: isHovered ? app.primaryColor.opacity(0.18) : Color.clear, radius: 8, y: 3)
                .scaleEffect(isHovered ? 1.015 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.spring(response: 0.38, dampingFraction: 0.65)) {
                isHovered = h
            }
        }
    }
}
