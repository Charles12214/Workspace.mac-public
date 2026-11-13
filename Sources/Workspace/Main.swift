import SwiftUI
import AppKit

@main
struct WorkspaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var state = AppState.shared
    
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
                    if let app = state.apps.first(where: { $0.id == "docs" }) {
                        state.launchNewItem(for: app)
                    }
                }
                .keyboardShortcut("n", modifiers: [.command])
                
                Button("New Google Sheet") {
                    if let app = state.apps.first(where: { $0.id == "sheets" }) {
                        state.launchNewItem(for: app)
                    }
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Button("Go to Workspace.mac Home") {
                    state.goHome()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save Group") {
                    state.triggerSaveGroup()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(!state.isMultitaskingActive)
                
                Button("Save Group As...") {
                    state.triggerSaveGroupAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!state.isMultitaskingActive)
                
                Button("Rename Group...") {
                    state.triggerRenameGroup()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(!state.isMultitaskingActive || state.activeGroupId == nil)
                
                Divider()
                
                Button("Quit Group") {
                    state.quitActiveGroup()
                }
                .keyboardShortcut("w", modifiers: [.command, .option])
                .disabled(!state.isMultitaskingActive)
            }
            CommandGroup(replacing: .printItem) {
                Button("Print...") {
                    state.triggerNativePrint()
                }
                .keyboardShortcut("p", modifiers: [.command])
            }
            CommandMenu("View") {
                Button("Zoom In") {
                    AppState.shared.zoomIn()
                }
                .keyboardShortcut("+", modifiers: [.command])
                
                Button("Zoom In (Equal Key)") {
                    AppState.shared.zoomIn()
                }
                .keyboardShortcut("=", modifiers: [.command])
                
                Button("Zoom Out") {
                    AppState.shared.zoomOut()
                }
                .keyboardShortcut("-", modifiers: [.command])
                
                Divider()
                
                Button("Actual Size") {
                    AppState.shared.resetZoom()
                }
                .keyboardShortcut("0", modifiers: [.command])
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
