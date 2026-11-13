import Foundation
import Network
import Combine
import AppKit

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
    
    // Directory: ~/Documents/Workspace.mac/
    public let localDocumentsDirectory: URL
    
    private var lastWasOffline: Bool = false
    
    public init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.localDocumentsDirectory = docs.appendingPathComponent("Workspace.mac", isDirectory: true)
        
        ensureDirectoryExists()
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
                
                // If transitioning from offline to online, signal auto-reload across active webviews
                if self.lastWasOffline && !currentlyOffline {
                    AppState.shared.webViewActionSignal = .reload
                    if let curApp = AppState.shared.selectedApp {
                        AppState.shared.activeWebView?.load(URLRequest(url: curApp.url))
                    } else {
                        AppState.shared.activeWebView?.reload()
                    }
                }
                self.lastWasOffline = currentlyOffline
            }
        }
        monitor.start(queue: monitorQueue)
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
