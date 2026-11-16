import Foundation
import WebKit

@MainActor
public final class OfflineCacheService: NSObject, WKNavigationDelegate {
    public static let shared = OfflineCacheService()
    
    private var prewarmWebView: WKWebView? = nil
    private var pendingUrls: [URL] = []
    @Published public var isPrewarming: Bool = false
    @Published public var isOfflineReady: Bool = true
    
    private let coreOfflineEndpoints = [
        "https://docs.google.com/document/u/0/",
        "https://docs.google.com/spreadsheets/u/0/",
        "https://docs.google.com/presentation/u/0/",
        "https://drive.google.com/drive/u/0/my-drive",
        "https://keep.google.com/u/0/",
        "https://calendar.google.com/calendar/u/0/r",
        "https://notebooklm.google.com/"
    ]
    
    public override init() {
        super.init()
    }
    
    /// Pre-warms and downloads offline application caches for Google Workspace apps in the background
    public func prewarmOfflineCache() {
        guard !isPrewarming && !OfflineManager.shared.isOffline && AppState.shared.hasCompletedSetup else { return }
        isPrewarming = true
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let cookies = await AppState.shared.activeDataStore.httpCookieStore.allCookies()
            let hasSession = cookies.contains { cookie in
                (cookie.name == "SID" || cookie.name == "__Secure-1PSID") &&
                cookie.domain.lowercased().contains("google.")
            }
            
            // Never hit Workspace URLs with a Chrome UA when logged out: the 302 to
            // accounts.google.com would plant a Chrome-tainted __Host-GAPS BotGuard cookie.
            guard hasSession, !OfflineManager.shared.isOffline else {
                self.isPrewarming = false
                return
            }
            
            let config = WKWebViewConfiguration()
            config.websiteDataStore = AppState.shared.activeDataStore
            config.userContentController.addUserScript(OfflineSuiteInjector.makeUserScript())
            
            let urls = self.coreOfflineEndpoints.compactMap { URL(string: $0) }
            self.pendingUrls = urls
            
            self.loadNextUrl(with: config)
        }
    }
    
    private func loadNextUrl(with config: WKWebViewConfiguration) {
        guard !pendingUrls.isEmpty else {
            isPrewarming = false
            isOfflineReady = true
            prewarmWebView?.stopLoading()
            prewarmWebView?.navigationDelegate = nil
            prewarmWebView = nil
            return
        }
        
        let nextUrl = pendingUrls.removeFirst()
        if prewarmWebView == nil {
            let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
            wv.customUserAgent = WebKitRepresentable.chromeWorkspaceUserAgent
            wv.navigationDelegate = self
            prewarmWebView = wv
        }
        
        let req = URLRequest(url: nextUrl, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15)
        prewarmWebView?.load(req)
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, WebKitRepresentable.isGoogleAuthURL(url) {
            decisionHandler(.cancel)
            pendingUrls.removeAll()
            loadNextUrl(with: webView.configuration)
            return
        }
        decisionHandler(.allow)
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Pre-warm next app in queue
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.loadNextUrl(with: webView.configuration)
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Continue even if an individual endpoint has network error
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.loadNextUrl(with: webView.configuration)
        }
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.loadNextUrl(with: webView.configuration)
        }
    }
}
