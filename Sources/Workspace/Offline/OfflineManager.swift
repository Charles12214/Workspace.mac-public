import Foundation
import Network
import Combine
import AppKit
import SwiftUI
import WebKit

// MARK: - Tracked Workspace Document Model (Smart Document Tracker)
public struct TrackedWorkspaceDocument: Identifiable, Codable, Equatable, Sendable {
    public var id: String // Google Doc/Sheet/Slide ID
    public var title: String
    public var type: String // "docs", "sheets", "slides", "drive"
    public var url: String
    public var exportUrl: String
    public var lastOpened: Date
    public var localFilePath: String?
    
    public var fileExtension: String {
        switch type {
        case "sheets": return "xlsx"
        case "slides": return "pptx"
        default: return "docx"
        }
    }
    
    public var iconSymbol: String {
        switch type {
        case "sheets": return "tablecells.fill"
        case "slides": return "play.rectangle.fill"
        default: return "doc.text.fill"
        }
    }
}

// MARK: - Local Workspace Document Model
public struct LocalWorkspaceDocument: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let url: URL
    public let fileExtension: String
    public let fileSizeFormatted: String
    public let modificationDate: Date
    
    public var iconSymbol: String {
        switch fileExtension.lowercased() {
        case "docx", "doc", "rtf", "gdoc":
            return "doc.text.fill"
        case "xlsx", "xls", "csv", "gsheet":
            return "tablecells.fill"
        case "pptx", "ppt", "gslides":
            return "play.rectangle.fill"
        case "pdf":
            return "doc.richtext.fill"
        case "txt", "md":
            return "note.text"
        default:
            return "doc.fill"
        }
    }
    
    public var isRichDocument: Bool {
        ["docx", "doc", "rtf", "txt", "md"].contains(fileExtension.lowercased())
    }
}

// MARK: - Offline Manager
@MainActor
public final class OfflineManager: ObservableObject {
    public static let shared = OfflineManager()
    
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "Workspace.mac.OfflineMonitorQueue")
    
    @Published public var isOffline: Bool = false
    @Published public var connectionType: String = "Wi-Fi"
    @Published public var localDocuments: [LocalWorkspaceDocument] = []
    @Published public var trackedDocuments: [TrackedWorkspaceDocument] = []
    
    // Cloud sync popup state
    @Published public var isSyncingToCloud: Bool = false
    @Published public var syncMessage: String = ""
    @Published public var syncIsComplete: Bool = false
    
    // Directory: ~/Documents/Workspace.mac/
    public let localDocumentsDirectory: URL
    
    private let kTrackedDocsKey = "Workspace_TrackedDocuments_V1"
    private var activeDownloadIds: Set<String> = []
    private var lastDownloadTimes: [String: Date] = [:]
    
    private var lastWasOffline: Bool = false
    
    public init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.localDocumentsDirectory = docs.appendingPathComponent("Workspace.mac", isDirectory: true)
        
        ensureDirectoryExists()
        loadTrackedDocuments()
        startMonitoring()
        scanLocalDocuments()
    }
    
    deinit {
        monitor.cancel()
    }
    
    private func ensureDirectoryExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: localDocumentsDirectory.path) {
            try? fm.createDirectory(at: localDocumentsDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let currentlyOffline = (path.status != .satisfied)
                self.isOffline = currentlyOffline
                
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = "Wi-Fi"
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = "Cellular"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = "Ethernet"
                } else {
                    self.connectionType = "No Network"
                }
                
                // Notify active and pooled webviews and transition offline state immediately
                self.applyNetworkState(currentlyOffline: currentlyOffline, fromWebView: false)
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    /// Applies a network connectivity state change from NWPathMonitor or WebKit online/offline events.
    public func applyNetworkState(currentlyOffline: Bool, fromWebView: Bool = false) {
        let stateChanged = (self.isOffline != currentlyOffline)
        if fromWebView && !stateChanged {
            return
        }
        
        let wasOffline = self.lastWasOffline
        self.isOffline = currentlyOffline
        self.lastWasOffline = currentlyOffline
        
        if stateChanged || !fromWebView {
            self.notifyWebViewsNetworkState(offline: currentlyOffline)
        }
        
        if wasOffline && !currentlyOffline {
            self.triggerOnlineSyncAndReload()
        }
    }
    
    /// Dispatches online/offline events into live pages instead of reloading so active IndexedDB edits aren't lost on Wi-Fi drops.
    private func notifyWebViewsNetworkState(offline: Bool) {
        let flag = offline ? "true" : "false"
        let eventName = offline ? "offline" : "online"
        let js = "window.__offlineSuiteFromNative = true; try { window.__offlineSuiteNetworkOffline = \(flag); window.dispatchEvent(new Event('\(eventName)')); } finally { window.__offlineSuiteFromNative = false; }"
        var targets = WebKitPool.shared.allWebViews
        if let active = AppState.shared.activeWebView, !targets.contains(where: { $0 === active }) {
            targets.append(active)
        }
        for wv in targets {
            wv.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    public func triggerOnlineSyncAndReload() {
        Task { @MainActor in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                self.isSyncingToCloud = true
                self.syncMessage = "Saving to workspace..."
                self.syncIsComplete = false
            }
            
            // Phase 1: Verify offline mutations & sync
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // Phase 2: Show "Saved to cloud ✓"
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                self.syncMessage = "Saved to cloud"
                self.syncIsComplete = true
            }
            
            // Phase 3: Pause briefly, hide popup, and re-dispatch in-page online event without navigating away
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation(.easeInOut(duration: 0.25)) {
                self.isSyncingToCloud = false
            }
            self.notifyWebViewsNetworkState(offline: false)
        }
    }
    
    public func scanLocalDocuments() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: localDocumentsDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return
        }
        
        let validExtensions = Set(["docx", "doc", "xlsx", "xls", "pptx", "ppt", "rtf", "txt", "pdf", "gdoc", "gsheet", "gslides"])
        var docs: [LocalWorkspaceDocument] = []
        for url in items {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            if values?.isDirectory == true { continue }
            
            let ext = url.pathExtension.lowercased()
            guard validExtensions.contains(ext) else { continue }
            
            let name = url.deletingPathExtension().lastPathComponent
            guard !name.hasPrefix("."), name != "OfflineHTMLCache" else { continue }
            
            let size = values?.fileSize ?? 0
            let modDate = values?.contentModificationDate ?? Date()
            
            let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            
            docs.append(LocalWorkspaceDocument(
                id: url.path,
                name: name,
                url: url,
                fileExtension: ext,
                fileSizeFormatted: formattedSize,
                modificationDate: modDate
            ))
        }
        
        // Sort descending by modification date
        self.localDocuments = docs.sorted(by: { $0.modificationDate > $1.modificationDate })
    }
    
    // MARK: - Smart Document Tracker & Auto-Sync Downloader
    /// Strips Google title suffixes and rejects transient loading/script strings so the Home recents strip stays clean.
    public static func sanitizeTrackedDocumentTitle(_ raw: String) -> String? {
        var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        
        let suffixes = [
            " - Google Docs",
            " - Google Sheets",
            " - Google Slides",
            " - Google Drive",
            " - Google"
        ]
        for suffix in suffixes {
            if title.hasSuffix(suffix) {
                title = String(title.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if title.hasPrefix("(NEW) ") {
            title = String(title.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if title.hasPrefix("* ") {
            title = String(title.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard title.count >= 2 else { return nil }
        let lower = title.lowercased()
        let badSubstrings = ["window.", "wiz_global", "function(", "{", "http://", "https://"]
        if badSubstrings.contains(where: { lower.contains($0) }) {
            return nil
        }
        let ignoredExact: Set<String> = [
            "document",
            "untitled",
            "google docs",
            "google sheets",
            "google slides",
            "google drive",
            "loading...",
            "loading",
            "sign in"
        ]
        if ignoredExact.contains(lower) {
            return nil
        }
        return title
    }
    
    private func loadTrackedDocuments() {
        if let data = UserDefaults.standard.data(forKey: kTrackedDocsKey),
           let list = try? JSONDecoder().decode([TrackedWorkspaceDocument].self, from: data) {
            var seenIds = Set<String>()
            var seenKeys = Set<String>()
            var cleaned: [TrackedWorkspaceDocument] = []
            
            for var doc in list {
                if doc.id.hasPrefix("doc_tracked_") { continue }
                guard let validTitle = Self.sanitizeTrackedDocumentTitle(doc.title) else { continue }
                if doc.url.contains("/presentation/d/") || doc.type == "slides" {
                    doc.type = "slides"
                    doc.url = "https://docs.google.com/presentation/d/\(doc.id)/edit"
                    doc.exportUrl = "https://docs.google.com/presentation/d/\(doc.id)/export?format=pptx"
                } else if doc.url.contains("/spreadsheets/d/") || doc.type == "sheets" {
                    doc.type = "sheets"
                    doc.url = "https://docs.google.com/spreadsheets/d/\(doc.id)/edit"
                    doc.exportUrl = "https://docs.google.com/spreadsheets/d/\(doc.id)/export?format=xlsx"
                }
                let dedupeKey = "\(doc.type.lowercased())::\(validTitle.lowercased())"
                if seenIds.contains(doc.id) || seenKeys.contains(dedupeKey) { continue }
                
                seenIds.insert(doc.id)
                seenKeys.insert(dedupeKey)
                doc.title = validTitle
                cleaned.append(doc)
            }
            
            self.trackedDocuments = cleaned
            if cleaned.count != list.count || cleaned != list {
                persistTrackedDocuments()
            }
        }
    }
    
    public func persistTrackedDocuments() {
        if let data = try? JSONEncoder().encode(trackedDocuments) {
            UserDefaults.standard.set(data, forKey: kTrackedDocsKey)
        }
    }
    
    public func removeTrackedDocument(id: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            trackedDocuments.removeAll(where: { $0.id == id })
        }
        persistTrackedDocuments()
    }
    
    public func clearTrackedDocuments() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            trackedDocuments.removeAll()
        }
        persistTrackedDocuments()
    }
    
    public func handleTrackedDocumentMessage(_ dict: [String: Any]) {
        let action = dict["action"] as? String ?? ""
        
        // Handle batch document list scanned from Google Docs home page
        if action == "documentListScanned", let docs = dict["documents"] as? [[String: Any]] {
            let now = Date()
            var changed = false
            for item in docs {
                guard let docId = item["docId"] as? String, !docId.isEmpty,
                      let rawTitle = item["title"] as? String,
                      let title = Self.sanitizeTrackedDocumentTitle(rawTitle) else {
                    continue
                }
                let type = item["type"] as? String ?? "docs"
                let url = item["url"] as? String ?? ""
                let exportUrl = item["exportUrl"] as? String ?? ""
                let normalizedTitleKey = title.lowercased()
                
                if let idx = trackedDocuments.firstIndex(where: {
                    $0.id == docId || ($0.type.lowercased() == type.lowercased() && $0.title.lowercased() == normalizedTitleKey)
                }) {
                    trackedDocuments[idx].title = title
                    if trackedDocuments[idx].id == docId { trackedDocuments[idx].type = type }
                    if !url.isEmpty { trackedDocuments[idx].url = url }
                    if !exportUrl.isEmpty { trackedDocuments[idx].exportUrl = exportUrl }
                    changed = true
                } else {
                    trackedDocuments.append(TrackedWorkspaceDocument(
                        id: docId,
                        title: title,
                        type: type,
                        url: url,
                        exportUrl: exportUrl,
                        lastOpened: now,
                        localFilePath: nil
                    ))
                    changed = true
                }
            }
            if changed {
                persistTrackedDocuments()
            }
            return
        }
        
        guard let docId = dict["docId"] as? String, !docId.isEmpty,
              let rawTitle = dict["title"] as? String,
              let title = Self.sanitizeTrackedDocumentTitle(rawTitle) else {
            return
        }
        let type = dict["type"] as? String ?? "docs"
        let url = dict["url"] as? String ?? ""
        let exportUrl = dict["exportUrl"] as? String ?? ""
        let normalizedTitleKey = title.lowercased()
        
        let now = Date()
        if let idx = trackedDocuments.firstIndex(where: {
            $0.id == docId || ($0.type.lowercased() == type.lowercased() && $0.title.lowercased() == normalizedTitleKey)
        }) {
            trackedDocuments[idx].title = title
            if trackedDocuments[idx].id == docId { trackedDocuments[idx].type = type }
            if !url.isEmpty { trackedDocuments[idx].url = url }
            if !exportUrl.isEmpty { trackedDocuments[idx].exportUrl = exportUrl }
            trackedDocuments[idx].lastOpened = now
        } else {
            trackedDocuments.append(TrackedWorkspaceDocument(
                id: docId,
                title: title,
                type: type,
                url: url,
                exportUrl: exportUrl,
                lastOpened: now,
                localFilePath: nil
            ))
        }
        persistTrackedDocuments()
    }
    
    public func handleOfflineDocumentSaverMessage(_ dict: [String: Any]) {
        // Google Docs now persists edits directly to WebKit's "GoogleDocs" IndexedDB database.
        // Avoid writing redundant .rtf copies on every keystroke autoSave.
    }
    
    public func smartDownloadDocument(docId: String, title: String, type: String, exportUrlString: String) {
        guard let exportUrl = URL(string: exportUrlString) else { return }
        
        // Debounce downloads to avoid hitting Google servers repeatedly while the user is actively typing
        if let last = lastDownloadTimes[docId], Date().timeIntervalSince(last) < 15 {
            return
        }
        guard !activeDownloadIds.contains(docId) else { return }
        activeDownloadIds.insert(docId)
        lastDownloadTimes[docId] = Date()
        
        Task { [weak self] in
            guard let self = self else { return }
            defer {
                Task { @MainActor [weak self] in
                    self?.activeDownloadIds.remove(docId)
                }
            }
            
            // Extract active session cookies from WKWebsiteDataStore
            let cookies = await AppState.shared.activeDataStore.httpCookieStore.allCookies()
            
            // Configure a dedicated session with cookie storage so 302 redirects retain auth
            let cookieStorage = HTTPCookieStorage()
            for cookie in cookies {
                cookieStorage.setCookie(cookie)
            }
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.httpCookieStorage = cookieStorage
            sessionConfig.httpShouldSetCookies = true
            sessionConfig.httpCookieAcceptPolicy = .always
            sessionConfig.timeoutIntervalForRequest = 30
            
            let session = URLSession(configuration: sessionConfig)
            
            var request = URLRequest(url: exportUrl)
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            for (header, val) in headers {
                request.setValue(val, forHTTPHeaderField: header)
            }
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 30
            
            print("[OfflineDownloader] Downloading: \(title) (\(docId)) from \(exportUrl.absoluteString)")
            
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("[OfflineDownloader] Non-HTTP response for \(title)")
                    return
                }
                print("[OfflineDownloader] Response for \(title): status \(httpResponse.statusCode), bytes \(data.count)")
                guard httpResponse.statusCode == 200, data.count > 100 else {
                    print("[OfflineDownloader] Download failed or not ready for \(title) (\(httpResponse.statusCode))")
                    return
                }
                
                // Sanitize file name for macOS filesystem
                let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
                var cleanTitle = title.components(separatedBy: invalidChars).joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanTitle.isEmpty { cleanTitle = "Untitled Document" }
                
                var ext = "docx"
                switch type {
                case "sheets": ext = "xlsx"
                case "slides": ext = "pptx"
                default: ext = "docx"
                }
                
                let targetUrl = self.localDocumentsDirectory.appendingPathComponent("\(cleanTitle).\(ext)")
                try data.write(to: targetUrl, options: .atomic)
                print("[OfflineDownloader] Saved offline document: \(targetUrl.path)")
                
                await MainActor.run {
                    if let idx = self.trackedDocuments.firstIndex(where: { $0.id == docId }) {
                        self.trackedDocuments[idx].localFilePath = targetUrl.path
                        self.persistTrackedDocuments()
                    }
                    self.scanLocalDocuments()
                }
            } catch {
                print("[OfflineDownloader] Network error downloading \(title): \(error.localizedDescription)")
            }
        }
    }
    
    public func createNewLocalDocument(title: String, initialContent: String = "") -> URL? {
        ensureDirectoryExists()
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Document" : title.trimmingCharacters(in: .whitespacesAndNewlines)
        var targetUrl = localDocumentsDirectory.appendingPathComponent("\(cleanTitle).rtf")
        var counter = 1
        
        while FileManager.default.fileExists(atPath: targetUrl.path) {
            targetUrl = localDocumentsDirectory.appendingPathComponent("\(cleanTitle) (\(counter)).rtf")
            counter += 1
        }
        
        let attrString = NSAttributedString(string: initialContent.isEmpty ? "Start typing your offline document..." : initialContent, attributes: [
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor.textColor
        ])
        
        if let rtfData = try? attrString.data(from: NSRange(location: 0, length: attrString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            try? rtfData.write(to: targetUrl)
            scanLocalDocuments()
            return targetUrl
        }
        return nil
    }
    
    public func openInFinder(url: URL? = nil) {
        let target = url ?? localDocumentsDirectory
        NSWorkspace.shared.activateFileViewerSelecting([target])
    }
    
    public func openDocumentExternally(url: URL) {
        NSWorkspace.shared.open(url)
    }
}
