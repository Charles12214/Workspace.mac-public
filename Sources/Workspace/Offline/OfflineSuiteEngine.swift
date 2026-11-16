import Foundation
import WebKit

/// OfflineSuite.mac — Native Swift Backend
/// Handles WKScriptMessageHandler messages from OfflineSuiteBridge.js
/// via the unified "offlineSuite" message channel.
///
/// Responsibilities:
///   1. Receives bridgeReady, autoSave, documentTracked messages from JS
///   2. Persists documents locally to ~/Documents/Workspace.mac/
///   3. Routes document tracking to OfflineManager
///
/// MIT License — 100% original clean-room code.
@MainActor
public final class OfflineSuiteEngine: NSObject, WKScriptMessageHandler {
    public static let shared = OfflineSuiteEngine()
    
    /// Whether the JS bridge has signaled readiness
    @Published public var isBridgeReady: Bool = false
    
    /// Bridge version reported by the JS side
    public private(set) var bridgeVersion: String = ""
    
    // MARK: - WKScriptMessageHandler
    
    nonisolated public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // Bridge into @MainActor cleanly across both older SDKs (nonisolated protocol)
        // and newer SDKs (@MainActor-isolated WKScriptMessage properties).
        Task { @MainActor in
            guard message.name == "offlineSuite",
                  let dict = message.body as? [String: Any],
                  let action = dict["action"] as? String else {
                return
            }
            
            switch action {
            case "bridgeReady":
                self.handleBridgeReady(dict)
                
            case "autoSave":
                self.handleAutoSave(dict)
                
            case "documentTracked":
                self.handleDocumentTracked(dict)
                
            case "documentListScanned":
                self.handleDocumentListScanned(dict)
                
            case "documentSavedOffline":
                self.handleDocumentSavedOffline(dict)
                
            case "networkStateChanged":
                if let isOffline = dict["isOffline"] as? Bool {
                    OfflineManager.shared.applyNetworkState(currentlyOffline: isOffline, fromWebView: true)
                }
                
            default:
                break
            }
        }
    }
    
    // MARK: - Document Saved Offline
    
    private func handleDocumentSavedOffline(_ dict: [String: Any]) {
        let title = dict["title"] as? String ?? "Document"
        let docId = dict["docId"] as? String ?? ""
        print("[OfflineSuite] Document saved offline: \(title) (\(docId))")
        OfflineManager.shared.handleTrackedDocumentMessage(dict)
    }
    
    // MARK: - Bridge Ready
    
    private func handleBridgeReady(_ dict: [String: Any]) {
        isBridgeReady = true
        bridgeVersion = dict["version"] as? String ?? "unknown"
        print("[OfflineSuite] Bridge ready — v\(bridgeVersion)")
    }
    
    // MARK: - Document List Scanned
    
    private func handleDocumentListScanned(_ dict: [String: Any]) {
        OfflineManager.shared.handleTrackedDocumentMessage(dict)
    }
    
    // MARK: - Auto Save
    
    private func handleAutoSave(_ dict: [String: Any]) {
        // Route to OfflineManager's existing save logic
        OfflineManager.shared.handleOfflineDocumentSaverMessage(dict)
    }
    
    // MARK: - Document Tracked
    
    private func handleDocumentTracked(_ dict: [String: Any]) {
        // Route to OfflineManager's existing tracking logic
        OfflineManager.shared.handleTrackedDocumentMessage(dict)
    }
}
