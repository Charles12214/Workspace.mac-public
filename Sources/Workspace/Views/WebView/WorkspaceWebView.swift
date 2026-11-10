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
    @Binding public var webViewOut: WKWebView?
    @Binding public var canGoBack: Bool
    @Binding public var canGoForward: Bool
    @Binding public var isLoading: Bool
    @Binding public var currentUrlString: String
    @Binding public var pageTitle: String
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        // Suppress browser upgrade and promo banners via CSS injection (do NOT run on accounts.google.com to preserve security integrity)
        let cssHideScript = """
        if (!window.location.hostname.includes('accounts.google.com')) {
            const style = document.createElement('style');
            style.type = 'text/css';
            style.innerHTML = `
                #push-modal, .gb_Fa, [aria-label*="Try Chrome"], [aria-label*="switch to Chrome"],
                [aria-label*="supported browser"], .apps-promo-card, .promo-banner, .app-download-banner,
                div[role="alert"]:has(a[href*="chrome"]), .butterbar-container:has(a[href*="chrome"]) {
                    display: none !important;
                    visibility: hidden !important;
                    height: 0 !important;
                }
            `;
            document.documentElement.appendChild(style);
        }
        """
        let userScript = WKUserScript(source: cssHideScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(userScript)
        
        let wv = WKWebView(frame: .zero, configuration: configuration)
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        
        // Force full Retina backing scale factor for razor-sharp canvas text in Google Docs & Sheets
        wv.wantsLayer = true
        wv.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        wv.pageZoom = 1.0
        
        // Use genuine macOS desktop Safari user agent (Safari 18.3)
        // Resolves "This browser or app may not be secure" on Google Sign-In
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"
        
        context.coordinator.setupObservers(for: wv)
        
        let request = URLRequest(url: url)
        wv.load(request)
        
        DispatchQueue.main.async {
            self.webViewOut = wv
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
                    self?.parent.pageTitle = wv.title ?? ""
                }
            })
            
            observers.append(webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.parent.currentUrlString = wv.url?.absoluteString ?? ""
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
