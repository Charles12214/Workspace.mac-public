import SwiftUI
import WebKit
import AppKit

public struct WorkspaceWebView: View {
    public let app: WorkspaceAppItem
    public let onReturnHome: () -> Void
    
    @State private var webView: WKWebView? = nil
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var isLoading: Bool = true
    @State private var isHoveringTopLeft: Bool = false
    @State private var currentUrlString: String = ""
    @State private var pageTitle: String = ""
    @State private var isOfflineError: Bool = false
    
    public init(app: WorkspaceAppItem, onReturnHome: @escaping () -> Void) {
        self.app = app
        self.onReturnHome = onReturnHome
    }
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            // MARK: - Edge-to-Edge Embedded WebKit View with Custom Open-Source Offline Extension
            WebKitRepresentable(
                url: app.url,
                app: app,
                webViewOut: $webView,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                isLoading: $isLoading,
                currentUrlString: $currentUrlString,
                pageTitle: $pageTitle,
                isOfflineError: $isOfflineError
            )
            .ignoresSafeArea()
            
            // MARK: - Ambient Offline Status Pill
            if OfflineManager.shared.isOffline {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: "F59E0B"))
                        
                        Text("Offline • Workspace Docs Offline Extension Active")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            webView?.reload()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Retry")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(hex: "F59E0B").opacity(0.35), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.18), radius: 8, y: 3)
                    .padding(.top, 10)
                    .frame(maxWidth: 420)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .zIndex(15)
            }
            
            // MARK: - Top Windowed-Fullscreen Zoom Trigger Zone (Double click top edge to enlarge)
            Color.clear
                .frame(height: 28)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    if let window = NSApp.keyWindow ?? NSApp.windows.first {
                        window.zoom(nil)
                    }
                }
            
            // MARK: - Top-Left Floating Control Hover Zone
            // "a floating button that emerges if the user's mouse goes near the top left corner"
            Color.clear
                .frame(width: 220, height: 70)
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        isHoveringTopLeft = hovering
                    }
                }
            
            // Floating Pill Button (Emerges when hovered)
            HStack(spacing: 8) {
                // Return Home Button
                Button(action: onReturnHome) {
                    HStack(spacing: 6) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white)
                        
                        Text("Home")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color(hex: "1A73E8"))
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                
                // Back & Reload controls
                HStack(spacing: 4) {
                    Button(action: { webView?.goBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(canGoBack ? Color.primary : Color.secondary.opacity(0.4))
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canGoBack)
                    
                    Button(action: {
                        if isLoading { webView?.stopLoading() } else { webView?.reload() }
                    }) {
                        Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 2)
            }
            .padding(.leading, 14)
            .padding(.top, 10)
            .opacity(isHoveringTopLeft ? 1.0 : 0.0)
            .scaleEffect(isHoveringTopLeft ? 1.0 : 0.85, anchor: .topLeading)
            .offset(y: isHoveringTopLeft ? 0 : -10)
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    isHoveringTopLeft = hovering
                }
            }
            
            // Subtle loading line indicator at very top
            if isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(height: 2)
                        .accentColor(app.primaryColor)
                    Spacer()
                }
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Native WebKit Host View (Protects WKWebView from SwiftUI deallocation & blanking)
@MainActor
public final class WebKitHostView: NSView {
    public private(set) weak var currentWebView: WKWebView?
    
    public override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
        self.autoresizingMask = [.width, .height]
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func attach(webView: WKWebView) {
        if currentWebView === webView && webView.superview === self {
            if self.bounds.width > 0 && self.bounds.height > 0 && webView.frame != self.bounds {
                webView.frame = self.bounds
            }
            webView.isHidden = false
            return
        }
        
        // Remove any old subviews from this host
        for subview in self.subviews {
            subview.removeFromSuperview()
        }
        
        // Detach safely from previous host if attached elsewhere
        if let oldSuper = webView.superview, oldSuper !== self {
            webView.removeFromSuperview()
        }
        
        self.currentWebView = webView
        if self.bounds.width > 0 && self.bounds.height > 0 {
            webView.frame = self.bounds
        } else {
            webView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        }
        webView.autoresizingMask = [.width, .height]
        webView.isHidden = false
        self.addSubview(webView)
        self.needsLayout = true
    }
    
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if let wv = currentWebView, newSize.width > 0 && newSize.height > 0 {
            wv.frame = NSRect(origin: .zero, size: newSize)
        }
    }
    
    public override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        if let wv = currentWebView, self.bounds.width > 0 && self.bounds.height > 0 {
            wv.frame = self.bounds
        }
    }
    
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let wv = currentWebView, window != nil {
            if self.bounds.width > 0 && self.bounds.height > 0 {
                wv.frame = self.bounds
            }
            wv.isHidden = false
            wv.needsLayout = true
            wv.needsDisplay = true
        }
    }
    
    public override func layout() {
        super.layout()
        if let wv = currentWebView {
            if wv.frame != self.bounds && self.bounds.width > 0 && self.bounds.height > 0 {
                wv.frame = self.bounds
            }
            wv.needsLayout = true
            wv.needsDisplay = true
        }
    }
}

// MARK: - NSViewRepresentable for WKWebView
public struct WebKitRepresentable: NSViewRepresentable {
    public let url: URL
    public let app: WorkspaceAppItem
    @Binding public var webViewOut: WKWebView?
    @Binding public var canGoBack: Bool
    @Binding public var canGoForward: Bool
    @Binding public var isLoading: Bool
    @Binding public var currentUrlString: String
    @Binding public var pageTitle: String
    @Binding public var isOfflineError: Bool
    
    public init(
        url: URL,
        app: WorkspaceAppItem,
        webViewOut: Binding<WKWebView?>,
        canGoBack: Binding<Bool>,
        canGoForward: Binding<Bool>,
        isLoading: Binding<Bool>,
        currentUrlString: Binding<String>,
        pageTitle: Binding<String>,
        isOfflineError: Binding<Bool> = .constant(false)
    ) {
        self.url = url
        self.app = app
        self._webViewOut = webViewOut
        self._canGoBack = canGoBack
        self._canGoForward = canGoForward
        self._isLoading = isLoading
        self._currentUrlString = currentUrlString
        self._pageTitle = pageTitle
        self._isOfflineError = isOfflineError
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> WebKitHostView {
        let hostView = WebKitHostView(frame: NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1400, height: 900))
        
        let (wv, isNew) = WebKitPool.shared.getOrCreateWebView(
            appId: app.id,
            accountId: AppState.shared.activeAccountId
        ) {
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = AppState.shared.activeDataStore
            configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
            configuration.suppressesIncrementalRendering = false
            
            // Match exact native Safari 27.2 User-Agent on macOS for crisp Retina canvas rendering in Google Docs & Sheets
            configuration.applicationNameForUserAgent = "Version/27.2 Safari/605.1.15"
            
            // Inject official Google Docs Offline Chrome Extension Polyfill / Shim
            configuration.userContentController.addUserScript(GoogleDocsOfflineExtension.makeUserScript())
            configuration.userContentController.add(LeakAvoider(delegate: context.coordinator), name: "offlineExtensionReady")
            
            // Suppress browser upgrade banners, hide companion sidebar cleanly via CSS, and route window.print() to native print handler
            let customScript = """
            if (!window.location.hostname.includes('accounts.google.com')) {
                const style = document.createElement('style');
                style.type = 'text/css';
                style.innerHTML = `
                    /* Promo / Download Banners */
                    #push-modal, [aria-label*="Try Chrome"], [aria-label*="switch to Chrome"],
                    [aria-label*="supported browser"], .apps-promo-card, .promo-banner, .app-download-banner,
                    div[role="alert"]:has(a[href*="chrome"]), .butterbar-container:has(a[href*="chrome"]),

                    /* Cleanly hide Google companion right sidebar & collapse toggle */
                    .companion-collapser-button-container,
                    .companion-app-sidebar-container {
                        display: none !important;
                    }
                `;
                (document.head || document.documentElement).appendChild(style);
                
                // Bridge native window.print() so Google Docs/Sheets/Slides trigger native macOS print sheet
                window.print = function() {
                    try {
                        window.webkit.messageHandlers.printHandler.postMessage('print');
                    } catch(e) {
                        console.warn('Native printHandler not available', e);
                    }
                };
            }
            """
            let userScript = WKUserScript(source: customScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            configuration.userContentController.addUserScript(userScript)
            configuration.userContentController.add(LeakAvoider(delegate: context.coordinator), name: "printHandler")
            
            // Initialize with real screen frame so WebKit and Google Docs initialize at full Retina resolution
            let initialFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1400, height: 900)
            let newWv = WKWebView(frame: initialFrame, configuration: configuration)
            newWv.autoresizingMask = [.width, .height]
            newWv.allowsMagnification = true
            newWv.pageZoom = 1.0
            newWv.magnification = 1.0
            return newWv
        }
        
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        context.coordinator.setupObservers(for: wv)
        
        if isNew || wv.url == nil {
            var request = URLRequest(url: url)
            request.cachePolicy = OfflineManager.shared.isOffline ? .returnCacheDataElseLoad : .useProtocolCachePolicy
            wv.load(request)
        }
        
        hostView.attach(webView: wv)
        
        DispatchQueue.main.async {
            self.webViewOut = wv
            self.isLoading = wv.isLoading
            self.canGoBack = wv.canGoBack
            self.canGoForward = wv.canGoForward
            if let t = wv.title, !t.isEmpty {
                self.pageTitle = t
            }
            if let u = wv.url?.absoluteString, !u.isEmpty {
                self.currentUrlString = u
            }
            if AppState.shared.focusedTiledAppId == self.app.id || AppState.shared.selectedAppId == self.app.id {
                AppState.shared.activeWebView = wv
            }
        }
        
        return hostView
    }
    
    public func updateNSView(_ hostView: WebKitHostView, context: Context) {
        if let wv = WebKitPool.shared.getWebView(appId: app.id, accountId: AppState.shared.activeAccountId) {
            hostView.attach(webView: wv)
            if hostView.bounds.width > 0 && hostView.bounds.height > 0 {
                wv.frame = hostView.bounds
            }
            wv.navigationDelegate = context.coordinator
            wv.uiDelegate = context.coordinator
            context.coordinator.setupObservers(for: wv)
            
            DispatchQueue.main.async {
                self.isLoading = wv.isLoading
                self.canGoBack = wv.canGoBack
                self.canGoForward = wv.canGoForward
            }
            
            if wv.url == nil {
                var request = URLRequest(url: url)
                request.cachePolicy = OfflineManager.shared.isOffline ? .returnCacheDataElseLoad : .useProtocolCachePolicy
                wv.load(request)
            }
        }
    }
    
    public static func dismantleNSView(_ hostView: WebKitHostView, coordinator: Coordinator) {
        coordinator.cleanup()
    }
    
    public class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, WKScriptMessageHandler {
        var parent: WebKitRepresentable
        private var observers: [NSKeyValueObservation] = []
        
        init(_ parent: WebKitRepresentable) {
            self.parent = parent
        }
        
        func cleanup() {
            for obs in observers {
                obs.invalidate()
            }
            observers.removeAll()
        }
        
        func setupObservers(for webView: WKWebView) {
            cleanup()
            
            observers.append(webView.observe(\.canGoBack, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.parent.canGoBack = wv.canGoBack
                }
            })
            
            observers.append(webView.observe(\.canGoForward, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.parent.canGoForward = wv.canGoForward
                }
            })
            
            observers.append(webView.observe(\.isLoading, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.parent.isLoading = wv.isLoading
                }
            })
            
            observers.append(webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    let title = wv.title ?? ""
                    self.parent.pageTitle = title
                    if let urlStr = wv.url?.absoluteString, !urlStr.isEmpty {
                        AppState.shared.recordRecentDocument(
                            appId: self.parent.app.id,
                            appName: self.parent.app.name,
                            title: title,
                            urlString: urlStr
                        )
                    }
                }
            })
            
            observers.append(webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    let urlStr = wv.url?.absoluteString ?? ""
                    self.parent.currentUrlString = urlStr
                    AppState.shared.notifyUrlChanged(sourceAppId: self.parent.app.id, newUrlString: urlStr)
                    if let title = wv.title, !title.isEmpty, !urlStr.isEmpty {
                        let detected = AppState.shared.app(for: urlStr)
                        AppState.shared.recordRecentDocument(
                            appId: detected?.id ?? self.parent.app.id,
                            appName: detected?.name ?? self.parent.app.name,
                            title: title,
                            urlString: urlStr
                        )
                    }
                }
            })
        }
        
        @MainActor
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let urlStr = webView.url?.absoluteString {
                parent.currentUrlString = urlStr
                AppState.shared.notifyUrlChanged(sourceAppId: parent.app.id, newUrlString: urlStr)
            }
            parent.isLoading = false
            parent.isOfflineError = false
        }
        
        @MainActor
        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleNavigationFailure(error: error, in: webView)
        }
        
        @MainActor
        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleNavigationFailure(error: error, in: webView)
        }
        
        @MainActor
        private func handleNavigationFailure(error: Error, in webView: WKWebView) {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                return // User cancelled or navigation redirected
            }
            
            // Check for network disconnection or offline unreachable status
            if nsError.code == NSURLErrorNotConnectedToInternet ||
               nsError.code == NSURLErrorCannotFindHost ||
               nsError.code == NSURLErrorCannotConnectToHost ||
               nsError.code == NSURLErrorNetworkConnectionLost ||
               nsError.code == NSURLErrorTimedOut ||
               OfflineManager.shared.isOffline {
                
                // Fall back to WebKit's persistent offline cache so Google Docs offline shell loads
                if let currentUrl = webView.url ?? parent.url as URL? {
                    var cachedReq = URLRequest(url: currentUrl)
                    cachedReq.cachePolicy = .returnCacheDataElseLoad
                    webView.load(cachedReq)
                }
                parent.isOfflineError = true
            }
            parent.isLoading = false
        }
        
        @MainActor
        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
            if navigationAction.shouldPerformDownload {
                decisionHandler(.download, preferences)
            } else {
                decisionHandler(.allow, preferences)
            }
        }
        
        @MainActor
        public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void) {
            if let httpResponse = navigationResponse.response as? HTTPURLResponse {
                let disposition = (httpResponse.allHeaderFields["Content-Disposition"] as? String ?? httpResponse.allHeaderFields["content-disposition"] as? String)?.lowercased() ?? ""
                if disposition.contains("attachment") {
                    decisionHandler(.download)
                    return
                }
            }
            
            if navigationResponse.canShowMIMEType {
                decisionHandler(.allow)
            } else {
                decisionHandler(.download)
            }
        }
        
        @MainActor
        public func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
            DownloadManager.shared.registerDownload(download)
        }
        
        @MainActor
        public func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
            DownloadManager.shared.registerDownload(download)
        }
        
        // MARK: - WKDownloadDelegate (Local File Saving Support)
        @MainActor
        public func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String) async -> URL? {
            let fileManager = FileManager.default
            let downloadsFolder = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
            
            var destinationURL = downloadsFolder.appendingPathComponent(suggestedFilename)
            var counter = 1
            let baseName = destinationURL.deletingPathExtension().lastPathComponent
            let ext = destinationURL.pathExtension
            
            while fileManager.fileExists(atPath: destinationURL.path) {
                let newName = ext.isEmpty ? "\(baseName) (\(counter))" : "\(baseName) (\(counter)).\(ext)"
                destinationURL = downloadsFolder.appendingPathComponent(newName)
                counter += 1
            }
            
            DownloadManager.shared.setDestination(for: download, destinationURL: destinationURL, suggestedFilename: suggestedFilename)
            return destinationURL
        }
        
        public func downloadDidFinish(_ download: WKDownload) {
            Task { @MainActor in
                DownloadManager.shared.finishDownload(download: download)
            }
        }
        
        public func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            Task { @MainActor in
                DownloadManager.shared.failDownload(download: download, error: error)
            }
        }
        
        @MainActor
        public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                if navigationAction.shouldPerformDownload {
                    // Let download policy handle it
                } else {
                    webView.load(navigationAction.request)
                }
            }
            return nil
        }
        
        // MARK: - WKScriptMessageHandler (Native Printing & Offline Extension Bridge)
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "printHandler" {
                Task { @MainActor in
                    if let webView = message.webView ?? AppState.shared.activeWebView {
                        AppState.shared.runNativePrintOperation(for: webView)
                    }
                }
            } else if message.name == "offlineExtensionReady" {
                // Google Docs Offline Extension Shim active and ready
            }
        }
    }
}

// MARK: - Weak Script Message Handler to Prevent Retain Cycles
private final class LeakAvoider: NSObject, WKScriptMessageHandler {
    private weak var delegate: WKScriptMessageHandler?
    
    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
