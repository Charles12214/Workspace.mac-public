import SwiftUI
import WebKit
import AppKit

// MARK: - Standalone Single-App Window View
// "Separate windows only have a top bar with NO option for a sidebar or home, basically a simplified browser tab"
public struct StandaloneAppWindowView: View {
    public let app: WorkspaceAppItem
    public let userEmail: String
    public let customUrl: URL?
    
    @State private var webView: WKWebView? = nil
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var isLoading: Bool = true
    @State private var currentUrlString: String = ""
    @State private var pageTitle: String = ""
    @State private var currentZoom: CGFloat = 1.0
    
    public init(app: WorkspaceAppItem, userEmail: String = "", customUrl: URL? = nil) {
        self.app = app
        self.userEmail = userEmail
        self.customUrl = customUrl
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Bar (Simplified Browser Tab header)
            HStack(spacing: 12) {
                // Space for macOS native traffic lights
                Color.clear.frame(width: 72, height: 1)
                
                // Navigation buttons (Back / Forward / Reload)
                HStack(spacing: 4) {
                    Button(action: { webView?.goBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(canGoBack ? Color.primary : Color.secondary.opacity(0.3))
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canGoBack)
                    .help("Back")
                    
                    Button(action: { webView?.goForward() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(canGoForward ? Color.primary : Color.secondary.opacity(0.3))
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canGoForward)
                    .help("Forward")
                    
                    Button(action: {
                        if isLoading { webView?.stopLoading() } else { webView?.reload() }
                    }) {
                        Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .help("Reload")
                }
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                
                // Clickable Zoom In / Out (+ / -) Controls
                HStack(spacing: 2) {
                    Button(action: { zoomOut() }) {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Zoom Out (Cmd -)")
                    
                    Button(action: { resetZoom() }) {
                        Text("\(Int(round(currentZoom * 100)))%")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                    .help("Reset Zoom (Cmd 0)")
                    
                    Button(action: { zoomIn() }) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Zoom In (Cmd +)")
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.05)))
                
                Spacer()
                
                // App Icon & Title centered
                HStack(spacing: 8) {
                    GoogleAppIconView(appId: app.id, size: 16)
                    
                    Text(pageTitle.isEmpty ? app.name : pageTitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: 320)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.primary.opacity(0.04)))
                
                Spacer()
                
                // Placeholder to balance the left traffic lights space
                Color.clear.frame(width: 72, height: 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider().opacity(0.2)
            
            // MARK: - Embedded Web View
            ZStack(alignment: .top) {
                WebKitRepresentable(
                    url: customUrl ?? app.resolvedUrl(for: userEmail),
                    app: app,
                    webViewOut: $webView,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    isLoading: $isLoading,
                    currentUrlString: $currentUrlString,
                    pageTitle: $pageTitle
                )
                .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(height: 2)
                        .accentColor(app.primaryColor)
                        .ignoresSafeArea()
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
    
    private func zoomIn() {
        guard let wv = webView else { return }
        let next = min((round(wv.pageZoom * 10) / 10) + 0.1, 3.0)
        wv.pageZoom = next
        currentZoom = next
    }
    
    private func zoomOut() {
        guard let wv = webView else { return }
        let next = max((round(wv.pageZoom * 10) / 10) - 0.1, 0.5)
        wv.pageZoom = next
        currentZoom = next
    }
    
    private func resetZoom() {
        guard let wv = webView else { return }
        wv.pageZoom = 1.0
        wv.magnification = 1.0
        currentZoom = 1.0
    }
}
