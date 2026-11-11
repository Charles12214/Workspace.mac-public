import Foundation
import WebKit

@MainActor
public final class OfflineCacheService: NSObject, WKNavigationDelegate {
    public static let shared = OfflineCacheService()
    
    private var prewarmWebViews: [WKWebView] = []
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
        guard !isPrewarming else { return }
        isPrewarming = true
        
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        config.applicationNameForUserAgent = "Version/27.2 Safari/605.1.15"
        
        // Enable web app caching and storage APIs
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.preferences.setValue(true, forKey: "offlineWebApplicationCacheEnabled")
        
        let urls = coreOfflineEndpoints.compactMap { URL(string: $0) }
        self.pendingUrls = urls
        
        loadNextUrl(with: config)
    }
    
    private func loadNextUrl(with config: WKWebViewConfiguration) {
        guard !pendingUrls.isEmpty else {
            isPrewarming = false
            isOfflineReady = true
            prewarmWebViews.removeAll()
            return
        }
        
        let nextUrl = pendingUrls.removeFirst()
        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        wv.navigationDelegate = self
        prewarmWebViews.append(wv)
        
        let req = URLRequest(url: nextUrl, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        wv.load(req)
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
}
