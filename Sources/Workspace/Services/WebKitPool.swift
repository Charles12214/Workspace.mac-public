import Foundation
import WebKit
import AppKit

/// Central in-memory pool for active WKWebView instances.
/// Allows tabs, split-screen multitasking, and groups to resize and reposition
/// seamlessly without reloading the underlying webpage, preserving unsaved Google Docs edits and scroll state.
@MainActor
public final class WebKitPool {
    public static let shared = WebKitPool()
    
    @MainActor
    private final class WeakViewBox {
        weak var view: NSView?
        init(_ view: NSView) { self.view = view }
    }
    
    private var webViews: [String: WKWebView] = [:]
    private var activeOwners: [String: WeakViewBox] = [:]
    
    private init() {}
    
    public func key(appId: String, accountId: String) -> String {
        "\(appId)_\(accountId)"
    }
    
    public func claimOwnership(_ host: NSView, appId: String, accountId: String) {
        let k = key(appId: appId, accountId: accountId)
        activeOwners[k] = WeakViewBox(host)
    }
    
    public func releaseOwnership(_ host: NSView, forKey key: String) {
        if activeOwners[key]?.view === host {
            activeOwners.removeValue(forKey: key)
        }
    }
    
    public func isOwner(_ host: NSView, appId: String, accountId: String) -> Bool {
        let k = key(appId: appId, accountId: accountId)
        return activeOwners[k]?.view === host
    }
    
    public func isOwner(_ host: NSView, forKey key: String) -> Bool {
        return activeOwners[key]?.view === host
    }
    
    public func getOrCreateWebView(
        appId: String,
        accountId: String,
        create: () -> WKWebView
    ) -> (webView: WKWebView, isNew: Bool) {
        let k = key(appId: appId, accountId: accountId)
        if let existing = webViews[k] {
            return (existing, false)
        }
        let created = create()
        webViews[k] = created
        return (created, true)
    }
    
    public func getWebView(appId: String, accountId: String) -> WKWebView? {
        let k = key(appId: appId, accountId: accountId)
        return webViews[k]
    }
    
    public func removeWebView(appId: String, accountId: String) {
        let k = key(appId: appId, accountId: accountId)
        webViews.removeValue(forKey: k)
        activeOwners.removeValue(forKey: k)
    }
    
    public func transferWebView(fromAppId: String, toAppId: String, accountId: String) {
        let fromKey = key(appId: fromAppId, accountId: accountId)
        let toKey = key(appId: toAppId, accountId: accountId)
        if let existing = webViews.removeValue(forKey: fromKey) {
            webViews[toKey] = existing
        }
        activeOwners.removeValue(forKey: fromKey)
    }
    
    public func clearAccount(accountId: String) {
        webViews = webViews.filter { !$0.key.hasSuffix("_\(accountId)") }
        activeOwners = activeOwners.filter { !$0.key.hasSuffix("_\(accountId)") }
    }
    
    public func clearAll() {
        webViews.removeAll()
        activeOwners.removeAll()
    }
    
    /// Returns all currently pooled WKWebView instances across apps and accounts.
    public var allWebViews: [WKWebView] {
        Array(webViews.values)
    }
}
