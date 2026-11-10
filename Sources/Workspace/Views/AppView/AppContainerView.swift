import SwiftUI
import WebKit
import AppKit

// MARK: - View Mode Visual Selector Icons
public struct ViewModeIcon: View {
    public let mode: AppViewMode
    public let isSelected: Bool
    
    public init(mode: AppViewMode, isSelected: Bool) {
        self.mode = mode
        self.isSelected = isSelected
    }
    
    public var body: some View {
        let accentColor = isSelected ? Color(hex: "1A73E8") : Color.secondary.opacity(0.65)
        
        ZStack {
            // Window Outline
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .stroke(accentColor, lineWidth: 1.2)
                .frame(width: 18, height: 13.5)
            
            // Inner layout content clipped strictly inside the rounded window outline
            ZStack(alignment: .topLeading) {
                switch mode {
                case .everything:
                    // Top bar
                    Rectangle()
                        .fill(accentColor)
                        .frame(width: 18, height: 3.2)
                    
                    // Left sidebar
                    Rectangle()
                        .fill(accentColor)
                        .frame(width: 4.8, height: 13.5)
                    
                case .essentials:
                    // Top bar only
                    Rectangle()
                        .fill(accentColor)
                        .frame(width: 18, height: 3.2)
                    
                case .minimalist:
                    EmptyView()
                    
                case .separated:
                    // Window with separated pop-out arrow badge
                    Rectangle()
                        .fill(accentColor)
                        .frame(width: 18, height: 3.2)
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(accentColor)
                        .offset(x: 3.5, y: 1.5)
                }
            }
            .frame(width: 18, height: 13.5)
            .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
        }
        .frame(width: 24, height: 20)
        .contentShape(Rectangle())
    }
}

// MARK: - Main App Container View
public struct WorkspaceAppContainer: View {
    public let app: WorkspaceAppItem
    @ObservedObject public var state: AppState
    @Binding public var showingSettings: Bool
    
    @State private var webView: WKWebView? = nil
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var isLoading: Bool = true
    @State private var currentUrlString: String = ""
    @State private var pageTitle: String = ""
    
    // Minimalist mode top-middle hover state
    @State private var isHoveringTopMiddle: Bool = false
    
    // Left edge hover state for bookmark arrow
    @State private var isHoveringLeftEdge: Bool = false
    @State private var isDraggingBookmark: Bool = false
    
    public init(app: WorkspaceAppItem, state: AppState, showingSettings: Binding<Bool>) {
        self.app = app
        self.state = state
        self._showingSettings = showingSettings
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // MARK: - Main Layout
                HStack(spacing: 0) {
                    // Sidebar shown docked in "Everything" mode
                    if state.appViewMode == .everything {
                        SidebarView(state: state, showingSettings: $showingSettings)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        Divider().opacity(0.2)
                    }
                    
                    // Main Content (Top Bar + Web View)
                    VStack(spacing: 0) {
                        // Top Bar (Shown in Everything and Essentials modes)
                        if state.appViewMode != .minimalist {
                            appTopBarView
                                .transition(.move(edge: .top).combined(with: .opacity))
                            Divider().opacity(0.2)
                        }
                        
                        // Embedded WebKit View
                        ZStack(alignment: .top) {
                            WebKitRepresentable(
                                url: app.resolvedUrl(for: state.userProfile.email),
                                webViewOut: $webView,
                                canGoBack: $canGoBack,
                                canGoForward: $canGoForward,
                                isLoading: $isLoading,
                                currentUrlString: $currentUrlString,
                                pageTitle: $pageTitle
                            )
                            .ignoresSafeArea()
                            
                            // Top loading line
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.linear)
                                    .frame(height: 2)
                                    .accentColor(app.primaryColor)
                                    .ignoresSafeArea()
                            }
                            
                            // Top Windowed-Fullscreen Zoom Trigger (Double-click)
                            Color.clear
                                .frame(height: 24)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    if let window = NSApp.keyWindow ?? NSApp.windows.first {
                                        window.zoom(nil)
                                    }
                                }
                        }
                    }
                }
                
                // MARK: - Minimalist Mode: Top-Middle Hover Dropdown Menu
                if state.appViewMode == .minimalist {
                    VStack {
                        ZStack(alignment: .top) {
                            // Top-middle invisible trigger zone
                            Color.clear
                                .frame(width: 380, height: 46)
                                .contentShape(Rectangle())
                                .onHover { hovering in
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                        isHoveringTopMiddle = hovering
                                    }
                                }
                            
                            // Floating Top-Middle Popup Menu (Emerges when hovering top middle)
                            topMiddlePopupMenu
                                .opacity(isHoveringTopMiddle ? 1.0 : 0.0)
                                .offset(y: isHoveringTopMiddle ? 10 : -35)
                                .scaleEffect(isHoveringTopMiddle ? 1.0 : 0.92, anchor: .top)
                                .onHover { hovering in
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                        isHoveringTopMiddle = hovering
                                    }
                                }
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .zIndex(20)
                }
                
                // MARK: - Left Edge Hover Zone & Draggable Bookmark Arrow
                // "an arrow like a bookmark sticks out with an arrow pointing out from the sidebar's left side if the user's mouse hovers near the left side. the user can drag it up and down if it gets in the way."
                if state.appViewMode != .everything && !state.isManualSidebarOpenInApp {
                    // Left edge trigger zone
                    Color.clear
                        .frame(width: 32, height: geometry.size.height)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isHoveringLeftEdge = hovering
                            }
                        }
                        .zIndex(15)
                    
                    // Draggable Bookmark Tab
                    draggableBookmarkTab(windowHeight: geometry.size.height)
                        .position(x: 14, y: state.bookmarkTabOffsetY)
                        .zIndex(16)
                }
                
                // MARK: - Sliding Overlay Sidebar (When manually toggled in Essentials or Minimalist mode)
                if state.isManualSidebarOpenInApp && state.appViewMode != .everything {
                    // Scrim to tap-to-dismiss
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                state.isManualSidebarOpenInApp = false
                            }
                        }
                        .zIndex(25)
                    
                    HStack(spacing: 0) {
                        SidebarView(state: state, showingSettings: $showingSettings)
                            .frame(width: state.isSidebarCollapsed ? 58 : 255)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .shadow(color: Color.black.opacity(0.4), radius: 16, x: 6, y: 0)
                            .transition(.move(edge: .leading))
                        
                        Spacer()
                    }
                    .ignoresSafeArea(.container, edges: .top)
                    .zIndex(30)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: state.appViewMode)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: state.isManualSidebarOpenInApp)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .ignoresSafeArea(.container, edges: .top)
    }
    
    // MARK: - Draggable Bookmark Tab
    private func draggableBookmarkTab(windowHeight: CGFloat) -> some View {
        HStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    state.isManualSidebarOpenInApp.toggle()
                }
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                        .offset(x: isHoveringLeftEdge ? 1 : 0)
                }
                .frame(width: 24, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: "1A73E8"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 6, x: 2, y: 2)
            }
            .buttonStyle(.plain)
            .help("Click to open sidebar • Drag up/down to reposition")
        }
        .opacity(isHoveringLeftEdge || isDraggingBookmark ? 1.0 : 0.45)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDraggingBookmark = true
                    let newY = state.bookmarkTabOffsetY + value.translation.height
                    state.bookmarkTabOffsetY = max(60, min(windowHeight - 80, newY))
                }
                .onEnded { _ in
                    isDraggingBookmark = false
                }
        )
    }
    
    // MARK: - Top Bar (Everything & Essentials)
    private var appTopBarView: some View {
        HStack(spacing: 12) {
            // Space for macOS traffic lights when sidebar is not docked
            if state.appViewMode != .everything && !state.isManualSidebarOpenInApp {
                Color.clear.frame(width: 68, height: 1)
            }
            
            // Manual Sidebar Toggle (Shows when sidebar is not permanently docked)
            if state.appViewMode != .everything {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        state.isManualSidebarOpenInApp.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.primary)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Toggle Sidebar")
            }
            
            // Return Home Button (No gradient)
            Button(action: { state.goHome() }) {
                HStack(spacing: 5) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 12))
                    Text("Home")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color(hex: "1A73E8"))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(Color(hex: "1A73E8").opacity(0.12))
                )
                .overlay(
                    Capsule().stroke(Color(hex: "1A73E8").opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Return to Workspace Home")
            
            // Navigation Controls (Back / Forward / Reload)
            HStack(spacing: 4) {
                Button(action: { webView?.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(canGoBack ? Color.primary : Color.secondary.opacity(0.3))
                        .padding(6)
                }
                .buttonStyle(.plain)
                .disabled(!canGoBack)
                .help("Back")
                
                Button(action: { webView?.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(canGoForward ? Color.primary : Color.secondary.opacity(0.3))
                        .padding(6)
                }
                .buttonStyle(.plain)
                .disabled(!canGoForward)
                .help("Forward")
                
                Button(action: {
                    if isLoading { webView?.stopLoading() } else { webView?.reload() }
                }) {
                    Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .help("Reload")
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
            
            // Clickable Zoom In / Out (+ / -) Controls
            HStack(spacing: 2) {
                Button(action: { state.zoomOut() }) {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Zoom Out (Cmd -)")
                
                Button(action: { state.resetZoom() }) {
                    Text("\(Int(round(state.currentZoom * 100)))%")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 3)
                }
                .buttonStyle(.plain)
                .help("Reset Zoom to 100% (Cmd 0)")
                
                Button(action: { state.zoomIn() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Zoom In (Cmd +)")
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.primary.opacity(0.04)))
            
            Spacer()
            
            // App Title & Icon in Center
            HStack(spacing: 7) {
                GoogleAppIconView(appId: app.id, size: 16)
                
                Text(app.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(hex: "34A853"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.primary.opacity(0.04)))
            
            Spacer()
            
            // MARK: - Open in Separate Window Button
            Button(action: { state.openSeparateWindow(for: app) }) {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .help("Open \(app.name) in Separate Window")
            
            // MARK: - View Mode Switcher (Everything, Essentials, Minimalist, Separated)
            HStack(spacing: 2) {
                viewModeButton(mode: .everything, help: "Everything: Sidebar and Top Bar")
                viewModeButton(mode: .essentials, help: "Essentials: Top Bar only (Default)")
                viewModeButton(mode: .minimalist, help: "Minimalist: 'At a glance' Fullscreen")
                viewModeButton(mode: .separated, help: "Separated: Standalone Windows")
            }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
            
            // Settings Button
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .help("Workspace Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                Color.primary.opacity(0.02)
            }
        )
    }
    
    // Helper for View Mode Button
    private func viewModeButton(mode: AppViewMode, help: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                state.appViewMode = mode
                if mode == .separated {
                    state.openSeparateWindow(for: app)
                    state.goHome()
                }
            }
        }) {
            ViewModeIcon(mode: mode, isSelected: state.appViewMode == mode)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(state.appViewMode == mode ? Color(hex: "1A73E8").opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
    
    // MARK: - Minimalist Floating Top-Middle Popup Menu
    private var topMiddlePopupMenu: some View {
        HStack(spacing: 10) {
            // Sidebar Toggle
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    state.isManualSidebarOpenInApp.toggle()
                }
            }) {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .help("Open Sidebar")
            
            // Home Button
            Button(action: { state.goHome() }) {
                HStack(spacing: 5) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 11))
                    Text("Home")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color(hex: "1A73E8")))
            }
            .buttonStyle(.plain)
            .help("Return Home")
            
            // App Icon & Name
            HStack(spacing: 6) {
                GoogleAppIconView(appId: app.id, size: 14)
                Text(app.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            
            Divider().frame(height: 14).opacity(0.3)
            
            // Back & Reload
            HStack(spacing: 2) {
                Button(action: { webView?.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(canGoBack ? Color.primary : Color.secondary.opacity(0.3))
                        .padding(5)
                }
                .buttonStyle(.plain)
                .disabled(!canGoBack)
                
                Button(action: {
                    if isLoading { webView?.stopLoading() } else { webView?.reload() }
                }) {
                    Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(5)
                }
                .buttonStyle(.plain)
            }
            
            Divider().frame(height: 14).opacity(0.3)
            
            // View Mode Icons in Popup
            HStack(spacing: 2) {
                viewModeButton(mode: .everything, help: "Everything Mode")
                viewModeButton(mode: .essentials, help: "Essentials Mode")
                viewModeButton(mode: .minimalist, help: "Minimalist Mode")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 6)
        )
        .overlay(
            Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }
}
