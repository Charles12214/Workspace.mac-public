import SwiftUI
import AppKit

public struct OfflineDocumentHubView: View {
    public let app: WorkspaceAppItem
    public let onRetry: () -> Void
    
    @ObservedObject public var offlineManager = OfflineManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var isRetrying: Bool = false
    @State private var hoveredDocId: String? = nil
    
    public init(app: WorkspaceAppItem, onRetry: @escaping () -> Void) {
        self.app = app
        self.onRetry = onRetry
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 24) {
                // Header Banner
                offlineBannerHeader
                
                // Primary Quick Actions Grid
                quickActionsRow
                
                // Local Documents Section
                localDocumentsSection
                
                Spacer(minLength: 32)
            }
            .padding(28)
            .frame(maxWidth: 880)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $offlineManager.showingLocalEditor) {
            LocalDocumentEditorView(documentUrl: offlineManager.editingDocumentURL)
        }
        .onAppear {
            offlineManager.scanLocalDocuments()
        }
    }
    
    // MARK: - Offline Banner Header
    private var offlineBannerHeader: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                // Glowing Wi-Fi Disconnected Emblem
                ZStack {
                    Circle()
                        .fill(Color(hex: "F59E0B").opacity(0.16))
                        .frame(width: 58, height: 58)
                    
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color(hex: "F59E0B"))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("You're Currently Offline")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Text(offlineManager.connectionType)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.primary.opacity(0.06)))
                    }
                    
                    Text("\(app.name) cannot reach Google's servers right now. You can create, view, and edit local files offline, and your changes will sync when reconnected.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Retry Button
                Button(action: {
                    isRetrying = true
                    onRetry()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        isRetrying = false
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .rotationEffect(.degrees(isRetrying ? 360 : 0))
                            .animation(isRetrying ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRetrying)
                        
                        Text(isRetrying ? "Checking..." : "Retry Connection")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(hex: "1A73E8")))
                    .shadow(color: Color(hex: "1A73E8").opacity(0.35), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(isRetrying)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "F59E0B").opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(hex: "F59E0B").opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Quick Actions Row
    private var quickActionsRow: some View {
        HStack(spacing: 14) {
            // Action 1: Create New Document
            Button(action: {
                offlineManager.launchLocalEditor(for: nil)
            }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "1A73E8").opacity(0.12))
                            .frame(width: 42, height: 42)
                        Image(systemName: "plus.doc.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(hex: "1A73E8"))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Offline Document")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("Open the built-in rich text editor")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Action 2: Open File from Mac
            Button(action: {
                openLocalFileWithPanel()
            }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "34A853").opacity(0.12))
                            .frame(width: 42, height: 42)
                        Image(systemName: "folder.badge.gearshape")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(hex: "34A853"))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open Local File...")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("Browse .docx, .xlsx, .pdf on Mac")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Local Documents Section
    private var localDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "1A73E8"))
                    
                    Text("Workspace Local Documents")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Button(action: {
                    offlineManager.openInFinder()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 11))
                        Text("Show in Finder")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.primary.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .help("Open ~/Documents/Workspace.mac/ in Finder")
            }
            
            if offlineManager.localDocuments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                        .padding(.top, 16)
                    
                    Text("No local documents saved yet")
                        .font(.system(size: 13, weight: .semibold))
                    
                    Text("Click 'New Offline Document' to write notes or create documents without internet.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(offlineManager.localDocuments) { doc in
                        localDocumentRow(doc)
                    }
                }
            }
        }
    }
    
    private func localDocumentRow(_ doc: LocalWorkspaceDocument) -> some View {
        HStack(spacing: 14) {
            Image(systemName: doc.iconSymbol)
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: "1A73E8"))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(doc.fileExtension.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(doc.fileSizeFormatted)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(doc.modificationDate, style: .date)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Action button
            Button(action: {
                openDocument(doc)
            }) {
                HStack(spacing: 4) {
                    Text(doc.isRichDocument ? "Edit" : "Open")
                        .font(.system(size: 11.5, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hoveredDocId == doc.id ? Color.primary.opacity(0.06) : Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(hoveredDocId == doc.id ? Color(hex: "1A73E8").opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onHover { h in
            hoveredDocId = h ? doc.id : nil
        }
        .onTapGesture(count: 2) {
            openDocument(doc)
        }
        .contextMenu {
            Button("Open in Workspace Local Editor") {
                offlineManager.launchLocalEditor(for: doc.url)
            }
            Button("Open in Default macOS App") {
                offlineManager.openDocumentExternally(url: doc.url)
            }
            Button("Reveal in Finder") {
                offlineManager.openInFinder(url: doc.url)
            }
            Divider()
            Button(role: .destructive, action: {
                try? FileManager.default.trashItem(at: doc.url, resultingItemURL: nil)
                offlineManager.scanLocalDocuments()
            }) {
                Label("Move to Trash", systemImage: "trash")
            }
        }
    }
    
    private func openDocument(_ doc: LocalWorkspaceDocument) {
        if doc.isRichDocument {
            offlineManager.launchLocalEditor(for: doc.url)
        } else {
            offlineManager.openDocumentExternally(url: doc.url)
        }
    }
    
    private func openLocalFileWithPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.text, .plainText, .rtf, .pdf, .data]
        if panel.runModal() == .OK, let url = panel.url {
            if ["rtf", "txt", "docx", "doc"].contains(url.pathExtension.lowercased()) {
                offlineManager.launchLocalEditor(for: url)
            } else {
                offlineManager.openDocumentExternally(url: url)
            }
        }
    }
}
