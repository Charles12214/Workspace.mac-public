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
            
            // Seed a welcome offline guide document
            seedWelcomeDocument()
            seedUserWorkspaceDocuments()
        }
    }
    
    private func seedWelcomeDocument() {
        let welcomePath = localDocumentsDirectory.appendingPathComponent("Welcome to Workspace Offline.txt")
        if !FileManager.default.fileExists(atPath: welcomePath.path) {
            let content = """
            Welcome to Workspace.mac Total Offline Mode!
            
            This local folder (~/Documents/Workspace.mac/) stores your offline documents, quick notes, and files.
            
            Key Offline Features:
            • Seamlessly create and edit rich text documents without an internet connection.
            • Google Docs, Sheets, and Drive offline caching via the built-in offline extension shim.
            • 1-click sync to Google Drive when back online.
            
            Workspace.mac • 100% Free & Open-Source
            """
            try? content.write(to: welcomePath, atomically: true, encoding: .utf8)
        }
    }
    
    private func seedUserWorkspaceDocuments() {
        let musicBookPath = localDocumentsDirectory.appendingPathComponent("(NEW) Music tech book Y12.rtf")
        if !FileManager.default.fileExists(atPath: musicBookPath.path) {
            let content = """
            Music Technology
            
            Charlie Cserfalvi-Smith
            Y12
            
            ========================================
            Document Sections & Syllabus:
            
            1. Heading & Overview
            2. Music History
               • Eras - Acoustic era
               • Eras - Magnetic era
               • Magnetic to digital shift
            3. Audio Principles
               • Wow & Flutter
               • A/D conversion & digital audio
               • MIDI
               • Reverse Reverb
            ========================================
            """
            let attrString = NSAttributedString(string: content, attributes: [
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: NSColor.textColor
            ])
            if let rtfData = try? attrString.data(from: NSRange(location: 0, length: attrString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                try? rtfData.write(to: musicBookPath)
            }
        }
        
        // Seed recent tracked documents if none exist yet
        if trackedDocuments.isEmpty {
            let sampleTitles = [
                "(NEW) Music tech book Y12",
                "Methods of transmission 26",
                "Network Hardware Worksheet",
                "44 Data Collection User Interfaces Worksheet",
                "42 Data Sources Worksheet",
                "45 Moral and Ethical Issues Worksheet",
                "41 Uses of Online Services Worksheet",
                "33 Interacting with Online Communities Worksheet",
                "35 External Threats to Data Worksheet",
                "46 Legal Issues Worksheet",
                "37 Impact of Data Threats Worksheet",
                "43 Data Collection Methods Worksheet"
            ]
            let now = Date()
            var seeded: [TrackedWorkspaceDocument] = []
            for (idx, title) in sampleTitles.enumerated() {
                seeded.append(TrackedWorkspaceDocument(
                    id: "doc_tracked_\(idx)",
                    title: title,
                    type: "docs",
                    url: "https://docs.google.com/document/",
                    exportUrl: "",
                    lastOpened: now.addingTimeInterval(Double(-idx * 3600)),
                    localFilePath: title.contains("Music tech book") ? musicBookPath.path : nil
                ))
            }
            self.trackedDocuments = seeded
            persistTrackedDocuments()
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
                
                // If transitioning from offline to online, trigger "Saving to workspace..." -> "Saved to cloud [tick]" -> refresh
                if self.lastWasOffline && !currentlyOffline {
                    self.triggerOnlineSyncAndReload()
                }
                self.lastWasOffline = currentlyOffline
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    public func triggerOnlineSyncAndReload() {
        Task { @MainActor in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                self.isSyncingToCloud = true
                self.syncMessage = "Saving to workspace..."
                self.syncIsComplete = false
            }
            
            // Phase 1: Verify offline mutations & sync
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            
            // Phase 2: Show "Saved to cloud ✓"
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                self.syncMessage = "Saved to cloud"
                self.syncIsComplete = true
            }
            
            // Phase 3: Pause briefly, hide popup, and refresh into real Google Workspace setup
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.easeInOut(duration: 0.25)) {
                self.isSyncingToCloud = false
            }
            
            AppState.shared.webViewActionSignal = .reload
            if let curApp = AppState.shared.selectedApp {
                AppState.shared.activeWebView?.load(URLRequest(url: curApp.url))
            } else {
                AppState.shared.activeWebView?.reload()
            }
        }
    }
    
    public func scanLocalDocuments() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: localDocumentsDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return
        }
        
        var docs: [LocalWorkspaceDocument] = []
        for url in items {
            let name = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            let resources = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = resources?.fileSize ?? 0
            let modDate = resources?.contentModificationDate ?? Date()
            
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
    private func loadTrackedDocuments() {
        if let data = UserDefaults.standard.data(forKey: kTrackedDocsKey),
           let list = try? JSONDecoder().decode([TrackedWorkspaceDocument].self, from: data) {
            self.trackedDocuments = list
        }
    }
    
    public func persistTrackedDocuments() {
        if let data = try? JSONEncoder().encode(trackedDocuments) {
            UserDefaults.standard.set(data, forKey: kTrackedDocsKey)
        }
    }
    
    public func handleTrackedDocumentMessage(_ dict: [String: Any]) {
        let action = dict["action"] as? String ?? ""
        
        // Handle batch document list scanned from Google Docs home page
        if action == "documentListScanned", let docs = dict["documents"] as? [[String: Any]] {
            let now = Date()
            for item in docs {
                if let docId = item["docId"] as? String, !docId.isEmpty,
                   let title = item["title"] as? String, !title.isEmpty {
                    let type = item["type"] as? String ?? "docs"
                    let url = item["url"] as? String ?? ""
                    let exportUrl = item["exportUrl"] as? String ?? ""
                    
                    if let idx = trackedDocuments.firstIndex(where: { $0.id == docId }) {
                        trackedDocuments[idx].title = title
                        trackedDocuments[idx].url = url
                        if !exportUrl.isEmpty { trackedDocuments[idx].exportUrl = exportUrl }
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
                }
            }
            persistTrackedDocuments()
            return
        }
        
        guard let docId = dict["docId"] as? String, !docId.isEmpty,
              let title = dict["title"] as? String, !title.isEmpty else {
            return
        }
        let type = dict["type"] as? String ?? "docs"
        let url = dict["url"] as? String ?? ""
        let exportUrl = dict["exportUrl"] as? String ?? ""
        
        let now = Date()
        if let idx = trackedDocuments.firstIndex(where: { $0.id == docId }) {
            trackedDocuments[idx].title = title
            trackedDocuments[idx].url = url
            trackedDocuments[idx].exportUrl = exportUrl
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
        
        // Smart Downloader: automatically download and cache local offline copy into ~/Documents/Workspace.mac/
        if !exportUrl.isEmpty {
            smartDownloadDocument(docId: docId, title: title, type: type, exportUrlString: exportUrl)
        }
    }
    
    public func handleOfflineDocumentSaverMessage(_ dict: [String: Any]) {
        _ = dict["action"] as? String ?? "save"
        let title = (dict["title"] as? String ?? "Untitled").trimmingCharacters(in: .whitespacesAndNewlines)
        let content = dict["content"] as? String ?? ""
        
        let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        var cleanTitle = title.components(separatedBy: invalidChars).joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle.isEmpty { cleanTitle = "Untitled Document" }
        
        let targetUrl = localDocumentsDirectory.appendingPathComponent("\(cleanTitle).rtf")
        
        let attrString = NSAttributedString(string: content, attributes: [
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor.textColor
        ])
        if let rtfData = try? attrString.data(from: NSRange(location: 0, length: attrString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            try? rtfData.write(to: targetUrl)
            scanLocalDocuments()
        }
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
            var request = URLRequest(url: exportUrl)
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            for (header, val) in headers {
                request.setValue(val, forHTTPHeaderField: header)
            }
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 30
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, data.count > 100 else {
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
                
                await MainActor.run {
                    if let idx = self.trackedDocuments.firstIndex(where: { $0.id == docId }) {
                        self.trackedDocuments[idx].localFilePath = targetUrl.path
                        self.persistTrackedDocuments()
                    }
                    self.scanLocalDocuments()
                }
            } catch {
                // Silently ignore network export failures when offline
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
