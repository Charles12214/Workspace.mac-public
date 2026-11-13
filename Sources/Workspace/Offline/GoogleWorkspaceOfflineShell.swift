import Foundation
import WebKit

/// Generates the Google Workspace Offline Web App Shell.
/// When the device is offline or when provisional navigation to Google servers fails (-1009),
/// this native shell renders the exact Google Docs / Sheets / Slides / Drive web interface
/// (matching Google Chrome's offline experience) within the WebKit view origin.
public struct GoogleWorkspaceOfflineShell {
    
    @MainActor
    public static func html(for app: WorkspaceAppItem, userName: String, userEmail: String) -> String {
        let fileName: String
        switch app.id {
        case "sheets": fileName = "sheets.html"
        case "slides": fileName = "slides.html"
        case "drive": fileName = "drive.html"
        default: fileName = "docs.html"
        }
        
        // 1. Try App Bundle Resources/OfflineShells/
        if let bundleUrl = Bundle.main.url(forResource: (fileName as NSString).deletingPathExtension, withExtension: "html", subdirectory: "OfflineShells"),
           let content = try? String(contentsOf: bundleUrl, encoding: .utf8), !content.isEmpty {
            return content
        }
        
        // 2. Try working directory Resources/OfflineShells/
        let workingDirFile = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/OfflineShells")
            .appendingPathComponent(fileName)
        if let content = try? String(contentsOf: workingDirFile, encoding: .utf8), !content.isEmpty {
            return content
        }
        
        let appName = app.name
        let appColor: String
        let appIconSvg: String
        let newLabel: String
        
        switch app.id {
        case "sheets":
            appColor = "#0F9D58"
            newLabel = "Blank spreadsheet"
            appIconSvg = """
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H5V5h14v14z" fill="#0F9D58"/><path d="M7 7h10v2H7zm0 4h10v2H7zm0 4h7v2H7z" fill="#0F9D58"/></svg>
            """
        case "slides":
            appColor = "#F4B400"
            newLabel = "Blank presentation"
            appIconSvg = """
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H5V5h14v14z" fill="#F4B400"/><path d="M8 8h8v8H8z" fill="#F4B400"/></svg>
            """
        case "drive":
            appColor = "#1A73E8"
            newLabel = "New Document"
            appIconSvg = """
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M7.71 3.5L1.15 15l3.43 6 6.55-11.5-3.42-6z" fill="#FFBA00"/><path d="M16.29 3.5l-6.55 11.5h6.86l6.55-11.5h-6.86z" fill="#0066DA"/><path d="M16.6 21H3.4l3.43-6h13.2l-3.43 6z" fill="#00AC47"/></svg>
            """
        default: // docs
            appColor = "#1A73E8"
            newLabel = "Blank document"
            appIconSvg = """
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z" fill="#1A73E8"/></svg>
            """
        }
        
        let initialLetter = userName.prefix(1).uppercased().isEmpty ? "U" : String(userName.prefix(1).uppercased())
        
        // Documents list
        let docs = OfflineManager.shared.localDocuments
        var docRowsHtml = ""
        
        if docs.isEmpty {
            docRowsHtml = """
            <div class="empty-state">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none" style="opacity: 0.35;"><path d="M14 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z" fill="currentColor"/></svg>
                <div class="empty-title">No offline documents yet</div>
                <div class="empty-desc">Create a new document above or open documents online to cache them for offline use.</div>
            </div>
            """
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "d MMM yyyy"
            
            for doc in docs {
                let dateStr = dateFormatter.string(from: doc.modificationDate)
                docRowsHtml += """
                <div class="doc-row" onclick="openOfflineDoc('\(doc.id)', '\(doc.name)')">
                    <div class="doc-title-cell">
                        \(appIconSvg)
                        <span class="doc-title-text">\(doc.name)</span>
                    </div>
                    <div class="doc-owner-cell">me</div>
                    <div class="doc-date-cell">\(dateStr)</div>
                </div>
                """
            }
        }
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(appName) - Offline Mode</title>
            <style>
                :root {
                    --app-color: \(appColor);
                    --bg-color: #ffffff;
                    --text-primary: #202124;
                    --text-secondary: #5f6368;
                    --border-color: #dadce0;
                    --hover-bg: #f1f3f4;
                    --card-bg: #f8f9fa;
                }
                @media (prefers-color-scheme: dark) {
                    :root {
                        --bg-color: #1f1f1f;
                        --text-primary: #e8eaed;
                        --text-secondary: #9aa0a6;
                        --border-color: #3c4043;
                        --hover-bg: #2d2e30;
                        --card-bg: #28292a;
                    }
                }
                * {
                    box-sizing: border-box;
                    margin: 0;
                    padding: 0;
                    user-select: none;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Google Sans", "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    background-color: var(--bg-color);
                    color: var(--text-primary);
                    height: 100vh;
                    display: flex;
                    flex-direction: column;
                    overflow-x: hidden;
                }
                
                /* Top Header */
                header {
                    height: 64px;
                    border-bottom: 1px solid var(--border-color);
                    display: flex;
                    align-items: center;
                    padding: 0 16px;
                    gap: 16px;
                    flex-shrink: 0;
                }
                .menu-btn {
                    width: 40px;
                    height: 40px;
                    border-radius: 50%;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    cursor: pointer;
                    color: var(--text-secondary);
                }
                .menu-btn:hover { background-color: var(--hover-bg); }
                .brand {
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    cursor: pointer;
                }
                .brand-title {
                    font-size: 20px;
                    font-weight: 500;
                    color: var(--text-primary);
                }
                
                /* Search Box */
                .search-container {
                    flex: 1;
                    max-width: 720px;
                    margin: 0 auto;
                    position: relative;
                }
                .search-box {
                    width: 100%;
                    height: 46px;
                    background-color: var(--hover-bg);
                    border: 1px solid transparent;
                    border-radius: 24px;
                    padding: 0 16px 0 46px;
                    font-size: 15px;
                    color: var(--text-primary);
                    outline: none;
                    transition: all 0.2s ease;
                }
                .search-box:focus {
                    background-color: var(--bg-color);
                    border-color: var(--border-color);
                    box-shadow: 0 1px 3px rgba(0,0,0,0.12);
                }
                .search-icon {
                    position: absolute;
                    left: 16px;
                    top: 14px;
                    color: var(--text-secondary);
                    pointer-events: none;
                }
                
                /* Right actions */
                .right-actions {
                    display: flex;
                    align-items: center;
                    gap: 12px;
                }
                .offline-status-badge {
                    display: flex;
                    align-items: center;
                    gap: 6px;
                    font-size: 12px;
                    font-weight: 500;
                    color: #f59e0b;
                    background-color: rgba(245, 158, 11, 0.12);
                    padding: 5px 10px;
                    border-radius: 14px;
                    border: 1px solid rgba(245, 158, 11, 0.25);
                }
                .avatar {
                    width: 32px;
                    height: 32px;
                    border-radius: 50%;
                    background-color: var(--app-color);
                    color: white;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-weight: 600;
                    font-size: 14px;
                }
                
                /* Template Gallery / Start New */
                .templates-strip {
                    background-color: var(--card-bg);
                    padding: 24px 32px;
                    border-bottom: 1px solid var(--border-color);
                }
                .strip-header {
                    font-size: 14px;
                    font-weight: 500;
                    color: var(--text-secondary);
                    margin-bottom: 16px;
                    max-width: 960px;
                    margin-left: auto;
                    margin-right: auto;
                }
                .templates-grid {
                    display: flex;
                    gap: 20px;
                    max-width: 960px;
                    margin: 0 auto;
                }
                .template-card {
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    gap: 8px;
                    cursor: pointer;
                }
                .template-thumb {
                    width: 128px;
                    height: 160px;
                    background-color: var(--bg-color);
                    border: 1px solid var(--border-color);
                    border-radius: 6px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    transition: all 0.2s ease;
                }
                .template-card:hover .template-thumb {
                    border-color: var(--app-color);
                    box-shadow: 0 2px 8px rgba(0,0,0,0.12);
                    transform: translateY(-2px);
                }
                .template-name {
                    font-size: 13px;
                    font-weight: 500;
                    color: var(--text-primary);
                }
                
                /* Recent Documents Section */
                .recent-container {
                    flex: 1;
                    max-width: 960px;
                    width: 100%;
                    margin: 0 auto;
                    padding: 24px 32px;
                    overflow-y: auto;
                }
                .recent-header {
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    margin-bottom: 12px;
                    padding-bottom: 8px;
                    font-size: 14px;
                    font-weight: 600;
                    color: var(--text-primary);
                }
                .col-headers {
                    display: grid;
                    grid-template-columns: 1fr 140px 140px;
                    padding: 8px 16px;
                    font-size: 12px;
                    font-weight: 600;
                    color: var(--text-secondary);
                    border-bottom: 1px solid var(--border-color);
                }
                
                /* Document Rows */
                .doc-row {
                    display: grid;
                    grid-template-columns: 1fr 140px 140px;
                    align-items: center;
                    padding: 12px 16px;
                    border-bottom: 1px solid var(--border-color);
                    cursor: pointer;
                    transition: background 0.15s ease;
                    border-radius: 6px;
                }
                .doc-row:hover {
                    background-color: var(--hover-bg);
                }
                .doc-title-cell {
                    display: flex;
                    align-items: center;
                    gap: 12px;
                }
                .doc-title-text {
                    font-size: 14px;
                    font-weight: 500;
                    color: var(--text-primary);
                }
                .doc-owner-cell, .doc-date-cell {
                    font-size: 13px;
                    color: var(--text-secondary);
                }
                
                /* Empty state */
                .empty-state {
                    text-align: center;
                    padding: 60px 20px;
                    color: var(--text-secondary);
                }
                .empty-title {
                    font-size: 16px;
                    font-weight: 600;
                    margin-top: 14px;
                    color: var(--text-primary);
                }
                .empty-desc {
                    font-size: 13px;
                    margin-top: 6px;
                    max-width: 380px;
                    margin-left: auto;
                    margin-right: auto;
                    line-height: 1.5;
                }
                
                /* In-App Fullscreen Offline Editor Modal */
                #editorModal {
                    display: none;
                    position: fixed;
                    top: 0;
                    left: 0;
                    right: 0;
                    bottom: 0;
                    background-color: var(--bg-color);
                    z-index: 1000;
                    flex-direction: column;
                }
                .editor-header {
                    height: 60px;
                    border-bottom: 1px solid var(--border-color);
                    display: flex;
                    align-items: center;
                    padding: 0 16px;
                    gap: 14px;
                }
                .editor-title-input {
                    font-size: 18px;
                    font-weight: 500;
                    color: var(--text-primary);
                    background: transparent;
                    border: 1px solid transparent;
                    padding: 4px 8px;
                    border-radius: 4px;
                    outline: none;
                }
                .editor-title-input:hover, .editor-title-input:focus {
                    border-color: var(--border-color);
                }
                .editor-toolbar {
                    height: 40px;
                    background-color: var(--card-bg);
                    border-bottom: 1px solid var(--border-color);
                    display: flex;
                    align-items: center;
                    padding: 0 16px;
                    gap: 6px;
                }
                .tool-btn {
                    padding: 4px 8px;
                    border-radius: 4px;
                    background: transparent;
                    border: none;
                    cursor: pointer;
                    font-size: 13px;
                    font-weight: bold;
                    color: var(--text-primary);
                }
                .tool-btn:hover { background-color: var(--hover-bg); }
                .editor-canvas-container {
                    flex: 1;
                    background-color: var(--card-bg);
                    overflow-y: auto;
                    padding: 32px 16px;
                    display: flex;
                    justify-content: center;
                }
                .editor-paper {
                    width: 100%;
                    max-width: 816px;
                    min-height: 1056px;
                    background-color: var(--bg-color);
                    border: 1px solid var(--border-color);
                    box-shadow: 0 1px 4px rgba(0,0,0,0.1);
                    padding: 72px 96px;
                    font-size: 15px;
                    line-height: 1.6;
                    color: var(--text-primary);
                    outline: none;
                    user-select: text;
                }
            </style>
        </head>
        <body>
            <!-- Top Header -->
            <header>
                <div class="menu-btn">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none"><path d="M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z" fill="currentColor"/></svg>
                </div>
                <div class="brand" onclick="location.reload()">
                    \(appIconSvg)
                    <span class="brand-title">\(appName)</span>
                </div>
                
                <div class="search-container">
                    <svg class="search-icon" width="20" height="20" viewBox="0 0 24 24" fill="none"><path d="M15.5 14h-.79l-.28-.27A6.471 6.471 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z" fill="currentColor"/></svg>
                    <input type="text" class="search-box" id="docSearch" placeholder="Search in \(appName)" oninput="filterDocs(this.value)">
                </div>
                
                <div class="right-actions">
                    <div class="offline-status-badge">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM10 17l-3.5-3.5 1.41-1.41L10 14.17l5.59-5.59L17 10l-7 7z" fill="currentColor"/></svg>
                        <span>Offline Ready</span>
                    </div>
                    <div class="avatar">\(initialLetter)</div>
                </div>
            </header>
            
            <!-- Template Strip (Start New) -->
            <div class="templates-strip">
                <div class="strip-header">Start a new document</div>
                <div class="templates-grid">
                    <div class="template-card" onclick="createNewDoc()">
                        <div class="template-thumb">
                            <svg width="40" height="40" viewBox="0 0 24 24" fill="none"><path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z" fill="\(appColor)"/></svg>
                        </div>
                        <span class="template-name">\(newLabel)</span>
                    </div>
                </div>
            </div>
            
            <!-- Recent Documents -->
            <div class="recent-container">
                <div class="recent-header">
                    <span>Recent documents</span>
                </div>
                <div class="col-headers">
                    <span>Title</span>
                    <span>Owned by</span>
                    <span>Last opened</span>
                </div>
                <div id="docsList">
                    \(docRowsHtml)
                </div>
            </div>
            
            <!-- In-App Fullscreen Offline Editor Modal -->
            <div id="editorModal">
                <div class="editor-header">
                    <div class="menu-btn" onclick="closeEditor()">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none"><path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z" fill="currentColor"/></svg>
                    </div>
                    \(appIconSvg)
                    <input type="text" class="editor-title-input" id="editorTitle" value="Untitled Document" oninput="saveCurrentDoc()">
                    <div style="flex:1"></div>
                    <div class="offline-status-badge">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM10 17l-3.5-3.5 1.41-1.41L10 14.17l5.59-5.59L17 10l-7 7z" fill="currentColor"/></svg>
                        <span id="saveStatus">Saved locally</span>
                    </div>
                </div>
                <div class="editor-toolbar">
                    <button class="tool-btn" onclick="document.execCommand('bold')">B</button>
                    <button class="tool-btn" onclick="document.execCommand('italic')">I</button>
                    <button class="tool-btn" onclick="document.execCommand('underline')">U</button>
                    <span style="border-left: 1px solid var(--border-color); height: 18px; margin: 0 4px;"></span>
                    <button class="tool-btn" onclick="document.execCommand('justifyLeft')">Left</button>
                    <button class="tool-btn" onclick="document.execCommand('justifyCenter')">Center</button>
                    <button class="tool-btn" onclick="document.execCommand('justifyRight')">Right</button>
                    <span style="border-left: 1px solid var(--border-color); height: 18px; margin: 0 4px;"></span>
                    <button class="tool-btn" onclick="document.execCommand('insertUnorderedList')">• List</button>
                </div>
                <div class="editor-canvas-container">
                    <div class="editor-paper" id="editorPaper" contenteditable="true" oninput="saveCurrentDoc()">
                    </div>
                </div>
            </div>
            
            <script>
                let currentActiveDocId = null;
                
                function filterDocs(query) {
                    const q = query.toLowerCase();
                    const rows = document.querySelectorAll('.doc-row');
                    rows.forEach(r => {
                        const title = r.querySelector('.doc-title-text').innerText.toLowerCase();
                        r.style.display = title.includes(q) ? 'grid' : 'none';
                    });
                }
                
                function createNewDoc() {
                    currentActiveDocId = 'doc_' + Date.now();
                    document.getElementById('editorTitle').value = 'Untitled Document';
                    document.getElementById('editorPaper').innerHTML = '<p>Start typing offline...</p>';
                    document.getElementById('editorModal').style.display = 'flex';
                }
                
                function openOfflineDoc(id, title) {
                    currentActiveDocId = id;
                    document.getElementById('editorTitle').value = title;
                    const cached = localStorage.getItem('offline_' + id) || '<p>Loaded offline document.</p>';
                    document.getElementById('editorPaper').innerHTML = cached;
                    document.getElementById('editorModal').style.display = 'flex';
                }
                
                function closeEditor() {
                    document.getElementById('editorModal').style.display = 'none';
                    location.reload();
                }
                
                function saveCurrentDoc() {
                    if (!currentActiveDocId) return;
                    const content = document.getElementById('editorPaper').innerHTML;
                    const title = document.getElementById('editorTitle').value;
                    localStorage.setItem('offline_' + currentActiveDocId, content);
                    localStorage.setItem('title_' + currentActiveDocId, title);
                    
                    const status = document.getElementById('saveStatus');
                    status.innerText = 'Saved locally';
                    
                    // Notify background extension
                    if (window.chrome && window.chrome.runtime && window.chrome.runtime.sendMessage) {
                        window.chrome.runtime.sendMessage({
                            type: 'saveDocument',
                            document: { id: currentActiveDocId, title: title, contentSnapshot: content }
                        });
                    }
                }
            </script>
        </body>
        </html>
        """
    }
}
