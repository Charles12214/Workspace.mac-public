import SwiftUI
import AppKit

// MARK: - Native Rich Text View for macOS
public struct NativeRichTextEditor: NSViewRepresentable {
    @Binding public var attributedText: NSAttributedString
    public let isEditable: Bool
    public var onTextChange: ((NSAttributedString) -> Void)?
    
    public init(
        attributedText: Binding<NSAttributedString>,
        isEditable: Bool = true,
        onTextChange: ((NSAttributedString) -> Void)? = nil
    ) {
        self._attributedText = attributedText
        self.isEditable = isEditable
        self.onTextChange = onTextChange
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        
        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        
        let textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: 15)
        textView.textContainerInset = NSSize(width: 32, height: 32)
        
        textView.textStorage?.setAttributedString(attributedText)
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }
    
    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if !context.coordinator.isUpdating && textView.attributedString() != attributedText {
            context.coordinator.isUpdating = true
            textView.textStorage?.setAttributedString(attributedText)
            context.coordinator.isUpdating = false
        }
    }
    
    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeRichTextEditor
        weak var textView: NSTextView?
        var isUpdating = false
        
        init(_ parent: NativeRichTextEditor) {
            self.parent = parent
        }
        
        public func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = notification.object as? NSTextView else { return }
            isUpdating = true
            let current = textView.attributedString()
            parent.attributedText = current
            parent.onTextChange?(current)
            isUpdating = false
        }
    }
}

// MARK: - Built-in Local Document Editor View (Docs/Word Style)
public struct LocalDocumentEditorView: View {
    @ObservedObject public var offlineManager = OfflineManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var documentTitle: String = "Untitled Document"
    @State private var attributedContent: NSAttributedString = NSAttributedString(string: "")
    @State private var fileUrl: URL? = nil
    @State private var isSaved: Bool = true
    @State private var lastSavedTime: String = "All changes saved locally"
    @State private var showingSyncAlert: Bool = false
    
    public init(documentUrl: URL? = nil) {
        self._fileUrl = State(initialValue: documentUrl)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Editor Header Bar
            editorHeaderBar
            
            Divider().opacity(0.2)
            
            // MARK: - Word / Docs Formatting Toolbar
            editorToolbar
            
            Divider().opacity(0.2)
            
            // MARK: - Document Canvas (Centered Sheet with Realistic Paper Shadow)
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    Spacer(minLength: 24)
                    
                    // Paper Sheet
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(colorScheme == .dark ? Color(hex: "1E1F20") : Color.white)
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.12), radius: 16, x: 0, y: 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        
                        NativeRichTextEditor(attributedText: $attributedContent, isEditable: true) { _ in
                            isSaved = false
                            lastSavedTime = "Unsaved changes"
                        }
                        .frame(minHeight: 820)
                    }
                    .frame(maxWidth: 820)
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                }
                .frame(maxWidth: .infinity)
            }
            .background(
                colorScheme == .dark ? Color(hex: "121314") : Color(hex: "F0F4F9")
            )
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            loadInitialContent()
        }
        .alert("Sync to Google Drive", isPresented: $showingSyncAlert) {
            Button("Open Google Drive") {
                if let app = AppState.shared.apps.first(where: { $0.id == "drive" }) {
                    AppState.shared.launchApp(app)
                    offlineManager.showingLocalEditor = false
                }
            }
            Button("Reveal in Finder") {
                offlineManager.openInFinder(url: fileUrl)
            }
            Button("Done", role: .cancel) {}
        } message: {
            Text("Your offline document is saved locally at \(fileUrl?.path ?? "~/Documents/Workspace.mac/"). You can upload it or drag & drop it directly into Google Drive now that you are connected.")
        }
    }
    
    // MARK: - Editor Header Bar
    private var editorHeaderBar: some View {
        HStack(spacing: 12) {
            // Close / Back button
            Button(action: {
                saveDocument()
                offlineManager.showingLocalEditor = false
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                    Text("Close")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            
            // Document Icon & Title
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "1A73E8"))
                
                TextField("Document Title", text: $documentTitle, onCommit: {
                    renameDocument()
                })
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .frame(minWidth: 160, maxWidth: 320)
            }
            
            // Save Status Pill
            HStack(spacing: 5) {
                Image(systemName: isSaved ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 10))
                    .foregroundStyle(isSaved ? Color(hex: "34A853") : Color(hex: "F59E0B"))
                
                Text(lastSavedTime)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.primary.opacity(0.04)))
            
            Spacer()
            
            // Reconnect / Sync Indicator
            if !offlineManager.isOffline {
                Button(action: { showingSyncAlert = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .font(.system(size: 12))
                        Text("Sync to Drive")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: "1A73E8")))
                }
                .buttonStyle(.plain)
                .help("Upload document to Google Drive")
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 10, weight: .bold))
                    Text("Offline Mode")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color(hex: "F59E0B"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(hex: "F59E0B").opacity(0.12)))
            }
            
            // Save Button
            Button(action: { saveDocument() }) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 13, weight: .medium))
                    .padding(6)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("s", modifiers: [.command])
            .help("Save Document (⌘S)")
            
            // Print / Export
            Button(action: { printDocument() }) {
                Image(systemName: "printer")
                    .font(.system(size: 13, weight: .medium))
                    .padding(6)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("p", modifiers: [.command])
            .help("Print or Export to PDF (⌘P)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Word / Docs Formatting Toolbar
    private var editorToolbar: some View {
        HStack(spacing: 14) {
            // Text Formatting Cluster
            HStack(spacing: 4) {
                toolbarButton(icon: "bold", help: "Bold (⌘B)") {
                    applyFormatting(trait: .boldFontMask)
                }
                toolbarButton(icon: "italic", help: "Italic (⌘I)") {
                    applyFormatting(trait: .italicFontMask)
                }
                toolbarButton(icon: "underline", help: "Underline (⌘U)") {
                    applyUnderline()
                }
            }
            
            Divider().frame(height: 16).opacity(0.3)
            
            // Alignment Cluster
            HStack(spacing: 4) {
                toolbarButton(icon: "text.alignleft", help: "Align Left") {
                    applyAlignment(.left)
                }
                toolbarButton(icon: "text.aligncenter", help: "Align Center") {
                    applyAlignment(.center)
                }
                toolbarButton(icon: "text.alignright", help: "Align Right") {
                    applyAlignment(.right)
                }
            }
            
            Divider().frame(height: 16).opacity(0.3)
            
            // Lists & Indents
            HStack(spacing: 4) {
                toolbarButton(icon: "list.bullet", help: "Bulleted List") {
                    insertBullet()
                }
            }
            
            Spacer()
            
            Text("Workspace.mac Local Editor")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.02))
    }
    
    private func toolbarButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.primary)
                .frame(width: 26, height: 24)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.05)))
        }
        .buttonStyle(.plain)
        .help(help)
    }
    
    // MARK: - Document Actions
    private func loadInitialContent() {
        if let url = fileUrl, let data = try? Data(contentsOf: url) {
            self.documentTitle = url.deletingPathExtension().lastPathComponent
            if let attr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                self.attributedContent = attr
            } else if let text = String(data: data, encoding: .utf8) {
                self.attributedContent = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 15)])
            }
        } else {
            self.documentTitle = "Untitled Document"
            self.attributedContent = NSAttributedString(string: "Start typing your offline document here...\n\nWorkspace.mac automatically saves your work locally.", attributes: [
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: NSColor.textColor
            ])
            saveDocument()
        }
    }
    
    private func saveDocument() {
        let folder = offlineManager.localDocumentsDirectory
        
        let targetUrl: URL
        if let current = fileUrl {
            targetUrl = current
        } else {
            targetUrl = folder.appendingPathComponent("\(documentTitle).rtf")
            fileUrl = targetUrl
        }
        
        if let rtfData = try? attributedContent.data(from: NSRange(location: 0, length: attributedContent.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            try? rtfData.write(to: targetUrl)
            offlineManager.scanLocalDocuments()
            isSaved = true
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            lastSavedTime = "Saved at \(formatter.string(from: Date()))"
        }
    }
    
    private func renameDocument() {
        guard let oldUrl = fileUrl else { return }
        let newUrl = oldUrl.deletingLastPathComponent().appendingPathComponent("\(documentTitle).rtf")
        if newUrl != oldUrl {
            try? FileManager.default.moveItem(at: oldUrl, to: newUrl)
            fileUrl = newUrl
            offlineManager.scanLocalDocuments()
            saveDocument()
        }
    }
    
    private func printDocument() {
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 800))
        textView.textStorage?.setAttributedString(attributedContent)
        
        let printOp = NSPrintOperation(view: textView, printInfo: printInfo)
        printOp.run()
    }
    
    private func applyFormatting(trait: NSFontTraitMask) {
        let mutable = NSMutableAttributedString(attributedString: attributedContent)
        let fontManager = NSFontManager.shared
        
        mutable.enumerateAttribute(.font, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, _ in
            let font = (value as? NSFont) ?? NSFont.systemFont(ofSize: 15)
            let newFont = fontManager.convert(font, toHaveTrait: trait)
            mutable.addAttribute(.font, value: newFont, range: range)
        }
        self.attributedContent = mutable
        saveDocument()
    }
    
    private func applyUnderline() {
        let mutable = NSMutableAttributedString(attributedString: attributedContent)
        mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: mutable.length))
        self.attributedContent = mutable
        saveDocument()
    }
    
    private func applyAlignment(_ alignment: NSTextAlignment) {
        let mutable = NSMutableAttributedString(attributedString: attributedContent)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        mutable.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: mutable.length))
        self.attributedContent = mutable
        saveDocument()
    }
    
    private func insertBullet() {
        let bullet = NSAttributedString(string: "\n• ", attributes: [.font: NSFont.systemFont(ofSize: 15)])
        let mutable = NSMutableAttributedString(attributedString: attributedContent)
        mutable.append(bullet)
        self.attributedContent = mutable
        saveDocument()
    }
}
