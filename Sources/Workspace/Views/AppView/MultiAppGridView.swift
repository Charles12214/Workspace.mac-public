import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

// MARK: - Multi-App Tiling & Split-Screen Grid View (Up to 4 Apps)
public struct MultiAppGridView: View {
    @ObservedObject public var state: AppState
    public let defaultApp: WorkspaceAppItem
    
    // Drag & Drop State
    @State private var isDraggingOverCanvas: Bool = false
    @State private var hoveredDropZone: DropZoneTarget? = nil
    
    // First-Time Resource Warning State
    @State private var dontShowWarningAgain: Bool = false
    
    private enum DropZoneTarget: Equatable {
        case leftHalf
        case rightHalf
        case topHalf
        case bottomHalf
        case quadrant(Int) // 0...3
    }
    
    public init(state: AppState, defaultApp: WorkspaceAppItem) {
        self.state = state
        self.defaultApp = defaultApp
    }
    
    private var activeApps: [WorkspaceAppItem] {
        if state.tiledApps.isEmpty {
            return [defaultApp]
        }
        return state.tiledApps
    }
    
    public var body: some View {
        ZStack {
            // Main Grid Layout
            GeometryReader { geometry in
                ZStack {
                    gridLayout(for: activeApps, in: geometry.size)
                    
                    // Drag and Drop Visual Zones Overlay
                    if isDraggingOverCanvas && activeApps.count < 4 {
                        dropZonesOverlay(size: geometry.size)
                            .transition(.opacity)
                    }
                }
                .onDrop(of: [UTType.text.identifier, UTType.plainText.identifier, "public.text"], isTargeted: $isDraggingOverCanvas) { providers in
                    handleDrop(providers: providers)
                }
            }
            
            // First-Time Multitasking Resource Warning Sheet / Modal
            if state.showingMultitaskingWarning {
                multitaskingResourceWarningModal
                    .zIndex(100)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        // Global Keyboard Shortcuts for Spot Cycling
        .background(
            HStack {
                Button("") { state.cycleTiledApps(clockwise: true) }
                    .keyboardShortcut("]", modifiers: [.command, .shift])
                Button("") { state.cycleTiledApps(clockwise: false) }
                    .keyboardShortcut("[", modifiers: [.command, .shift])
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        )
    }
    
    // MARK: - Responsive Grid Layout
    @ViewBuilder
    private func gridLayout(for apps: [WorkspaceAppItem], in size: CGSize) -> some View {
        switch apps.count {
        case 1:
            // 1 App: Full Window
            TiledAppPaneView(
                app: apps[0],
                state: state,
                isSingleApp: true,
                paneIndex: 0
            )
            .id(apps[0].id)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case 2:
            // 2 Apps: 50 / 50 Side-by-Side Split
            HStack(spacing: 8) {
                TiledAppPaneView(app: apps[0], state: state, isSingleApp: false, paneIndex: 0)
                    .id(apps[0].id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                TiledAppPaneView(app: apps[1], state: state, isSingleApp: false, paneIndex: 1)
                    .id(apps[1].id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: state.tiledAppIds)
            
        case 3:
            // 3 Apps: Master on Left (50%), 2 Stacked on Right (50% each)
            HStack(spacing: 8) {
                TiledAppPaneView(app: apps[0], state: state, isSingleApp: false, paneIndex: 0)
                    .id(apps[0].id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                VStack(spacing: 8) {
                    TiledAppPaneView(app: apps[1], state: state, isSingleApp: false, paneIndex: 1)
                        .id(apps[1].id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    TiledAppPaneView(app: apps[2], state: state, isSingleApp: false, paneIndex: 2)
                        .id(apps[2].id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(8)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: state.tiledAppIds)
            
        case 4:
            // 4 Apps: 2x2 Quad Grid
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TiledAppPaneView(app: apps[0], state: state, isSingleApp: false, paneIndex: 0)
                        .id(apps[0].id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    TiledAppPaneView(app: apps[1], state: state, isSingleApp: false, paneIndex: 1)
                        .id(apps[1].id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                HStack(spacing: 8) {
                    TiledAppPaneView(app: apps[2], state: state, isSingleApp: false, paneIndex: 2)
                        .id(apps[2].id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    TiledAppPaneView(app: apps[3], state: state, isSingleApp: false, paneIndex: 3)
                        .id(apps[3].id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(8)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: state.tiledAppIds)
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Drag & Drop Zones Visual Overlay
    private func dropZonesOverlay(size: CGSize) -> some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            
            HStack(spacing: 12) {
                // Drop Target: Split Left / First
                dropZoneCard(
                    title: "Tile Left / First",
                    icon: "rectangle.righthalf.inset.filled",
                    isHovered: hoveredDropZone == .leftHalf
                )
                
                // Drop Target: Split Right / Add
                dropZoneCard(
                    title: activeApps.count == 1 ? "Split Right" : (activeApps.count == 2 ? "Add 3rd Pane" : "Add 4th Pane"),
                    icon: activeApps.count == 1 ? "rectangle.split.2x1.fill" : (activeApps.count == 2 ? "rectangle.split.3x1.fill" : "square.grid.2x2.fill"),
                    isHovered: hoveredDropZone == .rightHalf
                )
            }
            .padding(40)
        }
    }
    
    private func dropZoneCard(title: String, icon: String, isHovered: Bool) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(isHovered ? Color.white : Color.white.opacity(0.8))
            
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
            
            Text("Release to tile application")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: "1A73E8").opacity(isHovered ? 0.85 : 0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(isHovered ? 0.9 : 0.4), lineWidth: isHovered ? 2.5 : 1.5)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 14)
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
            var appIdString: String? = nil
            
            if let str = item as? String {
                appIdString = str
            } else if let data = item as? Data, let str = String(data: data, encoding: .utf8) {
                appIdString = str
            } else if let url = item as? URL {
                appIdString = url.lastPathComponent
            }
            
            if let appId = appIdString?.trimmingCharacters(in: .whitespacesAndNewlines) {
                DispatchQueue.main.async {
                    if let targetApp = state.apps.first(where: { $0.id == appId }) {
                        state.requestAddTiledApp(targetApp)
                    }
                }
            }
        }
        
        return true
    }
    
    // MARK: - First-Time Multitasking Resource Warning Modal
    private var multitaskingResourceWarningModal: some View {
        ZStack {
            // Dark Frosted Scrim
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    state.cancelMultitaskingWarning()
                }
            
            VStack(spacing: 20) {
                // Header with CPU Gauge Emblem
                ZStack {
                    Circle()
                        .fill(Color(hex: "F59E0B").opacity(0.18))
                        .frame(width: 72, height: 72)
                        .blur(radius: 14)
                    
                    Image(systemName: "gauge.with.needle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Color(hex: "F59E0B"))
                        .shadow(color: Color(hex: "F59E0B").opacity(0.4), radius: 8, y: 3)
                }
                
                VStack(spacing: 8) {
                    Text("Multitasking Performance Notice")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Running multiple Google Workspace web applications simultaneously uses more system memory and processor power than a single app view.\n\nWhile Workspace.mac intelligently throttles background panes to conserve battery, overall responsiveness depends on your Mac's available RAM.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .frame(maxWidth: 420)
                }
                
                // "Don't show this warning again" Checkbox
                Toggle(isOn: $dontShowWarningAgain) {
                    Text("Don't show this notice again")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .toggleStyle(.checkbox)
                .padding(.top, 4)
                
                // Action Buttons
                HStack(spacing: 14) {
                    Button(action: {
                        state.cancelMultitaskingWarning()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        state.confirmMultitaskingWarning(dontShowAgain: dontShowWarningAgain)
                    }) {
                        Text("Continue")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(hex: "1A73E8")))
                            .shadow(color: Color(hex: "1A73E8").opacity(0.35), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            }
            .padding(28)
            .liquidGlass(cornerRadius: 24, tintColor: Color(hex: "F59E0B"), isHighlighted: true)
            .frame(maxWidth: 480)
            .shadow(color: Color.black.opacity(0.4), radius: 24, y: 10)
        }
    }
}

// MARK: - Individual Tiled Pane View
public struct TiledAppPaneView: View {
    public let app: WorkspaceAppItem
    @ObservedObject public var state: AppState
    public let isSingleApp: Bool
    public let paneIndex: Int
    
    @State private var webView: WKWebView? = nil
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var isLoading: Bool = true
    @State private var currentUrlString: String = ""
    @State private var pageTitle: String = ""
    @State private var isHovered: Bool = false
    
    private var isFocused: Bool {
        state.focusedTiledAppId == app.id
    }
    
    private var displayApp: WorkspaceAppItem {
        state.app(for: currentUrlString) ?? app
    }
    
    public init(app: WorkspaceAppItem, state: AppState, isSingleApp: Bool, paneIndex: Int) {
        self.app = app
        self.state = state
        self.isSingleApp = isSingleApp
        self.paneIndex = paneIndex
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Mini Glass Header (Shown when in multi-pane mode)
            if !isSingleApp {
                paneHeaderView
            }
            
            // WebKit WebView Container
            ZStack(alignment: .top) {
                WebKitRepresentable(
                    url: state.overrideUrlForApp[app.id] ?? app.resolvedUrl(for: state.userProfile.email),
                    app: app,
                    webViewOut: $webView,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    isLoading: $isLoading,
                    currentUrlString: $currentUrlString,
                    pageTitle: $pageTitle
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Loading line
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(height: 2)
                        .accentColor(app.primaryColor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: isSingleApp ? 0 : 12, style: .continuous))
        .overlay(
            // Focus ring & subtle window border when in multi-app mode
            RoundedRectangle(cornerRadius: isSingleApp ? 0 : 12, style: .continuous)
                .stroke(
                    isFocused && !isSingleApp
                        ? Color(hex: "1A73E8").opacity(0.85)
                        : Color.primary.opacity(isSingleApp ? 0 : 0.1),
                    lineWidth: isFocused && !isSingleApp ? 2 : 1
                )
        )
        .shadow(
            color: isSingleApp ? Color.clear : Color.black.opacity(0.12),
            radius: isSingleApp ? 0 : 8,
            x: 0,
            y: 3
        )
        .onTapGesture {
            state.focusedTiledAppId = app.id
            state.activeWebView = webView
        }
        .onHover { h in
            isHovered = h
            if h && webView != nil {
                state.activeWebView = webView
            }
        }
    }
    
    // MARK: - Mini Pane Header
    private var paneHeaderView: some View {
        HStack(spacing: 8) {
            // App Icon & Name
            HStack(spacing: 6) {
                GoogleAppIconView(appId: displayApp.id, size: 14)
                
                Text(displayApp.name)
                    .font(.system(size: 11.5, weight: isFocused ? .bold : .semibold))
                    .foregroundStyle(isFocused ? Color.primary : Color.secondary)
                    .lineLimit(1)
                
                if !pageTitle.isEmpty && pageTitle != displayApp.name {
                    Text("—")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(pageTitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Pane Controls Cluster
            HStack(spacing: 4) {
                // Navigation controls for this pane
                Button(action: { webView?.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(canGoBack ? Color.primary : Color.secondary.opacity(0.3))
                        .padding(4)
                }
                .buttonStyle(.plain)
                .disabled(!canGoBack)
                .help("Back in \(displayApp.name)")
                
                Button(action: { webView?.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(canGoForward ? Color.primary : Color.secondary.opacity(0.3))
                        .padding(4)
                }
                .buttonStyle(.plain)
                .disabled(!canGoForward)
                .help("Forward in \(displayApp.name)")
                
                Button(action: {
                    if isLoading { webView?.stopLoading() } else { webView?.reload() }
                }) {
                    Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Reload")
                
                Divider()
                    .frame(height: 12)
                    .padding(.horizontal, 2)
                
                // Add another app to split menu (if < 4 apps)
                if state.tiledAppIds.count < 4 {
                    Menu {
                        ForEach(state.apps.filter { !state.tiledAppIds.contains($0.id) }) { otherApp in
                            Button(action: {
                                state.requestAddTiledApp(otherApp)
                            }) {
                                Label(otherApp.name, systemImage: otherApp.iconSymbol)
                            }
                        }
                    } label: {
                        Image(systemName: "plus.square")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                            .padding(4)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 18)
                    .help("Add another app to split view")
                }
                
                // Cycle positions button (Clockwise)
                Button(action: {
                    state.cycleTiledApps(clockwise: true)
                }) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Cycle pane positions (Cmd + Shift + ])")
                
                // Pop out to standalone window
                Button(action: {
                    state.popOutTiledApp(id: app.id)
                }) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Open in standalone window")
                
                // Maximize this pane
                Button(action: {
                    state.maximizeTiledApp(id: app.id)
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Maximize to full window")
                
                // Close pane
                Button(action: {
                    state.closeTiledApp(id: app.id)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Color.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Close this pane")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            isFocused
                ? Color(hex: "1A73E8").opacity(0.08)
                : Color.primary.opacity(0.03)
        )
        .overlay(
            Divider().opacity(0.2),
            alignment: .bottom
        )
    }
}
