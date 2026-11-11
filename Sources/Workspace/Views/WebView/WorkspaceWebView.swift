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
    
    public init(app: WorkspaceAppItem, onReturnHome: @escaping () -> Void) {
        self.app = app
        self.onReturnHome = onReturnHome
    }
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            // MARK: - Edge-to-Edge Embedded WebKit View (No URL bar space, full window)
            WebKitRepresentable(
                url: app.url,
                app: app,
                webViewOut: $webView,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                isLoading: $isLoading,
                currentUrlString: $currentUrlString,
                pageTitle: $pageTitle
            )
            .ignoresSafeArea()
            
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
    
    public init(
        url: URL,
        app: WorkspaceAppItem,
        webViewOut: Binding<WKWebView?>,
        canGoBack: Binding<Bool>,
        canGoForward: Binding<Bool>,
        isLoading: Binding<Bool>,
        currentUrlString: Binding<String>,
        pageTitle: Binding<String>
    ) {
        self.url = url
        self.app = app
        self._webViewOut = webViewOut
        self._canGoBack = canGoBack
        self._canGoForward = canGoForward
        self._isLoading = isLoading
        self._currentUrlString = currentUrlString
        self._pageTitle = pageTitle
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        // Match exact native Safari 27.2 User-Agent on macOS
        configuration.applicationNameForUserAgent = "Version/27.2 Safari/605.1.15"
        
        // Suppress browser upgrade and promo banners via CSS injection (do NOT run on accounts.google.com)
        let customScript = """
        if (!window.location.hostname.includes('accounts.google.com')) {
            const style = document.createElement('style');
            style.type = 'text/css';
            style.innerHTML = `
                /* Promo / Download Banners */
                #push-modal, [aria-label*="Try Chrome"], [aria-label*="switch to Chrome"],
                [aria-label*="supported browser"], .apps-promo-card, .promo-banner, .app-download-banner,
                div[role="alert"]:has(a[href*="chrome"]), .butterbar-container:has(a[href*="chrome"]) {
                    display: none !important;
                    visibility: hidden !important;
                    height: 0 !important;
                }
            `;
            (document.head || document.documentElement).appendChild(style);

            // Cleanly collapse Google Docs right companion side panel using Google's native API/controls
            function collapseCompanionRail() {
                const hideBtn = document.querySelector('button[aria-label*="Hide side panel"], div[role="button"][aria-label*="Hide side panel"]');
                if (hideBtn) {
                    hideBtn.click();
                }
            }
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', () => setTimeout(collapseCompanionRail, 1000));
            } else {
                setTimeout(collapseCompanionRail, 1000);
            }
        }
        """
        let userScript = WKUserScript(source: customScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(userScript)
        
        // Initialize with real screen frame so WebKit and Google Docs initialize at full Retina resolution
        let initialFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1400, height: 900)
        let wv = WKWebView(frame: initialFrame, configuration: configuration)
        wv.autoresizingMask = [.width, .height]
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        wv.allowsMagnification = true
        
        context.coordinator.setupObservers(for: wv)
        
        let request = URLRequest(url: url)
        wv.load(request)
        
        DispatchQueue.main.async {
            self.webViewOut = wv
            AppState.shared.activeWebView = wv
        }
        
        return wv
    }
    
    public func updateNSView(_ nsView: WKWebView, context: Context) {}
    
    public class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebKitRepresentable
        private var observers: [NSKeyValueObservation] = []
        
        init(_ parent: WebKitRepresentable) {
            self.parent = parent
        }
        
        func setupObservers(for webView: WKWebView) {
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
                    if let title = wv.title, !title.isEmpty, !urlStr.isEmpty {
                        AppState.shared.recordRecentDocument(
                            appId: self.parent.app.id,
                            appName: self.parent.app.name,
                            title: title,
                            urlString: urlStr
                        )
                    }
                }
            })
        }
        
        @MainActor
        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
        
        @MainActor
        public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
