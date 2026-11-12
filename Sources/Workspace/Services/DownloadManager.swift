import Foundation
import WebKit
import AppKit
import SwiftUI
import PDFKit

public struct DownloadItemInfo: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var filename: String
    public var progress: Double // 0.0 to 1.0
    public var isIndeterminate: Bool
    public var destinationURL: URL?
    public var isCompleted: Bool
    public var errorMessage: String?
    
    public init(
        id: UUID = UUID(),
        filename: String,
        progress: Double = 0.0,
        isIndeterminate: Bool = true,
        destinationURL: URL? = nil,
        isCompleted: Bool = false,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.progress = progress
        self.isIndeterminate = isIndeterminate
        self.destinationURL = destinationURL
        self.isCompleted = isCompleted
        self.errorMessage = errorMessage
    }
}

@MainActor
public final class DownloadManager: ObservableObject {
    public static let shared = DownloadManager()
    
    @Published public var activeDownload: DownloadItemInfo? = nil
    @Published public var completedDownload: DownloadItemInfo? = nil
    
    private var progressObservations: [ObjectIdentifier: NSKeyValueObservation] = [:]
    private var activeWKDownloads: [ObjectIdentifier: WKDownload] = [:]
    private var dismissTimer: DispatchWorkItem? = nil
    
    private init() {}
    
    public func registerDownload(_ download: WKDownload) {
        let key = ObjectIdentifier(download)
        activeWKDownloads[key] = download
        
        let initialName = "Downloading file..."
        let item = DownloadItemInfo(
            filename: initialName,
            progress: download.progress.fractionCompleted,
            isIndeterminate: download.progress.isIndeterminate
        )
        self.activeDownload = item
        self.completedDownload = nil
        self.dismissTimer?.cancel()
        
        let targetId = item.id
        let observation = download.progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] progress, _ in
            let fraction = progress.fractionCompleted
            let isIndet = progress.isIndeterminate
            Task { @MainActor [weak self] in
                guard let self = self, self.activeDownload?.id == targetId else { return }
                self.activeDownload?.progress = fraction
                self.activeDownload?.isIndeterminate = isIndet
            }
        }
        progressObservations[key] = observation
    }
    
    public func setDestination(for download: WKDownload, destinationURL: URL, suggestedFilename: String) {
        if var current = activeDownload {
            current.filename = suggestedFilename
            current.destinationURL = destinationURL
            self.activeDownload = current
        } else {
            let item = DownloadItemInfo(
                filename: suggestedFilename,
                progress: download.progress.fractionCompleted,
                isIndeterminate: download.progress.isIndeterminate,
                destinationURL: destinationURL
            )
            self.activeDownload = item
        }
    }
    
    public func finishDownload(download: WKDownload) {
        let key = ObjectIdentifier(download)
        progressObservations[key]?.invalidate()
        progressObservations.removeValue(forKey: key)
        activeWKDownloads.removeValue(forKey: key)
        
        if var item = activeDownload {
            item.isCompleted = true
            item.progress = 1.0
            item.isIndeterminate = false
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                self.activeDownload = nil
                self.completedDownload = item
            }
            
            // Auto dismiss after 6 seconds
            dismissTimer?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self?.completedDownload = nil
                }
            }
            self.dismissTimer = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: workItem)
        }
    }
    
    public func failDownload(download: WKDownload, error: Error) {
        let key = ObjectIdentifier(download)
        progressObservations[key]?.invalidate()
        progressObservations.removeValue(forKey: key)
        activeWKDownloads.removeValue(forKey: key)
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.activeDownload = nil
            self.completedDownload = nil
        }
    }
    
    public func cancelActiveDownload() {
        for (_, download) in activeWKDownloads {
            download.cancel()
        }
        activeWKDownloads.removeAll()
        progressObservations.values.forEach { $0.invalidate() }
        progressObservations.removeAll()
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.activeDownload = nil
        }
    }
    
    public func dismissCompleted() {
        dismissTimer?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.completedDownload = nil
        }
    }
    
    public func showInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    // MARK: - Native Printing for Downloaded Documents (e.g. Google Docs PDF exports)
    public func printFile(at url: URL) {
        if let pdfDoc = PDFDocument(url: url) {
            let printInfo = NSPrintInfo.shared
            printInfo.isHorizontallyCentered = true
            printInfo.isVerticallyCentered = true
            if let op = pdfDoc.printOperation(for: printInfo, scalingMode: .pageScaleToFit, autoRotate: true) {
                op.showsPrintPanel = true
                op.showsProgressPanel = true
                if let window = NSApp.keyWindow ?? NSApp.windows.first {
                    op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
                } else {
                    op.run()
                }
                return
            }
        }
        
        // Fallback for non-PDF files: reveal or open
        NSWorkspace.shared.open(url)
    }
}
