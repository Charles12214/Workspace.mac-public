import Foundation
import WebKit

/// Central in-memory pool for active WKWebView instances.
/// Allows tabs, split-screen multitasking, and groups to resize and reposition
/// seamlessly without reloading the underlying webpage, preserving unsaved Google Docs edits and scroll state.
@MainActor
public final class WebKitPool {
    public static let shared = WebKitPool()
    
    private var webViews: [String: WKWebView] = [:]
    
    private init() {}
    
    public func key(appId: String, accountId: String) -> String {
        "\(appId)_\(accountId)"
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
    }
    
    public func transferWebView(fromAppId: String, toAppId: String, accountId: String) {
        let fromKey = key(appId: fromAppId, accountId: accountId)
        let toKey = key(appId: toAppId, accountId: accountId)
        if let existing = webViews.removeValue(forKey: fromKey) {
            webViews[toKey] = existing
        }
    }
    
    public func clearAccount(accountId: String) {
        webViews = webViews.filter { !$0.key.hasSuffix("_\(accountId)") }
    }
    
    public func clearAll() {
        webViews.removeAll()
    }
    
    /// Returns all currently pooled WKWebView instances across apps and accounts.
    public var allWebViews: [WKWebView] {
        Array(webViews.values)
    }
}
