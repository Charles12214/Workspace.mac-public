import SwiftUI

public struct ContentView: View {
    @StateObject private var state = AppState.shared
    @StateObject private var greetingManager = GreetingManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .top) {
            Group {
                if !state.hasCompletedSetup {
                    OnboardingView(state: state)
                        .background(VisualEffectBackground().ignoresSafeArea())
                } else if let app = state.selectedApp {
                    // MARK: - App View Container (Everything, Essentials [Default], Minimalist ["At a glance"])
                    WorkspaceAppContainer(app: app, state: state, showingSettings: $state.showingSettings)
                        .id(state.activeAccountId)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // MARK: - Home Launcher View with Sidebar
                    HStack(spacing: 0) {
                        SidebarView(state: state, showingSettings: $state.showingSettings)
                        
                        Divider()
                            .opacity(0.2)
                            .ignoresSafeArea(.container, edges: .top)
                        
                        HomeView(state: state, greetingManager: greetingManager)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .background(
                        colorScheme == .dark ? Color.black : Color.white
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Yellow / Amber update banner at top of window
            if let update = state.availableUpdate, !state.dismissedUpdateTags.contains(update.tagName) {
                UpdateBannerView(update: update, onDismiss: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        state.dismissUpdate(update.tagName)
                    }
                })
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .move(edge: .top).combined(with: .opacity)))
                .padding(.top, 14)
                .zIndex(999)
            }
            
            // Download Progress Bar & "Downloaded to [file location]" Popup
            DownloadHUDView()
                .zIndex(1000)
            
            // Save Group Modal Dialog
            if state.showingSaveGroupModal {
                SaveGroupModalView(state: state)
                    .zIndex(1100)
                    .transition(.opacity)
            }
            
            // Rename Group Modal Dialog
            if state.showingRenameGroupModal {
                RenameGroupModalView(state: state)
                    .zIndex(1100)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(state.effectiveColorScheme)
        .sheet(isPresented: $state.showingSettings) {
            SettingsView(state: state)
                .frame(width: 820, height: 600)
        }
        .frame(minWidth: 940, minHeight: 620)
    }
}
