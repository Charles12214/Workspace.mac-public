import SwiftUI
import AppKit
import UniformTypeIdentifiers

// Drop Delegate for Pinned Apps
public struct PinnedAppsDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onPinApp: (String) -> Void
    
    public init(isTargeted: Binding<Bool>, onPinApp: @escaping (String) -> Void) {
        self._isTargeted = isTargeted
        self.onPinApp = onPinApp
    }
    
    public func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.utf8PlainText, .plainText, .text])
    }
    
    public func dropEntered(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isTargeted = true
        }
    }
    
    public func dropExited(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isTargeted = false
        }
    }
    
    public func performDrop(info: DropInfo) -> Bool {
        withAnimation(.easeInOut(duration: 0.15)) {
            isTargeted = false
        }
        
        let providers = info.itemProviders(for: [.utf8PlainText, .plainText, .text])
        guard let provider = providers.first else { return false }
        
        _ = provider.loadObject(ofClass: NSString.self) { string, _ in
            if let appId = string as? String {
                DispatchQueue.main.async {
                    onPinApp(appId)
                }
            }
        }
        return true
    }
}

public struct HomeView: View {
    @ObservedObject var state: AppState
    @ObservedObject var greetingManager: GreetingManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPinDropTargeted: Bool = false
    @State private var isHoveringContinueCard: Bool = false
    
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
                
                // MARK: - Animated Gemini Greeting Section & Home Weather Dashboard
                HStack(alignment: .top, spacing: 20) {
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
                    
                    Spacer(minLength: 16)
                    
                    // Large Home Screen Weather & Clock Dashboard Widget
                    HomeWeatherClockWidgetView()
                }
                
                // MARK: - "Continue where you left off" Hero Section
                if let doc = state.lastOpenedDocument {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: "1A73E8"))
                            
                            Text("CONTINUE WHERE YOU LEFT OFF")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .tracking(0.8)
                            
                            Spacer()
                        }
                        
                        Button(action: {
                            state.resumeLastDocument()
                        }) {
                            HStack(spacing: 16) {
                                // App Icon
                                GoogleAppIconView(appId: doc.appId, size: 38)
                                    .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                                
                                // Titles (Large App Title, Small Document Subtitle)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(doc.appName)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    
                                    Text(doc.documentTitle)
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                // Pill Resume Action Button
                                HStack(spacing: 6) {
                                    Text("Resume")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "1A73E8"))
                                )
                                .foregroundStyle(Color.white)
                                .shadow(color: Color(hex: "1A73E8").opacity(0.35), radius: isHoveringContinueCard ? 8 : 4, x: 0, y: 2)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isHoveringContinueCard ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        isHoveringContinueCard ? Color(hex: "1A73E8").opacity(0.5) : Color.primary.opacity(0.08),
                                        lineWidth: isHoveringContinueCard ? 1.5 : 1
                                    )
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isHoveringContinueCard = hovering
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
                                        onTogglePin: { state.togglePin(appId: app.id) },
                                        onOpenSeparate: { state.openSeparateWindow(for: app) }
                                    )
                                }
                            }
                            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: state.hideTileTitles)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                
                // MARK: - Pinned Apps Section (Drop Target for Drag & Drop Pinning)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 6) {
                            Text("Pinned Apps")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            
                            if isPinDropTargeted {
                                Text("• Drop to Pin!")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "1A73E8"))
                            }
                        }
                        
                        Spacer()
                        
                        if !state.pinnedApps.isEmpty {
                            Text("\(state.pinnedApps.count) pinned")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    ZStack {
                        if state.pinnedApps.isEmpty {
                            HStack(spacing: 12) {
                                Image(systemName: isPinDropTargeted ? "arrow.down.circle.fill" : "pin")
                                    .font(.system(size: 16))
                                    .foregroundStyle(isPinDropTargeted ? Color(hex: "1A73E8") : .secondary)
                                
                                Text(isPinDropTargeted ? "Release to pin app to your dashboard!" : "Drag & drop apps here, or pin from the sidebar to access them quickly.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(isPinDropTargeted ? Color(hex: "1A73E8") : .secondary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isPinDropTargeted ? Color(hex: "1A73E8").opacity(0.12) : Color.primary.opacity(0.03))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        isPinDropTargeted ? Color(hex: "1A73E8") : Color.primary.opacity(0.06),
                                        style: StrokeStyle(lineWidth: isPinDropTargeted ? 2 : 1, dash: isPinDropTargeted ? [6, 4] : [])
                                    )
                            )
                        } else {
                            LazyVGrid(columns: gridColumns, spacing: 12) {
                                ForEach(state.pinnedApps) { app in
                                    ModernQuarterIconTile(
                                        app: app,
                                        hideTitle: state.hideTileTitles,
                                        onLaunch: { state.launchApp(app) },
                                        onTogglePin: { state.togglePin(appId: app.id) },
                                        onOpenSeparate: { state.openSeparateWindow(for: app) }
                                    )
                                }
                            }
                            .padding(isPinDropTargeted ? 8 : 0)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isPinDropTargeted ? Color(hex: "1A73E8").opacity(0.08) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        isPinDropTargeted ? Color(hex: "1A73E8") : Color.clear,
                                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                                    )
                            )
                            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: state.hideTileTitles)
                        }
                    }
                    .contentShape(Rectangle())
                    .onDrop(
                        of: [.utf8PlainText, .plainText, .text],
                        delegate: PinnedAppsDropDelegate(isTargeted: $isPinDropTargeted) { appId in
                            state.setPinned(appId: appId, pinned: true)
                        }
                    )
                }
                .contentShape(Rectangle())
                .onDrop(
                    of: [.utf8PlainText, .plainText, .text],
                    delegate: PinnedAppsDropDelegate(isTargeted: $isPinDropTargeted) { appId in
                        state.setPinned(appId: appId, pinned: true)
                    }
                )
                
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
    public let onOpenSeparate: (() -> Void)?
    
    @State private var isHovered = false
    
    public init(
        app: WorkspaceAppItem,
        hideTitle: Bool,
        onLaunch: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onOpenSeparate: (() -> Void)? = nil
    ) {
        self.app = app
        self.hideTitle = hideTitle
        self.onLaunch = onLaunch
        self.onTogglePin = onTogglePin
        self.onOpenSeparate = onOpenSeparate
    }
    
    public var body: some View {
        Group {
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
                    
                    // Centered Real App Icon
                    VStack {
                        Spacer()
                        GoogleAppIconView(appId: app.id, size: 30)
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
                    
                    // Enlarged real icon in bottom right corner (quarter preview watermark)
                    GeometryReader { geo in
                        GoogleAppIconView(appId: app.id, size: 68)
                            .opacity(isHovered ? 0.45 : 0.20)
                            .rotationEffect(.degrees(isHovered ? -12 : 0))
                            .offset(x: isHovered ? -10 : 0, y: isHovered ? -10 : 0)
                            .scaleEffect(isHovered ? 1.06 : 1.0)
                            .position(x: geo.size.width + 10, y: geo.size.height + 10)
                            .allowsHitTesting(false)
                            .animation(.spring(response: 0.38, dampingFraction: 0.65), value: isHovered)
                    }
                    .clipped()
                    
                    // Title and Pin Controls - Perfectly anchored at top
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top) {
                            HStack(spacing: 8) {
                                GoogleAppIconView(appId: app.id, size: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.primary)
                                        .lineLimit(1)
                                    
                                    Text(app.category.rawValue)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
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
                            .help(app.isPinned ? "Unpin App" : "Pin App to Dashboard")
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
        .contentShape(Rectangle())
        .onTapGesture {
            onLaunch()
        }
        .onDrag {
            let provider = NSItemProvider(object: app.id as NSString)
            provider.suggestedName = app.name
            return provider
        }
        .contextMenu {
            if let onOpenSeparate = onOpenSeparate {
                Button(action: onOpenSeparate) {
                    Label("Open in Separate Window", systemImage: "arrow.up.forward.app")
                }
            }
            Button(action: onTogglePin) {
                Label(app.isPinned ? "Unpin App" : "Pin App to Dashboard", systemImage: app.isPinned ? "pin.slash" : "pin")
            }
        }
        .onHover { h in
            withAnimation(.spring(response: 0.38, dampingFraction: 0.65)) {
                isHovered = h
            }
        }
    }
}
