import SwiftUI

public struct ContentView: View {
    @StateObject private var state = AppState.shared
    @StateObject private var greetingManager = GreetingManager.shared
    @State private var showingSettings: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    public init() {}
    
    public var body: some View {
        Group {
            if !state.hasCompletedSetup {
                OnboardingView(state: state)
                    .background(VisualEffectBackground().ignoresSafeArea())
            } else if let app = state.selectedApp {
                // MARK: - App View Container (Everything, Essentials [Default], Minimalist ["At a glance"])
                WorkspaceAppContainer(app: app, state: state, showingSettings: $showingSettings)
                    .id(app.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // MARK: - Home Launcher View with Sidebar
                HStack(spacing: 0) {
                    SidebarView(state: state, showingSettings: $showingSettings)
                    
                    Divider().opacity(0.2)
                    
                    HomeView(state: state, greetingManager: greetingManager)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(
                    colorScheme == .dark ? Color.black : Color.white
                )
            }
        }
        .preferredColorScheme(state.effectiveColorScheme)
        .sheet(isPresented: $showingSettings) {
            SettingsView(state: state)
        }
        .frame(minWidth: 940, minHeight: 620)
    }
}
