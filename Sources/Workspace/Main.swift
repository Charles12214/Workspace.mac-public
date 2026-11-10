import SwiftUI
import AppKit

@main
struct WorkspaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {
                Button("New Google Doc") {
                    if let app = AppState.shared.apps.first(where: { $0.id == "docs" }) {
                        AppState.shared.launchNewItem(for: app)
                    }
                }
                .keyboardShortcut("n", modifiers: [.command])
                
                Button("New Google Sheet") {
                    if let app = AppState.shared.apps.first(where: { $0.id == "sheets" }) {
                        AppState.shared.launchNewItem(for: app)
                    }
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Button("Go to Workspace.mac Home") {
                    AppState.shared.goHome()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            }
        }
    }
}

// MARK: - AppKit Visual Effect Background
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .underWindowBackground
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - App Delegate
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
