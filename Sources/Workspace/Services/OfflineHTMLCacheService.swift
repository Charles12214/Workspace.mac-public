import Foundation
import WebKit

/// Dedicated high-speed offline HTML cache for Google Workspace applications.
/// Caches the full document HTML shells of Docs, Sheets, Slides, and Drive on disk
/// so WKWebView can boot Google's web applications instantly without internet connection,
/// preventing the blank white screen when launching offline.
@MainActor
public final class OfflineHTMLCacheService {
    public static let shared = OfflineHTMLCacheService()
    
    private let fileManager = FileManager.default
    public let cacheDirectory: URL
    private let manifestURL: URL
    
    // In-memory index of cached URLs: URL string -> local filename
    private var manifest: [String: String] = [:]
    
    private init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let baseDir = docs.appendingPathComponent("Workspace.mac", isDirectory: true)
        self.cacheDirectory = baseDir.appendingPathComponent("OfflineHTMLCache", isDirectory: true)
        self.manifestURL = cacheDirectory.appendingPathComponent("manifest.json")
        
        ensureDirectoryExists()
        loadManifest()
    }
    
    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        self.manifest = dict
    }
    
    private func saveManifest() {
        if let data = try? JSONEncoder().encode(manifest) {
            try? data.write(to: manifestURL, options: .atomic)
        }
    }
    
    private func cacheKey(for url: URL) -> String {
        let str = url.absoluteString
        let clean = str.components(separatedBy: "?").first ?? str
        return clean.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
    
    private func filename(for url: URL) -> String {
        let str = url.absoluteString
        
        if str.contains("/document/u/0") || str.hasSuffix("/document/") {
            return "docs_home.html"
        } else if str.contains("/spreadsheets/u/0") || str.hasSuffix("/spreadsheets/") {
            return "sheets_home.html"
        } else if str.contains("/presentation/u/0") || str.hasSuffix("/presentation/") {
            return "slides_home.html"
        } else if str.contains("/drive/u/0") || str.contains("/drive/") {
            return "drive_home.html"
        } else if str.contains("/keep/u/0") || str.contains("/keep/") {
            return "keep_home.html"
        }
        
        // Document specific pattern: /document/d/<id>/
        if let match = str.range(of: #"/document/d/([a-zA-Z0-9_-]+)"#, options: .regularExpression) {
            let docId = String(str[match]).replacingOccurrences(of: "/document/d/", with: "")
            return "doc_\(docId).html"
        }
        if let match = str.range(of: #"/spreadsheets/d/([a-zA-Z0-9_-]+)"#, options: .regularExpression) {
            let sheetId = String(str[match]).replacingOccurrences(of: "/spreadsheets/d/", with: "")
            return "sheet_\(sheetId).html"
        }
        if let match = str.range(of: #"/presentation/d/([a-zA-Z0-9_-]+)"#, options: .regularExpression) {
            let slideId = String(str[match]).replacingOccurrences(of: "/presentation/d/", with: "")
            return "slide_\(slideId).html"
        }
        
        // Generic fallback hash
        let hash = abs(str.hashValue)
        return "page_\(hash).html"
    }
    
    /// Asynchronously captures and saves the full rendered HTML of the webView
    public func saveFromWebView(_ webView: WKWebView, url: URL) {
        // Skip auth/login pages and about:blank
        let urlStr = url.absoluteString
        guard !urlStr.isEmpty,
              !urlStr.contains("accounts.google.com"),
              !urlStr.contains("about:blank"),
              !urlStr.contains("google.com/url") else {
            return
        }
        
        webView.evaluateJavaScript("document.documentElement ? document.documentElement.outerHTML : ''") { [weak self] result, error in
            guard let self = self, let html = result as? String, html.count > 200 else { return }
            
            Task { @MainActor in
                self.saveHTML(html, for: url)
            }
        }
    }
    
    /// Saves raw HTML string for a URL to disk
    public func saveHTML(_ html: String, for url: URL) {
        ensureDirectoryExists()
        let name = filename(for: url)
        let fileURL = cacheDirectory.appendingPathComponent(name)
        
        do {
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
            let key = cacheKey(for: url)
            manifest[key] = name
            saveManifest()
            print("[OfflineHTMLCache] Successfully cached \(name) (\(html.count) bytes) for \(url.absoluteString)")
        } catch {
            print("[OfflineHTMLCache] Failed to save HTML cache: \(error)")
        }
    }
    
    /// Checks whether cached HTML is available for the given URL
    public func hasCachedHTML(for url: URL) -> Bool {
        let name = filename(for: url)
        let fileURL = cacheDirectory.appendingPathComponent(name)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Retrieves cached HTML string for the given URL, if available
    public func cachedHTML(for url: URL) -> String? {
        let name = filename(for: url)
        let fileURL = cacheDirectory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: fileURL.path),
              let content = try? String(contentsOf: fileURL, encoding: .utf8),
              !content.isEmpty else {
            return nil
        }
        return content
    }
    
    /// Retrieves cached HTML for an app by ID (e.g. "docs", "sheets", "slides", "drive")
    public func cachedHTML(forAppId appId: String) -> (html: String, url: URL)? {
        let (fileName, urlStr): (String, String)
        switch appId {
        case "docs":
            fileName = "docs_home.html"
            urlStr = "https://docs.google.com/document/u/0/"
        case "sheets":
            fileName = "sheets_home.html"
            urlStr = "https://docs.google.com/spreadsheets/u/0/"
        case "slides":
            fileName = "slides_home.html"
            urlStr = "https://docs.google.com/presentation/u/0/"
        case "drive":
            fileName = "drive_home.html"
            urlStr = "https://drive.google.com/drive/u/0/my-drive"
        default:
            return nil
        }
        
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: fileURL.path),
           let content = try? String(contentsOf: fileURL, encoding: .utf8),
           let url = URL(string: urlStr) {
            return (content, url)
        }
        
        return nil
    }
}
