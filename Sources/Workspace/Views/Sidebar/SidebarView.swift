import SwiftUI
import AppKit

public struct SidebarView: View {
    @ObservedObject var state: AppState
    @Binding var showingSettings: Bool
    
    public init(state: AppState, showingSettings: Binding<Bool>) {
        self.state = state
        self._showingSettings = showingSettings
    }
    
    public var body: some View {
        Group {
            if state.isSidebarCollapsed {
                collapsedSidebar
            } else {
                expandedSidebar
            }
        }
        .background(
            ZStack {
                Rectangle().fill(Color(nsColor: .windowBackgroundColor))
                Rectangle().fill(.ultraThinMaterial)
            }
        )
    }
    
    // MARK: - Expanded Sidebar
    private var expandedSidebar: some View {
        VStack(spacing: 0) {
            // MARK: - TOP LEFT: Account Details & Window Controls
            VStack(spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    // Profile Header - Shows current active single account
                    Button(action: { showingSettings = true }) {
                        HStack(alignment: .center, spacing: 10) {
                            GoogleProfileAvatarView(
                                avatarData: state.userProfile.avatarImageData,
                                name: state.userProfile.displayName,
                                size: 40,
                                tier: state.userProfile.tier,
                                showEditButton: false
                            )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(state.userProfile.displayName)
                                    .font(.system(size: 13.5, weight: .bold))
                                    .lineLimit(1)
                                
                                Text(state.userProfile.email.isEmpty ? "Workspace Profile" : state.userProfile.email)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help("View Account Settings")
                    
                    Spacer()
                    
                    // Settings Gear
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(Circle().fill(Color.primary.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                    
                    // Collapse Sidebar Button
                    Button(action: { state.toggleSidebar() }) {
                        Image(systemName: "sidebar.leading")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(Circle().fill(Color.primary.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .help("Collapse Sidebar")
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                
                // MARK: - Home Button (Rounded home with Gemini gradient in middle)
                HStack(spacing: 10) {
                    GeminiHomeIcon(isSelected: state.selectedAppId == nil) {
                        state.goHome()
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Workspace.mac Home")
                            .font(.system(size: 13.5, weight: state.selectedAppId == nil ? .bold : .medium))
                            .foregroundStyle(state.selectedAppId == nil ? Color.primary : Color.secondary)
                        
                        Text("Overview & Recents")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 10)
            
            // MARK: - Search Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                TextField("Search Workspace.mac...", text: $state.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !state.searchQuery.isEmpty {
                    Button(action: { state.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            
            Divider().opacity(0.3)
            
            // MARK: - All Workspace Apps List (Clean, No Quick Sort Clutter)
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 2) {
                    ForEach(state.filteredApps) { app in
                        SidebarItemRow(
                            app: app,
                            isSelected: state.selectedAppId == app.id,
                            onSelect: {
                                state.launchApp(app)
                            },
                            onTogglePin: {
                                state.togglePin(appId: app.id)
                            },
                            onOpenSeparate: {
                                state.openSeparateWindow(for: app)
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .frame(minWidth: 260, maxWidth: 280)
    }
    
    // MARK: - Collapsed Rail Sidebar
    private var collapsedSidebar: some View {
        VStack(spacing: 12) {
            // Expand button & Avatar at top
            Button(action: { state.toggleSidebar() }) {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help("Expand Sidebar")
            .padding(.top, 14)
            
            Button(action: { showingSettings = true }) {
                GoogleProfileAvatarView(
                    avatarData: state.userProfile.avatarImageData,
                    name: state.userProfile.name,
                    size: 34,
                    tier: state.userProfile.tier,
                    showEditButton: false
                )
            }
            .buttonStyle(.plain)
            .help("\(state.userProfile.name) • Settings")
            
            Divider().frame(width: 32).opacity(0.3)
            
            // Home icon
            GeminiHomeIcon(isSelected: state.selectedAppId == nil) {
                state.goHome()
            }
            
            Divider().frame(width: 32).opacity(0.3)
            
            // Compact icons of apps
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(state.apps) { app in
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    state.selectedAppId == app.id
                                        ? app.primaryColor.opacity(0.25)
                                        : Color.primary.opacity(0.04)
                                )
                                .frame(width: 36, height: 36)
                            
                            GoogleAppIconView(appId: app.id, size: 20)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            state.launchApp(app)
                        }
                        .onDrag {
                            let provider = NSItemProvider(object: app.id as NSString)
                            provider.suggestedName = app.name
                            return provider
                        }
                        .contextMenu {
                            Button("Open in Separate Window") {
                                state.openSeparateWindow(for: app)
                            }
                            Button(app.isPinned ? "Unpin App" : "Pin App to Dashboard") {
                                state.togglePin(appId: app.id)
                            }
                        }
                        .help(app.name)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Spacer()
            
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
        .frame(width: 58)
    }
}

// MARK: - Sidebar Row Item
public struct SidebarItemRow: View {
    public let app: WorkspaceAppItem
    public let isSelected: Bool
    public let onSelect: () -> Void
    public let onTogglePin: () -> Void
    public let onOpenSeparate: () -> Void
    
    @State private var isHovered = false
    
    public init(
        app: WorkspaceAppItem,
        isSelected: Bool,
        onSelect: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onOpenSeparate: @escaping () -> Void
    ) {
        self.app = app
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onTogglePin = onTogglePin
        self.onOpenSeparate = onOpenSeparate
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            // App Icon Container
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(app.primaryColor.opacity(isSelected ? 0.25 : 0.14))
                    .frame(width: 28, height: 28)
                
                GoogleAppIconView(appId: app.id, size: 18)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.9))
                    .lineLimit(1)
                
                Text(app.category.rawValue)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Hover actions: Separate Window & Pin
            if isHovered || app.isPinned {
                HStack(spacing: 2) {
                    Button(action: onOpenSeparate) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .help("Open in Separate Window")
                    
                    Button(action: onTogglePin) {
                        Image(systemName: app.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 10))
                            .foregroundStyle(app.isPinned ? Color(hex: "F4B400") : Color.secondary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .help(app.isPinned ? "Unpin" : "Pin")
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isSelected
                        ? Color(hex: "1A73E8").opacity(0.14)
                        : (isHovered ? Color.primary.opacity(0.06) : Color.clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isSelected ? Color(hex: "1A73E8").opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onDrag {
            let provider = NSItemProvider(object: app.id as NSString)
            provider.suggestedName = app.name
            return provider
        }
        .contextMenu {
            Button("Open in Separate Window") {
                onOpenSeparate()
            }
            Button(app.isPinned ? "Unpin App" : "Pin App to Dashboard") {
                onTogglePin()
            }
        }
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = h
            }
        }
    }
}
