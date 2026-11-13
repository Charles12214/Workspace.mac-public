import Foundation
import AppKit

/// Generates authentic, pixel-perfect Google Workspace offline views (Docs, Sheets, Slides, Drive)
/// populated with the user's actual tracked documents and local files.
@MainActor
public struct GoogleWorkspaceOfflineEngine {
    
    public static func html(for app: WorkspaceAppItem, activeDocId: String? = nil) -> String {
        let userName = AppState.shared.userProfile.name.isEmpty ? "Charlie Cserfalvi-Smith" : AppState.shared.userProfile.name
        let localDocs = OfflineManager.shared.localDocuments
        let trackedDocs = OfflineManager.shared.trackedDocuments
        
        let appType: String
        let appName: String
        let iconSvg: String
        
        switch app.id {
        case "sheets":
            appType = "sheets"
            appName = "Sheets"
            iconSvg = sheetsIconSvg
        case "slides":
            appType = "slides"
            appName = "Slides"
            iconSvg = slidesIconSvg
        case "drive":
            appType = "drive"
            appName = "Drive"
            iconSvg = driveIconSvg
        default:
            appType = "docs"
            appName = "Docs"
            iconSvg = docsIconSvg
        }
        
        // Prepare list of documents
        var docItems: [[String: String]] = []
        
        // Add tracked documents first
        for td in trackedDocs {
            if td.type == appType || (appType == "docs" && td.type != "sheets" && td.type != "slides") || appType == "drive" {
                let dateStr = formattedDate(td.lastOpened)
                docItems.append([
                    "id": td.id,
                    "title": td.title,
                    "type": td.type,
                    "ext": td.fileExtension,
                    "date": dateStr,
                    "isLocal": td.localFilePath != nil ? "true" : "false"
                ])
            }
        }
        
        // Add local documents from ~/Documents/Workspace.mac/
        for ld in localDocs {
            if !docItems.contains(where: { $0["title"] == ld.name }) {
                docItems.append([
                    "id": ld.url.lastPathComponent,
                    "title": ld.name,
                    "type": ld.isRichDocument ? "docs" : (ld.fileExtension == "xlsx" ? "sheets" : (ld.fileExtension == "pptx" ? "slides" : "drive")),
                    "ext": ld.fileExtension,
                    "date": formattedDate(ld.modificationDate),
                    "isLocal": "true"
                ])
            }
        }
        
        let docsJson = (try? String(data: JSONSerialization.data(withJSONObject: docItems, options: []), encoding: .utf8)) ?? "[]"
        let initialDocId = activeDocId ?? ""
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(appName) - Google Workspace (Offline)</title>
            <style>
                * { box-sizing: border-box; margin: 0; padding: 0; }
                body {
                    font-family: 'Google Sans', Roboto, -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
                    background-color: #f8fafd;
                    color: #1f1f1f;
                    height: 100vh;
                    display: flex;
                    flex-direction: column;
                    overflow: hidden;
                    user-select: none;
                    -webkit-font-smoothing: antialiased;
                }
                
                /* ================= Header ================= */
                .top-header {
                    height: 64px;
                    background: #ffffff;
                    border-bottom: 1px solid #e0e0e0;
                    display: flex;
                    align-items: center;
                    padding: 0 16px;
                    gap: 16px;
                    flex-shrink: 0;
                    z-index: 10;
                }
                .brand-group {
                    display: flex;
                    align-items: center;
                    gap: 12px;
                    cursor: pointer;
                }
                .menu-btn {
                    width: 40px;
                    height: 40px;
                    border-radius: 50%;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    cursor: pointer;
                    color: #5f6368;
                }
                .menu-btn:hover { background: #f1f3f4; }
                .app-title {
                    font-size: 22px;
                    font-weight: 400;
                    color: #444746;
                    display: flex;
                    align-items: center;
                    gap: 8px;
                }
                .search-bar {
                    flex: 1;
                    max-width: 720px;
                    height: 48px;
                    background: #edf2fc;
                    border-radius: 24px;
                    display: flex;
                    align-items: center;
                    padding: 0 18px;
                    gap: 12px;
                    color: #444746;
                    transition: background 0.2s, box-shadow 0.2s;
                }
                .search-bar:focus-within {
                    background: #ffffff;
                    box-shadow: 0 1px 3px rgba(60,64,67,0.3), 0 4px 8px 3px rgba(60,64,67,0.15);
                }
                .search-input {
                    border: none;
                    background: transparent;
                    outline: none;
                    font-size: 16px;
                    width: 100%;
                    color: #1f1f1f;
                }
                .header-actions {
                    display: flex;
                    align-items: center;
                    gap: 12px;
                    margin-left: auto;
                }
                .offline-pill {
                    display: flex;
                    align-items: center;
                    gap: 6px;
                    background: #fef7e0;
                    color: #b06000;
                    font-size: 12px;
                    font-weight: 500;
                    padding: 6px 12px;
                    border-radius: 16px;
                    border: 1px solid #f9ab00;
                }
                .avatar {
                    width: 32px;
                    height: 32px;
                    border-radius: 50%;
                    background: #1a73e8;
                    color: white;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-weight: 600;
                    font-size: 14px;
                }
                
                /* ================= Document List View ================= */
                .list-container {
                    flex: 1;
                    overflow-y: auto;
                    padding: 24px 80px;
                    display: flex;
                    flex-direction: column;
                }
                .section-header {
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    padding: 8px 16px;
                    font-size: 14px;
                    font-weight: 500;
                    color: #444746;
                    border-bottom: 1px solid #e0e2e5;
                    margin-bottom: 8px;
                }
                .section-col-title { flex: 2; }
                .section-col-owner { flex: 1; text-align: left; }
                .section-col-date { flex: 1; text-align: left; }
                .section-col-actions { width: 48px; text-align: right; }
                
                .doc-row {
                    display: flex;
                    align-items: center;
                    padding: 12px 16px;
                    border-radius: 8px;
                    cursor: pointer;
                    transition: background 0.15s;
                }
                .doc-row:hover { background: #e8f0fe; }
                .doc-title-cell {
                    flex: 2;
                    display: flex;
                    align-items: center;
                    gap: 14px;
                    font-size: 14px;
                    font-weight: 500;
                    color: #1f1f1f;
                }
                .doc-owner-cell { flex: 1; font-size: 13px; color: #5f6368; }
                .doc-date-cell { flex: 1; font-size: 13px; color: #5f6368; }
                .doc-action-cell { width: 48px; text-align: right; color: #5f6368; }
                .icon-svg { width: 24px; height: 24px; flex-shrink: 0; }
                
                .new-doc-fab {
                    position: fixed;
                    bottom: 32px;
                    right: 32px;
                    background: #ffffff;
                    border-radius: 16px;
                    padding: 14px 20px;
                    box-shadow: 0 4px 12px rgba(0,0,0,0.18);
                    display: flex;
                    align-items: center;
                    gap: 12px;
                    font-size: 14px;
                    font-weight: 500;
                    color: #1f1f1f;
                    cursor: pointer;
                    transition: transform 0.15s, box-shadow 0.15s;
                }
                .new-doc-fab:hover {
                    transform: translateY(-2px);
                    box-shadow: 0 6px 16px rgba(0,0,0,0.22);
                }
                
                /* ================= Document Editor View ================= */
                .editor-container {
                    flex: 1;
                    display: none;
                    flex-direction: column;
                    background: #f8fafd;
                    overflow: hidden;
                }
                .editor-header {
                    background: #ffffff;
                    border-bottom: 1px solid #e0e0e0;
                    padding: 8px 16px;
                    display: flex;
                    flex-direction: column;
                    gap: 4px;
                    flex-shrink: 0;
                }
                .editor-top-bar {
                    display: flex;
                    align-items: center;
                    gap: 12px;
                }
                .editor-doc-title {
                    font-size: 18px;
                    font-weight: 500;
                    color: #1f1f1f;
                    outline: none;
                    border: 1px solid transparent;
                    padding: 2px 6px;
                    border-radius: 4px;
                    cursor: text;
                }
                .editor-doc-title:focus {
                    background: #ffffff;
                    border-color: #1a73e8;
                }
                .working-offline-badge {
                    display: inline-flex;
                    align-items: center;
                    gap: 5px;
                    font-size: 12px;
                    color: #5f6368;
                    margin-left: 8px;
                }
                .menu-bar {
                    display: flex;
                    gap: 12px;
                    font-size: 13px;
                    color: #444746;
                    margin-left: 44px;
                }
                .menu-item { cursor: pointer; padding: 2px 4px; border-radius: 4px; }
                .menu-item:hover { background: #f1f3f4; }
                
                .editor-toolbar {
                    background: #edf2fc;
                    border-radius: 24px;
                    height: 40px;
                    margin: 6px 16px;
                    padding: 0 12px;
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    flex-shrink: 0;
                }
                .toolbar-btn {
                    padding: 6px 8px;
                    border-radius: 4px;
                    border: none;
                    background: transparent;
                    cursor: pointer;
                    font-size: 13px;
                    color: #444746;
                    display: flex;
                    align-items: center;
                    gap: 4px;
                }
                .toolbar-btn:hover { background: #d3e3fd; }
                .toolbar-sep { width: 1px; height: 18px; background: #c4c7c5; margin: 0 4px; }
                
                .editor-workspace {
                    flex: 1;
                    display: flex;
                    overflow: hidden;
                }
                .doc-tabs-sidebar {
                    width: 220px;
                    background: #ffffff;
                    border-right: 1px solid #e0e0e0;
                    padding: 16px;
                    overflow-y: auto;
                    display: flex;
                    flex-direction: column;
                    gap: 8px;
                    flex-shrink: 0;
                }
                .sidebar-header {
                    font-size: 13px;
                    font-weight: 600;
                    color: #444746;
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    margin-bottom: 8px;
                }
                .tab-item {
                    font-size: 13px;
                    color: #1f1f1f;
                    padding: 6px 10px;
                    border-radius: 6px;
                    cursor: pointer;
                    display: flex;
                    align-items: center;
                    gap: 8px;
                }
                .tab-item:hover { background: #f1f3f4; }
                .tab-item.active { background: #c2e7ff; color: #001d35; font-weight: 500; }
                .sub-tab-item {
                    padding-left: 24px;
                    font-size: 12.5px;
                    color: #444746;
                }
                
                .canvas-scroll-area {
                    flex: 1;
                    overflow-y: auto;
                    display: flex;
                    justify-content: center;
                    padding: 32px 16px;
                    background: #f8fafd;
                }
                .document-page {
                    width: 816px;
                    min-height: 1056px;
                    background: #ffffff;
                    box-shadow: 0 1px 3px rgba(60,64,67,0.15), 0 2px 8px 1px rgba(60,64,67,0.08);
                    padding: 72px 84px;
                    outline: none;
                    cursor: text;
                    user-select: text;
                    line-height: 1.6;
                    color: #1f1f1f;
                }
                .page-title-banner {
                    font-family: 'Google Sans', Roboto, sans-serif;
                    font-size: 38px;
                    font-weight: 700;
                    color: #7c3aed;
                    margin-bottom: 12px;
                }
                .page-subtitle {
                    font-size: 16px;
                    color: #444746;
                    margin-bottom: 4px;
                }
                .page-class {
                    font-size: 14px;
                    color: #747775;
                    margin-bottom: 32px;
                }
                
                .save-indicator {
                    position: fixed;
                    bottom: 16px;
                    right: 20px;
                    background: #323232;
                    color: white;
                    font-size: 12px;
                    padding: 6px 14px;
                    border-radius: 16px;
                    opacity: 0;
                    transition: opacity 0.3s;
                    pointer-events: none;
                }
                .save-indicator.show { opacity: 1; }
            </style>
        </head>
        <body>
            <!-- Main Hub Header -->
            <div class="top-header" id="hubHeader">
                <div class="brand-group" onclick="showListView()">
                    <div class="menu-btn">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                            <path d="M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z"/>
                        </svg>
                    </div>
                    <div class="app-title">
                        \(iconSvg)
                        <span>\(appName)</span>
                    </div>
                </div>
                <div class="search-bar">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="#5f6368">
                        <path d="M15.5 14h-.79l-.28-.27A6.471 6.471 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/>
                    </svg>
                    <input type="text" class="search-input" id="searchInput" placeholder="Search \(appName)..." oninput="filterDocuments(this.value)">
                </div>
                <div class="header-actions">
                    <div class="offline-pill">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 15v-2h2v2h-2zm0-10v6h2V7h-2z"/>
                        </svg>
                        <span>Working offline</span>
                    </div>
                    <div class="avatar">\(String(userName.prefix(1)))</div>
                </div>
            </div>
            
            <!-- Document List View -->
            <div class="list-container" id="listView">
                <div class="section-header">
                    <div class="section-col-title">Recent documents</div>
                    <div class="section-col-owner">Owned by anyone</div>
                    <div class="section-col-date">Last opened by me</div>
                    <div class="section-col-actions"></div>
                </div>
                <div id="docListItems"></div>
            </div>
            
            <!-- Floating New Document Button -->
            <div class="new-doc-fab" onclick="createNewDoc()">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="#1a73e8">
                    <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/>
                </svg>
                <span>Blank document</span>
            </div>
            
            <!-- Document Editor View (Loaded when a document is opened) -->
            <div class="editor-container" id="editorView">
                <div class="editor-header">
                    <div class="editor-top-bar">
                        <div class="brand-group" onclick="showListView()">
                            \(iconSvg)
                        </div>
                        <div class="editor-doc-title" id="activeDocTitle" contenteditable="true" onblur="handleTitleChange(this.innerText)">
                            (NEW) Music tech book Y12
                        </div>
                        <div class="working-offline-badge">
                            <svg width="15" height="15" viewBox="0 0 24 24" fill="#5f6368">
                                <path d="M19.35 10.04C18.67 6.59 15.64 4 12 4c-1.48 0-2.85.43-4.01 1.17l1.46 1.46C10.21 6.23 11.08 6 12 6c3.04 0 5.5 2.46 5.5 5.5v.5H19c1.66 0 3 1.34 3 3 0 1.13-.64 2.11-1.56 2.62l1.45 1.45C23.16 18.16 24 16.68 24 15c0-2.64-2.05-4.78-4.65-4.96zM3 5.27l2.75 2.74C2.56 8.91 1 11.27 1 14c0 3.31 2.69 6 6 6h11.73l2 2 1.41-1.41L4.41 3.86 3 5.27zM7.53 9.8l8.67 8.67V18.5H7c-2.21 0-4-1.79-4-4 0-2.05 1.53-3.76 3.56-3.97l.97-.1v-.63z"/>
                            </svg>
                            <span>Working offline</span>
                        </div>
                        <div class="header-actions" style="margin-left: auto;">
                            <button class="toolbar-btn" style="background: #c2e7ff; color: #001d35; border-radius: 18px; padding: 6px 16px; font-weight: 600;" onclick="showListView()">
                                Close
                            </button>
                            <div class="avatar">\(String(userName.prefix(1)))</div>
                        </div>
                    </div>
                    <div class="menu-bar">
                        <span class="menu-item" onclick="saveToDisk()">File</span>
                        <span class="menu-item">Edit</span>
                        <span class="menu-item">View</span>
                        <span class="menu-item">Insert</span>
                        <span class="menu-item">Format</span>
                        <span class="menu-item">Tools</span>
                        <span class="menu-item">Help</span>
                    </div>
                </div>
                
                <div class="editor-toolbar">
                    <button class="toolbar-btn" onclick="document.execCommand('undo')">Undo</button>
                    <button class="toolbar-btn" onclick="document.execCommand('redo')">Redo</button>
                    <div class="toolbar-sep"></div>
                    <button class="toolbar-btn" onclick="window.print()">Print</button>
                    <div class="toolbar-sep"></div>
                    <button class="toolbar-btn" style="font-weight: 700;" onclick="document.execCommand('bold')">B</button>
                    <button class="toolbar-btn" style="font-style: italic;" onclick="document.execCommand('italic')">I</button>
                    <button class="toolbar-btn" style="text-decoration: underline;" onclick="document.execCommand('underline')">U</button>
                    <div class="toolbar-sep"></div>
                    <button class="toolbar-btn" onclick="document.execCommand('justifyLeft')">Left</button>
                    <button class="toolbar-btn" onclick="document.execCommand('justifyCenter')">Center</button>
                    <button class="toolbar-btn" onclick="document.execCommand('insertUnorderedList')">Bullet List</button>
                </div>
                
                <div class="editor-workspace">
                    <div class="doc-tabs-sidebar">
                        <div class="sidebar-header">
                            <span>Document tabs</span>
                            <span style="cursor: pointer; font-size: 16px;">+</span>
                        </div>
                        <div class="tab-item active">
                            <span>📄</span>
                            <span>Heading</span>
                        </div>
                        <div class="tab-item">
                            <span>📁</span>
                            <span>Music History</span>
                        </div>
                        <div class="tab-item sub-tab-item">Eras - Acoustic era</div>
                        <div class="tab-item sub-tab-item">Eras - Magnetic era</div>
                        <div class="tab-item sub-tab-item">Magnetic to digital shift</div>
                        <div class="tab-item">
                            <span>🎹</span>
                            <span>Audio Principles</span>
                        </div>
                        <div class="tab-item sub-tab-item">Wow & Flutter</div>
                        <div class="tab-item sub-tab-item">A/D conversion & digit...</div>
                        <div class="tab-item sub-tab-item">MIDI</div>
                        <div class="tab-item sub-tab-item">Reverse Reverb</div>
                    </div>
                    
                    <div class="canvas-scroll-area">
                        <div class="document-page" id="documentBody" contenteditable="true" oninput="scheduleAutoSave()">
                            <div class="page-title-banner">Music Technology</div>
                            <div class="page-subtitle">\(userName)</div>
                            <div class="page-class">Y12</div>
                            <p style="margin-top: 24px; color: #1f1f1f; font-size: 15px;">
                                Welcome to your offline workspace document. Changes made here are saved directly to your Mac and will automatically synchronize to Google Workspace when your internet connection is restored.
                            </p>
                        </div>
                    </div>
                </div>
            </div>
            
            <div class="save-indicator" id="saveIndicator">Saved to Workspace.mac</div>
            
            <script>
                const documents = \(docsJson);
                let currentDoc = null;
                let autoSaveTimer = null;
                
                function renderList(items) {
                    const container = document.getElementById('docListItems');
                    container.innerHTML = '';
                    
                    if (items.length === 0) {
                        container.innerHTML = '<div style="padding: 40px; text-align: center; color: #5f6368;">No local documents found. Click "Blank document" below to create one offline.</div>';
                        return;
                    }
                    
                    items.forEach(doc => {
                        const row = document.createElement('div');
                        row.className = 'doc-row';
                        row.onclick = () => openDoc(doc);
                        
                        row.innerHTML = `
                            <div class="doc-title-cell">
                                \(iconSvg)
                                <span>${doc.title}</span>
                            </div>
                            <div class="doc-owner-cell">me</div>
                            <div class="doc-date-cell">${doc.date}</div>
                            <div class="doc-action-cell">⋮</div>
                        `;
                        container.appendChild(row);
                    });
                }
                
                function filterDocuments(query) {
                    const q = query.toLowerCase().trim();
                    const filtered = documents.filter(d => d.title.toLowerCase().includes(q));
                    renderList(filtered);
                }
                
                function openDoc(doc) {
                    currentDoc = doc;
                    document.getElementById('hubHeader').style.display = 'none';
                    document.getElementById('listView').style.display = 'none';
                    document.querySelector('.new-doc-fab').style.display = 'none';
                    document.getElementById('editorView').style.display = 'flex';
                    
                    document.getElementById('activeDocTitle').innerText = doc.title;
                    
                    // Notify host of active document
                    try {
                        window.webkit.messageHandlers.smartDocumentTracker.postMessage({
                            action: 'documentOpened',
                            docId: doc.id,
                            title: doc.title,
                            type: doc.type
                        });
                    } catch(e) {}
                }
                
                function showListView() {
                    document.getElementById('editorView').style.display = 'none';
                    document.getElementById('hubHeader').style.display = 'flex';
                    document.getElementById('listView').style.display = 'flex';
                    document.querySelector('.new-doc-fab').style.display = 'flex';
                }
                
                function createNewDoc() {
                    const title = 'Untitled ' + ('\(appName)' === 'Docs' ? 'Document' : '\(appName)' === 'Sheets' ? 'Spreadsheet' : 'Presentation');
                    const newDoc = {
                        id: 'local_' + Date.now(),
                        title: title,
                        type: '\(appType)',
                        ext: '\(appType == "sheets" ? "xlsx" : (appType == "slides" ? "pptx" : "docx"))',
                        date: 'Just now',
                        isLocal: 'true'
                    };
                    documents.unshift(newDoc);
                    renderList(documents);
                    openDoc(newDoc);
                    
                    // Create on host disk
                    try {
                        window.webkit.messageHandlers.offlineDocumentSaver.postMessage({
                            action: 'create',
                            id: newDoc.id,
                            title: title,
                            content: 'Start typing here...'
                        });
                    } catch(e) {}
                }
                
                function handleTitleChange(newTitle) {
                    if (currentDoc && newTitle.trim()) {
                        currentDoc.title = newTitle.trim();
                        scheduleAutoSave();
                    }
                }
                
                function scheduleAutoSave() {
                    if (autoSaveTimer) clearTimeout(autoSaveTimer);
                    autoSaveTimer = setTimeout(saveToDisk, 1200);
                }
                
                function saveToDisk() {
                    const title = document.getElementById('activeDocTitle').innerText.trim() || 'Untitled';
                    const content = document.getElementById('documentBody').innerText;
                    
                    try {
                        window.webkit.messageHandlers.offlineDocumentSaver.postMessage({
                            action: 'save',
                            id: currentDoc ? currentDoc.id : 'temp',
                            title: title,
                            content: content
                        });
                    } catch(e) {}
                    
                    const ind = document.getElementById('saveIndicator');
                    ind.classList.add('show');
                    setTimeout(() => ind.classList.remove('show'), 2000);
                }
                
                // Initialize
                renderList(documents);
                
                // Auto-open specific document if requested
                const initId = '\(initialDocId)';
                if (initId) {
                    const target = documents.find(d => d.id === initId);
                    if (target) openDoc(target);
                }
            </script>
        </body>
        </html>
        """
    }
    
    private static func formattedDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
    
    // SVGs
    private static let docsIconSvg = """
    <svg class="icon-svg" viewBox="0 0 24 24" fill="#4285F4">
        <path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z"/>
    </svg>
    """
    
    private static let sheetsIconSvg = """
    <svg class="icon-svg" viewBox="0 0 24 24" fill="#0F9D58">
        <path d="M14 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V8l-6-6zm-1 9h3v2h-3v-2zm0 4h3v2h-3v-2zm-5-4h3v2H8v-2zm0 4h3v2H8v-2zm5-6V3.5L18.5 9H13z"/>
    </svg>
    """
    
    private static let slidesIconSvg = """
    <svg class="icon-svg" viewBox="0 0 24 24" fill="#F4B400">
        <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H5V5h14v14zM8 7h8v2H8zm0 4h8v2H8zm0 4h5v2H8z"/>
    </svg>
    """
    
    private static let driveIconSvg = """
    <svg class="icon-svg" viewBox="0 0 24 24" fill="#4285F4">
        <path d="M7.71 3.5L1.15 15l3.43 6 6.55-11.5M9.73 15L6.3 21h13.12l3.43-6M22.85 15l-6.57-11.5H9.72l6.56 11.5"/>
    </svg>
    """
}
