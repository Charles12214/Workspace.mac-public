import SwiftUI
import Foundation

// MARK: - App Category
public enum AppCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case all = "All Apps"
    case intelligence = "AI & Research"
    case productivity = "Productivity"
    case communication = "Communication"
    case notesAndTasks = "Notes & Tasks"
    case storageAndAdmin = "Storage & Admin"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .intelligence: return "sparkles"
        case .productivity: return "doc.text.fill"
        case .communication: return "bubble.left.and.bubble.right.fill"
        case .notesAndTasks: return "checklist"
        case .storageAndAdmin: return "externaldrive.fill"
        }
    }
}

// MARK: - Workspace App Item
public struct WorkspaceAppItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let category: AppCategory
    public let appDescription: String
    public let urlString: String
    public let newDocUrlString: String?
    public let iconSymbol: String
    public let colorHex: String
    public let secondaryColorHex: String
    public var isPinned: Bool
    public var lastUsed: Date?
    public var launchCount: Int
    
    public var url: URL {
        URL(string: urlString) ?? URL(string: "https://workspace.google.com")!
    }
    
    public func resolvedUrl(for email: String = "") -> URL {
        return url
    }
    
    public var newDocUrl: URL? {
        guard let s = newDocUrlString else { return nil }
        return URL(string: s)
    }
    
    public var primaryColor: Color {
        Color(hex: colorHex)
    }
    
    public var secondaryColor: Color {
        Color(hex: secondaryColorHex)
    }
    
    public init(
        id: String,
        name: String,
        category: AppCategory,
        appDescription: String,
        urlString: String,
        newDocUrlString: String? = nil,
        iconSymbol: String,
        colorHex: String,
        secondaryColorHex: String,
        isPinned: Bool = false,
        lastUsed: Date? = nil,
        launchCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.appDescription = appDescription
        self.urlString = urlString
        self.newDocUrlString = newDocUrlString
        self.iconSymbol = iconSymbol
        self.colorHex = colorHex
        self.secondaryColorHex = secondaryColorHex
        self.isPinned = isPinned
        self.lastUsed = lastUsed
        self.launchCount = launchCount
    }
}

// MARK: - Subscription Tier
public enum SubscriptionTier: String, CaseIterable, Codable, Identifiable, Sendable {
    case aiPlus = "Google AI Plus"
    case aiPro = "Google AI Pro"
    case aiUltra = "Google AI Ultra"
    case workspaceEnterprise = "Workspace Enterprise"
    case workspaceBusiness = "Workspace Business"
    case standard = "Personal (Free)"
    
    public var id: String { rawValue }
    
    public var isAiTier: Bool {
        switch self {
        case .aiPlus, .aiPro, .aiUltra: return true
        default: return false
        }
    }
    
    public var badgeLabel: String {
        switch self {
        case .aiPlus: return "Plus"
        case .aiPro: return "Pro"
        case .aiUltra: return "Ultra"
        case .workspaceEnterprise: return "Enterprise"
        case .workspaceBusiness: return "Business"
        case .standard: return "Free"
        }
    }
    
    public var badgeGradient: [Color] {
        switch self {
        case .aiPlus:
            return [Color(hex: "8B5CF6"), Color(hex: "3B82F6")]
        case .aiPro:
            return [Color(hex: "8B5CF6"), Color(hex: "00A4F9")]
        case .aiUltra:
            return [Color(hex: "C4B5FD"), Color(hex: "8B5CF6"), Color(hex: "00A4F9")]
        case .workspaceEnterprise:
            return [Color(hex: "1A73E8"), Color(hex: "0D47A1")]
        case .workspaceBusiness:
            return [Color(hex: "34A853"), Color(hex: "0F9D58")]
        case .standard:
            return [Color(hex: "5F6368"), Color(hex: "80868B")]
        }
    }
    
    public func summaryText(name: String) -> String {
        switch self {
        case .aiPlus:
            return "\(name), you have Google AI Plus! Enjoy enhanced Gemini integration across Workspace."
        case .aiPro:
            return "\(name), you have Google AI Pro! Full Gemini Workspace integration enabled."
        case .aiUltra:
            return "\(name), you have Google AI Ultra! The most capable Gemini models unlocked across Workspace."
        case .workspaceEnterprise:
            return "\(name), you have Workspace Enterprise! Complete enterprise tools unlocked."
        case .workspaceBusiness:
            return "\(name), you have Workspace Business! Professional team collaboration ready."
        case .standard:
            return "\(name), your standard Google account is ready!"
        }
    }
}

// MARK: - App Viewing Layout Mode
public enum AppViewMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case everything = "Everything"
    case essentials = "Essentials"
    case minimalist = "Minimalist"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .everything: return "Sidebar and top bar visible"
        case .essentials: return "Top bar only (manual sidebar toggle)"
        case .minimalist: return "Fullscreen immersion with top-middle hover bar"
        }
    }
}

// MARK: - User Profile
public struct UserProfile: Codable, Equatable, Sendable, Identifiable {
    public var id: String {
        email.isEmpty ? name : email
    }
    public var name: String
    public var firstName: String
    public var lastName: String
    public var nickname: String
    public var useNickname: Bool
    public var email: String
    public var avatarUrl: String?
    public var avatarImageData: Data?
    public var tier: SubscriptionTier
    public var isLoggedIn: Bool
    public var hasPasskey: Bool
    
    public init(
        name: String,
        firstName: String = "",
        lastName: String = "",
        nickname: String = "",
        useNickname: Bool = false,
        email: String,
        avatarUrl: String? = nil,
        avatarImageData: Data? = nil,
        tier: SubscriptionTier = .aiPro,
        isLoggedIn: Bool = true,
        hasPasskey: Bool = false
    ) {
        self.name = name
        self.firstName = firstName
        self.lastName = lastName
        self.nickname = nickname
        self.useNickname = useNickname
        self.email = email
        self.avatarUrl = avatarUrl
        self.avatarImageData = avatarImageData
        self.tier = tier
        self.isLoggedIn = isLoggedIn
        self.hasPasskey = hasPasskey
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.firstName = try container.decodeIfPresent(String.self, forKey: .firstName) ?? ""
        self.lastName = try container.decodeIfPresent(String.self, forKey: .lastName) ?? ""
        self.nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        self.useNickname = try container.decodeIfPresent(Bool.self, forKey: .useNickname) ?? false
        self.email = try container.decode(String.self, forKey: .email)
        self.avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        self.avatarImageData = try container.decodeIfPresent(Data.self, forKey: .avatarImageData)
        self.tier = try container.decodeIfPresent(SubscriptionTier.self, forKey: .tier) ?? .aiPro
        self.isLoggedIn = try container.decodeIfPresent(Bool.self, forKey: .isLoggedIn) ?? true
        self.hasPasskey = try container.decodeIfPresent(Bool.self, forKey: .hasPasskey) ?? false
    }
    
    public var displayName: String {
        let full = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        if !full.isEmpty { return full }
        if !name.isEmpty { return name }
        return "Workspace User"
    }
    
    public var greetingName: String {
        if useNickname && !nickname.trimmingCharacters(in: .whitespaces).isEmpty {
            return nickname.trimmingCharacters(in: .whitespaces)
        }
        if !firstName.trimmingCharacters(in: .whitespaces).isEmpty {
            return firstName.trimmingCharacters(in: .whitespaces)
        }
        let parts = name.split(separator: " ")
        if let first = parts.first, !first.isEmpty {
            return String(first)
        }
        return name.isEmpty ? "Friend" : name
    }
    
    public static func loadDefaultAvatarData() -> Data? {
        if let resUrl = Bundle.main.url(forResource: "default_avatar", withExtension: "png", subdirectory: "Images") {
            return try? Data(contentsOf: resUrl)
        }
        if let directUrl = Bundle.main.url(forResource: "default_avatar", withExtension: "png") {
            return try? Data(contentsOf: directUrl)
        }
        let localPaths = [
            "Resources/Images/default_avatar.png",
            "Workspace.app/Contents/Resources/Images/default_avatar.png"
        ]
        for p in localPaths {
            if FileManager.default.fileExists(atPath: p) {
                return try? Data(contentsOf: URL(fileURLWithPath: p))
            }
        }
        return nil
    }
    
    public static let `default` = UserProfile(
        name: "Charlie C-S",
        firstName: "Charlie",
        lastName: "C-S",
        nickname: "",
        useNickname: false,
        email: "ccserfalvismith@gmail.com",
        avatarUrl: nil,
        avatarImageData: loadDefaultAvatarData(),
        tier: .aiPro,
        isLoggedIn: true,
        hasPasskey: true
    )
    
    public static let empty = UserProfile(
        name: "",
        firstName: "",
        lastName: "",
        nickname: "",
        useNickname: false,
        email: "",
        avatarUrl: nil,
        avatarImageData: nil,
        tier: .standard,
        isLoggedIn: false,
        hasPasskey: false
    )
}

// MARK: - Appearance Mode
public enum AppearanceMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case light = "Light"
    case dark = "Dark"
    case auto = "Auto"
    
    public var id: String { rawValue }
    
    @MainActor
    public static var currentSystemColorScheme: ColorScheme {
        let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return match == .darkAqua ? .dark : .light
    }
    
    @MainActor
    public var resolvedColorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .auto: return Self.currentSystemColorScheme
        }
    }
    
    @MainActor
    public var colorScheme: ColorScheme? {
        resolvedColorScheme
    }
}

// MARK: - Color Hex Extension
extension Color {
    public init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 66, 133, 244)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
