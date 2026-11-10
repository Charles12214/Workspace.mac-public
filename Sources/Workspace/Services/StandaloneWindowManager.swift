import SwiftUI
import AppKit

@MainActor
public final class StandaloneWindowManager: NSObject, ObservableObject {
    public static let shared = StandaloneWindowManager()
    
    private var windowControllers: [String: NSWindowController] = [:]
    
    public func openWindow(for app: WorkspaceAppItem, userEmail: String = "") {
        let windowId = "standalone_\(app.id)_\(UUID().uuidString)"
        
        let standaloneView = StandaloneAppWindowView(app: app, userEmail: userEmail)
        let hostingController = NSHostingController(rootView: standaloneView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "\(app.name) - Workspace.mac"
        window.setContentSize(NSSize(width: 1100, height: 750))
        window.minSize = NSSize(width: 600, height: 450)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.center()
        
        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        windowControllers[windowId] = controller
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.windowControllers.removeValue(forKey: windowId)
            }
        }
    }
}
