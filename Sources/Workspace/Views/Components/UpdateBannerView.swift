import SwiftUI
import AppKit

public struct UpdateBannerView: View {
    public let update: AppUpdateInfo
    public var onDismiss: () -> Void
    
    public init(update: AppUpdateInfo, onDismiss: @escaping () -> Void) {
        self.update = update
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Yellow / Amber update indicator
            ZStack {
                Circle()
                    .fill(Color(hex: "F59E0B").opacity(0.2))
                    .frame(width: 26, height: 26)
                
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "D97706"))
            }
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Workspace.mac \(update.versionName) is available!")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text("New Update")
                        .font(.system(size: 9.5, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "F59E0B").opacity(0.18))
                        .foregroundStyle(Color(hex: "B45309"))
                        .clipShape(Capsule())
                }
                
                Text("Get the latest features, performance improvements, and fixes.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Download button
            Button(action: {
                NSWorkspace.shared.open(update.releaseUrl)
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 10.5, weight: .bold))
                    Text("Download")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color(hex: "D97706"))
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Dismiss update notification")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "F59E0B").opacity(0.55), lineWidth: 1.2)
        )
        .shadow(color: Color(hex: "F59E0B").opacity(0.18), radius: 10, y: 4)
        .shadow(color: Color.black.opacity(0.15), radius: 6, y: 2)
        .frame(maxWidth: 620)
    }
}
