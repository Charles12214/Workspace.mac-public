import SwiftUI
import AppKit

// MARK: - Download HUD & "Downloaded to [file location]" Popup
public struct DownloadHUDView: View {
    @ObservedObject private var manager = DownloadManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack {
            if let active = manager.activeDownload {
                downloadingPill(active)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            } else if let completed = manager.completedDownload {
                completedPopup(completed)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .padding(.top, 14)
        .padding(.horizontal, 20)
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: manager.activeDownload)
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: manager.completedDownload)
    }
    
    // MARK: - 1. Active Downloading Progress Pill
    private func downloadingPill(_ item: DownloadItemInfo) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "1A73E8").opacity(0.18))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: "1A73E8"))
            }
            
            // Text & Progress Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.filename)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer(minLength: 4)
                    
                    if !item.isIndeterminate && item.progress > 0 {
                        Text("\(Int(item.progress * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "1A73E8"))
                    } else {
                        Text("Downloading...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Progress Bar
                if !item.isIndeterminate && item.progress > 0 {
                    ProgressView(value: max(0.02, min(item.progress, 1.0)), total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(Color(hex: "1A73E8"))
                        .frame(height: 4)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(Color(hex: "1A73E8"))
                        .frame(height: 4)
                }
            }
            .frame(width: 240)
            
            // Cancel button
            Button(action: {
                manager.cancelActiveDownload()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Cancel download")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 14, y: 5)
    }
    
    // MARK: - 2. "Downloaded to [file location]" Popup
    private func completedPopup(_ item: DownloadItemInfo) -> some View {
        let folderName: String = {
            if let dest = item.destinationURL {
                return dest.deletingLastPathComponent().lastPathComponent
            }
            return "Downloads"
        }()
        
        let pathDisplay: String = {
            if let dest = item.destinationURL {
                let path = dest.path
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                if path.hasPrefix(home) {
                    return "~" + path.dropFirst(home.count)
                }
                return path
            }
            return "~/Downloads/\(item.filename)"
        }()
        
        return HStack(spacing: 12) {
            // Emerald Success Badge
            ZStack {
                Circle()
                    .fill(Color(hex: "34A853").opacity(0.18))
                    .frame(width: 34, height: 34)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "34A853"))
            }
            
            // Labels
            VStack(alignment: .leading, spacing: 2) {
                Text("Downloaded to \(folderName)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text(pathDisplay)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 280, alignment: .leading)
            }
            
            Spacer(minLength: 8)
            
            // Action buttons: Print & Show in Finder
            if let url = item.destinationURL {
                if url.pathExtension.lowercased() == "pdf" {
                    Button(action: {
                        manager.printFile(at: url)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "printer.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Print...")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: "1A73E8"))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Print document natively without opening Preview")
                }
                
                Button(action: {
                    manager.showInFinder(url: url)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "folder")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Show in Finder")
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.08))
                    .foregroundStyle(.primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Reveal downloaded file in Finder")
            }
            
            // Dismiss button
            Button(action: {
                manager.dismissCompleted()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(5)
            }
            .buttonStyle(.plain)
            .help("Dismiss notification")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "34A853").opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.24), radius: 14, y: 5)
    }
}
