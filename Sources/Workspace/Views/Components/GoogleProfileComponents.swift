import SwiftUI
import AppKit

// MARK: - Official AI Tier Gradient Ring & Badge Palette
public struct GoogleAiDesign {
    // Lavender to Electric Blue gradient ring as sampled from user reference
    public static let ringGradient = AngularGradient(
        gradient: Gradient(colors: [
            Color(hex: "00A4F9"), // Electric Blue (left/bottom)
            Color(hex: "3B82F6"), // Royal Blue
            Color(hex: "8B5CF6"), // Violet
            Color(hex: "C4B5FD"), // Lavender / Soft Purple (top/top-right)
            Color(hex: "818CF8"), // Indigo
            Color(hex: "3B82F6"), // Royal Blue
            Color(hex: "00A4F9")  // Electric Blue
        ]),
        center: .center,
        startAngle: .degrees(60),
        endAngle: .degrees(420)
    )
    
    public static let pillBorderGradient = LinearGradient(
        colors: [
            Color(hex: "A78BFA").opacity(0.85),
            Color(hex: "60A5FA").opacity(0.75)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Profile Avatar with Purple/Blue Gradient Ring & Edit Pencil Button
public struct GoogleProfileAvatarView: View {
    public let avatarData: Data?
    public let name: String
    public let size: CGFloat
    public let tier: SubscriptionTier
    public let showEditButton: Bool
    public let action: (() -> Void)?
    
    public init(
        avatarData: Data?,
        name: String,
        size: CGFloat = 40,
        tier: SubscriptionTier = .aiPro,
        showEditButton: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.avatarData = avatarData
        self.name = name
        self.size = size
        self.tier = tier
        self.showEditButton = showEditButton
        self.action = action
    }
    
    public var body: some View {
        Button(action: { action?() }) {
            ZStack(alignment: .bottomTrailing) {
                // Main Avatar Circle with Clean Border
                ZStack {
                    // Inner profile image, initial, or standard PFP icon
                    Group {
                        if let data = avatarData,
                           let nsImg = NSImage(data: data) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            ZStack {
                                // Simple, clean dark grey circle
                                Circle()
                                    .fill(Color(hex: "374151"))
                                
                                let cleanName = name.trimmingCharacters(in: .whitespaces)
                                if !cleanName.isEmpty && cleanName != "Workspace User" {
                                    // Start with the first letter of the first name
                                    Text(String(cleanName.prefix(1)).uppercased())
                                        .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                } else {
                                    // Standard PFP icon
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundStyle(.white.opacity(0.85))
                                        .padding(size * 0.22)
                                }
                            }
                        }
                    }
                    .frame(width: size - 2, height: size - 2)
                    .clipShape(Circle())
                    
                    // Simple, clean subtle border
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1.0)
                        .frame(width: size, height: size)
                }
                .frame(width: size, height: size)
                
                // Edit Pencil Button in bottom-right corner (as in reference image)
                if showEditButton {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "1F2328"))
                            .frame(width: size * 0.36, height: size * 0.36)
                        
                        Circle()
                            .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5)
                            .frame(width: size * 0.36, height: size * 0.36)
                        
                        Image(systemName: "pencil")
                            .font(.system(size: size * 0.18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: size * 0.04, y: size * 0.04)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI Plus / Pro / Ultra Pill Badge
public struct AiTierBadgeView: View {
    public let tier: SubscriptionTier
    
    public init(tier: SubscriptionTier) {
        self.tier = tier
    }
    
    public var body: some View {
        if tier.isAiTier {
            // Authentic AI Plus / Pro / Ultra glowing pill as in reference
            Text(tier.badgeLabel)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 3.5)
                .background(
                    ZStack {
                        // Ambient soft purple & blue backglow
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "3B82F6").opacity(0.7), Color(hex: "8B5CF6").opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .blur(radius: 5)
                            .padding(-1)
                        
                        // Deep dark navy / black container
                        Capsule()
                            .fill(Color(hex: "0D111A"))
                    }
                )
                .overlay(
                    Capsule()
                        .stroke(GoogleAiDesign.pillBorderGradient, lineWidth: 1.0)
                )
        } else {
            // Enterprise / Business / Free
            Text(tier.badgeLabel)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: tier.badgeGradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        }
    }
}

// MARK: - Crisp Vector Google "G" Logo
public struct GoogleGLogo: View {
    public var size: CGFloat = 20
    
    public init(size: CGFloat = 20) {
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            if let img = loadLocalGLogo() {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                fallbackVectorG
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
    }
    
    private func loadLocalGLogo() -> NSImage? {
        let paths = [
            "Resources/Images/google_g_logo.png",
            "Workspace.app/Contents/Resources/Images/google_g_logo.png"
        ]
        for p in paths {
            if FileManager.default.fileExists(atPath: p),
               let img = NSImage(contentsOfFile: p) {
                return img
            }
        }
        if let resUrl = Bundle.main.url(forResource: "google_g_logo", withExtension: "png", subdirectory: "Images"),
           let img = NSImage(contentsOf: resUrl) {
            return img
        }
        return nil
    }
    
    private var fallbackVectorG: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            let cx = w / 2
            let cy = h / 2
            let r = min(w, h) * 0.44
            let innerR = r * 0.54
            let center = CGPoint(x: cx, y: cy)
            
            // Colors
            let cBlue = Color(hex: "4285F4")
            let cRed = Color(hex: "EA4335")
            let cYellow = Color(hex: "FBBC05")
            let cGreen = Color(hex: "34A853")
            
            // Red top
            var redPath = Path()
            redPath.addArc(center: center, radius: r, startAngle: .degrees(220), endAngle: .degrees(320), clockwise: false)
            redPath.addArc(center: center, radius: innerR, startAngle: .degrees(320), endAngle: .degrees(220), clockwise: true)
            redPath.closeSubpath()
            context.fill(redPath, with: .color(cRed))
            
            // Yellow left
            var yelPath = Path()
            yelPath.addArc(center: center, radius: r, startAngle: .degrees(140), endAngle: .degrees(220), clockwise: false)
            yelPath.addArc(center: center, radius: innerR, startAngle: .degrees(220), endAngle: .degrees(140), clockwise: true)
            yelPath.closeSubpath()
            context.fill(yelPath, with: .color(cYellow))
            
            // Green bottom
            var grnPath = Path()
            grnPath.addArc(center: center, radius: r, startAngle: .degrees(40), endAngle: .degrees(140), clockwise: false)
            grnPath.addArc(center: center, radius: innerR, startAngle: .degrees(140), endAngle: .degrees(40), clockwise: true)
            grnPath.closeSubpath()
            context.fill(grnPath, with: .color(cGreen))
            
            // Blue right + bar
            var bluPath = Path()
            bluPath.addArc(center: center, radius: r, startAngle: .degrees(320), endAngle: .degrees(365), clockwise: false)
            bluPath.addLine(to: CGPoint(x: cx, y: cy + r * 0.2))
            bluPath.addLine(to: CGPoint(x: cx, y: cy - r * 0.2))
            bluPath.addLine(to: CGPoint(x: cx + r, y: cy - r * 0.2))
            bluPath.closeSubpath()
            context.fill(bluPath, with: .color(cBlue))
        }
    }
}
