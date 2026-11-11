import SwiftUI
import Combine
import AppKit
import WebKit

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    // MARK: - App Persistence Keys
    private let kRecentlyUsedKey = "Workspace_RecentlyUsedApps"
    private let kPinnedAppsKey = "Workspace_PinnedApps"
    private let kUserProfileKey = "Workspace_UserProfile"
    private let kAppearanceModeKey = "Workspace_AppearanceMode"
    private let kHasCompletedSetupKey = "Workspace_HasCompletedSetup"
    private let kHideTileTitlesKey = "Workspace_HideTileTitles"
    private let kIsSidebarCollapsedKey = "Workspace_IsSidebarCollapsed"
    private let kLastOpenedDocumentKey = "Workspace_LastOpenedDocument"
    public static let maxAccountsCount = 5
    private let kAccountsKey = "Workspace_Accounts_V2"
    private let kActiveAccountIdKey = "Workspace_ActiveAccountId"
    
    // MARK: - Published State
    @Published public var apps: [WorkspaceAppItem] = []
    @Published public var selectedAppId: String? = nil // nil means Home is selected
    @Published public var searchQuery: String = ""
    
    // Continue where you left off
    @Published public var lastOpenedDocument: RecentDocumentItem? {
        didSet { saveLastOpenedDocument() }
    }
    @Published public var overrideUrlForApp: [String: URL] = [:]
    
    // Dedicated Multi-Account Storage (Up to 5 accounts)
    @Published public var accounts: [UserProfile] = []
    @Published public var activeAccountId: String = ""
    @Published public var isAddingNewAccount: Bool = false
    
    public var activeAccount: UserProfile {
        if let acc = accounts.first(where: { $0.accountId == activeAccountId }) {
            return acc
        }
        return accounts.first ?? .default
    }
    
    // Current active user profile
    public var userProfile: UserProfile {
        get {
            activeAccount
        }
        set {
            if let idx = accounts.firstIndex(where: { $0.accountId == activeAccountId }) {
                accounts[idx] = newValue
                saveAccounts()
            } else if !accounts.isEmpty {
                accounts[0] = newValue
                saveAccounts()
            }
        }
    }
    
    @Published public var appearanceMode: AppearanceMode {
        didSet {
            saveAppearanceMode()
            applyAppearanceToWindow()
        }
    }
    
    @Published public var hasCompletedSetup: Bool {
        didSet { UserDefaults.standard.set(hasCompletedSetup, forKey: kHasCompletedSetupKey) }
    }
    
    @Published public var hideTileTitles: Bool {
        didSet { UserDefaults.standard.set(hideTileTitles, forKey: kHideTileTitlesKey) }
    }
    
    @Published public var isSidebarCollapsed: Bool {
        didSet { UserDefaults.standard.set(isSidebarCollapsed, forKey: kIsSidebarCollapsedKey) }
    }
    
    // Recently Used section collapsible state
    @Published public var isRecentlyUsedCollapsed: Bool {
        didSet { UserDefaults.standard.set(isRecentlyUsedCollapsed, forKey: "isRecentlyUsedCollapsed") }
    }
    
    // App viewing layout mode (Everything, Essentials [Default], Minimalist ["At a glance"])
    @Published public var appViewMode: AppViewMode {
        didSet { UserDefaults.standard.set(appViewMode.rawValue, forKey: "appViewMode") }
    }
    
    // Background Update Check State
    @Published public var availableUpdate: AppUpdateInfo? = nil
    @Published public var dismissedUpdateTags: Set<String> = []
    
    // Active Web View & Zoom Controls
    public weak var activeWebView: WKWebView? = nil {
        didSet {
            if let wv = activeWebView {
                currentZoom = Double(wv.pageZoom)
            } else {
                currentZoom = 1.0
            }
        }
    }
    @Published public var currentZoom: Double = 1.0
    
    public func zoomIn() {
        guard let wv = activeWebView else { return }
        let next = min((round(Double(wv.pageZoom) * 10) / 10) + 0.1, 3.0)
        wv.pageZoom = CGFloat(next)
        currentZoom = next
    }
    
    public func zoomOut() {
        guard let wv = activeWebView else { return }
        let next = max((round(Double(wv.pageZoom) * 10) / 10) - 0.1, 0.5)
        wv.pageZoom = CGFloat(next)
        currentZoom = next
    }
    
    public func resetZoom() {
        guard let wv = activeWebView else { return }
        wv.pageZoom = 1.0
        wv.magnification = 1.0
        currentZoom = 1.0
    }
    
    public func dismissUpdate(_ tag: String) {
        dismissedUpdateTags.insert(tag)
        UserDefaults.standard.set(Array(dismissedUpdateTags), forKey: "dismissedUpdateTags")
    }
    
    public func checkForUpdates() {
        UpdateCheckerService.shared.checkForUpdates { [weak self] update in
            DispatchQueue.main.async {
                self?.availableUpdate = update
            }
        }
    }
    
    // Temporary overlay sidebar state when viewing app in Essentials or Minimalist mode
    @Published public var isManualSidebarOpenInApp: Bool = false
    
    // Draggable left bookmark tab position
    @Published public var bookmarkTabOffsetY: CGFloat = 220.0
    
    // Web view navigation action signals
    @Published public var webViewActionSignal: WebAction = .none
    
    public enum WebAction {
        case none
        case goBack
        case goForward
        case reload
    }
    
    public init() {
        // Load initial setup status
        self.hasCompletedSetup = UserDefaults.standard.bool(forKey: kHasCompletedSetupKey)
        self.hideTileTitles = UserDefaults.standard.bool(forKey: kHideTileTitlesKey)
        self.isSidebarCollapsed = UserDefaults.standard.bool(forKey: kIsSidebarCollapsedKey)
        self.isRecentlyUsedCollapsed = UserDefaults.standard.bool(forKey: "isRecentlyUsedCollapsed")
        
        // Load App View Mode (defaults to Essentials)
        if let rawMode = UserDefaults.standard.string(forKey: "appViewMode"),
           let mode = AppViewMode(rawValue: rawMode) {
            self.appViewMode = mode
        } else {
            self.appViewMode = .essentials
        }
        
        // Load Appearance Mode (default to dark if not set)
        if let rawMode = UserDefaults.standard.string(forKey: kAppearanceModeKey),
           let mode = AppearanceMode(rawValue: rawMode) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .dark
        }
        
        // Load Dedicated Accounts (Up to 5 accounts)
        if let data = UserDefaults.standard.data(forKey: "Workspace_Accounts_V2"),
           let savedAccounts = try? JSONDecoder().decode([UserProfile].self, from: data),
           !savedAccounts.isEmpty {
            self.accounts = Array(savedAccounts.prefix(Self.maxAccountsCount))
            let savedActiveId = UserDefaults.standard.string(forKey: "Workspace_ActiveAccountId") ?? ""
            if self.accounts.contains(where: { $0.accountId == savedActiveId }) {
                self.activeAccountId = savedActiveId
            } else {
                self.activeAccountId = self.accounts.first?.accountId ?? ""
            }
        } else {
            // Migrate single legacy userProfile if present, otherwise default
            var initialProfile: UserProfile = .default
            if let legacyData = UserDefaults.standard.data(forKey: kUserProfileKey),
               let profile = try? JSONDecoder().decode(UserProfile.self, from: legacyData) {
                initialProfile = profile
            }
            if initialProfile.accountId.isEmpty {
                initialProfile.accountId = UUID().uuidString
            }
            self.accounts = [initialProfile]
            self.activeAccountId = initialProfile.accountId
            saveAccounts()
        }
        
        // Populate apps catalog
        self.apps = Self.defaultAppsCatalog()
        
        // Load Pinned and Recent
        loadPersistedAppData()
        
        // Load Last Opened Document ("Continue where you left off")
        if let data = UserDefaults.standard.data(forKey: kLastOpenedDocumentKey),
           let doc = try? JSONDecoder().decode(RecentDocumentItem.self, from: data) {
            self.lastOpenedDocument = doc
        } else {
            // Seed initial sample document
            self.lastOpenedDocument = RecentDocumentItem(
                appId: "docs",
                appName: "Google Docs",
                documentTitle: "Music Tech Book Y12",
                documentUrl: "https://docs.google.com/document/u/0/"
            )
        }
        
        // Listen for macOS system theme changes (Dark/Light mode switch)
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.appearanceMode == .auto {
                    self.objectWillChange.send()
                    self.applyAppearanceToWindow()
                }
            }
        }
        
        applyAppearanceToWindow()
        
        // Load dismissed updates
        if let savedDismissed = UserDefaults.standard.stringArray(forKey: "dismissedUpdateTags") {
            self.dismissedUpdateTags = Set(savedDismissed)
        }
        
        // Asynchronously check for releases on GitHub after a brief launch delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.checkForUpdates()
        }
    }
    
    public var effectiveColorScheme: ColorScheme {
        appearanceMode.resolvedColorScheme
    }
    
    public func applyAppearanceToWindow() {
        DispatchQueue.main.async {
            for window in NSApp.windows {
                switch self.appearanceMode {
                case .light:
                    window.appearance = NSAppearance(named: .aqua)
                case .dark:
                    window.appearance = NSAppearance(named: .darkAqua)
                case .auto:
                    window.appearance = nil
                }
            }
        }
    }
    
    // MARK: - App Catalog Definition
    public static func defaultAppsCatalog() -> [WorkspaceAppItem] {
        return [
            WorkspaceAppItem(
                id: "gemini",
                name: "Gemini",
                category: .intelligence,
                appDescription: "Supercharge your thinking with Google's most capable AI model.",
                urlString: "https://gemini.google.com",
                newDocUrlString: "https://gemini.google.com/app",
                iconSymbol: "sparkles",
                colorHex: "00A4F9",
                secondaryColorHex: "F7646F",
                isPinned: false
            ),
            WorkspaceAppItem(
                id: "docs",
                name: "Google Docs",
                category: .productivity,
                appDescription: "Create, edit, and collaborate on documents in real time.",
                urlString: "https://docs.google.com",
                newDocUrlString: "https://docs.new",
                iconSymbol: "doc.text.fill",
                colorHex: "4285F4",
                secondaryColorHex: "1A73E8",
                isPinned: false
            ),
            WorkspaceAppItem(
                id: "sheets",
                name: "Google Sheets",
                category: .productivity,
                appDescription: "Smart spreadsheets with automated data insights and Gemini tools.",
                urlString: "https://sheets.google.com",
                newDocUrlString: "https://sheets.new",
                iconSymbol: "tablecells.fill",
                colorHex: "0F9D58",
                secondaryColorHex: "34A853",
                isPinned: false
            ),
            WorkspaceAppItem(
                id: "slides",
                name: "Google Slides",
                category: .productivity,
                appDescription: "Stunning presentations with intelligent themes and transitions.",
                urlString: "https://slides.google.com",
                newDocUrlString: "https://slides.new",
                iconSymbol: "play.rectangle.fill",
                colorHex: "F4B400",
                secondaryColorHex: "FBBC04",
                isPinned: false
            ),
            WorkspaceAppItem(
                id: "drive",
                name: "Google Drive",
                category: .storageAndAdmin,
                appDescription: "Secure cloud file storage, synchronisation, and quick file sharing.",
                urlString: "https://drive.google.com",
                newDocUrlString: "https://drive.google.com/drive/my-drive",
                iconSymbol: "externaldrive.fill",
                colorHex: "34A853",
                secondaryColorHex: "4285F4",
                isPinned: false
            ),
            WorkspaceAppItem(
                id: "gmail",
                name: "Gmail",
                category: .communication,
                appDescription: "Secure, smart, and fast email with AI-assisted drafting.",
                urlString: "https://mail.google.com",
                newDocUrlString: "https://mail.google.com/mail/u/0/#inbox?compose=new",
                iconSymbol: "envelope.fill",
                colorHex: "EA4335",
                secondaryColorHex: "D93025",
                isPinned: false
            ),
            WorkspaceAppItem(
                id: "calendar",
                name: "Google Calendar",
                category: .communication,
                appDescription: "Intelligent scheduling, meeting slots, and time management.",
                urlString: "https://calendar.google.com",
                newDocUrlString: "https://calendar.google.com/calendar/r/eventedit",
                iconSymbol: "calendar",
                colorHex: "4285F4",
                secondaryColorHex: "1A73E8",
                isPinned: false
            ),
            WorkspaceAppItem(
                id: "meet",
                name: "Google Meet",
                category: .communication,
                appDescription: "High-definition video meetings with live captions and background blur.",
                urlString: "https://meet.google.com",
                newDocUrlString: "https://meet.new",
                iconSymbol: "video.fill",
                colorHex: "00AC47",
                secondaryColorHex: "00832D",
                isPinned: false
            ),
            WorkspaceAppItem(
                id: "chat",
                name: "Google Chat",
                category: .communication,
                appDescription: "Team messaging spaces, threads, and direct channels.",
                urlString: "https://chat.google.com",
                newDocUrlString: nil,
                iconSymbol: "bubble.left.and.bubble.right.fill",
                colorHex: "0F9D58",
                secondaryColorHex: "34A853",
                isPinned: false
            ),
            WorkspaceAppItem(
                id: "keep",
                name: "Google Keep",
                category: .notesAndTasks,
                appDescription: "Capture notes, lists, voice memos, and fast reminders.",
                urlString: "https://keep.google.com",
                newDocUrlString: "https://keep.new",
                iconSymbol: "lightbulb.fill",
                colorHex: "F4B400",
                secondaryColorHex: "FBBC04",
                isPinned: false
            ),
            WorkspaceAppItem(
                id: "notebooklm",
                name: "NotebookLM",
                category: .intelligence,
                appDescription: "Personalized AI research assistant grounded in your notes and sources.",
                urlString: "https://notebooklm.google.com",
                newDocUrlString: nil,
                iconSymbol: "book.pages.fill",
                colorHex: "1A73E8",
                secondaryColorHex: "9B51E0",
                isPinned: false
            ),
            WorkspaceAppItem(
                id: "forms",
                name: "Google Forms",
                category: .productivity,
                appDescription: "Create surveys, forms, and quizzes with automatic response analysis.",
                urlString: "https://forms.google.com",
                newDocUrlString: "https://forms.new",
                iconSymbol: "list.clipboard.fill",
                colorHex: "7248B9",
                secondaryColorHex: "5E35B1",
                isPinned: false
            ),
            WorkspaceAppItem(
                id: "sites",
                name: "Google Sites",
                category: .productivity,
                appDescription: "Effortlessly build dynamic team intranet and project sites.",
                urlString: "https://sites.google.com",
                newDocUrlString: "https://sites.new",
                iconSymbol: "globe",
                colorHex: "1A73E8",
                secondaryColorHex: "4285F4",
                isPinned: false
            ),
            WorkspaceAppItem(
                id: "contacts",
                name: "Google Contacts",
                category: .storageAndAdmin,
                appDescription: "Organize, merge, and sync contacts across all your devices.",
                urlString: "https://contacts.google.com",
                newDocUrlString: "https://contacts.google.com/new",
                iconSymbol: "person.crop.circle.fill",
                colorHex: "4285F4",
                secondaryColorHex: "1A73E8",
                isPinned: false
            ),
            WorkspaceAppItem(
                id: "tasks",
                name: "Google Tasks",
                category: .notesAndTasks,
                appDescription: "Track day-to-day to-dos seamlessly integrated with Calendar and Gmail.",
                urlString: "https://calendar.google.com/calendar/u/0/r/tasks",
                newDocUrlString: nil,
                iconSymbol: "checkmark.circle.fill",
                colorHex: "4285F4",
                secondaryColorHex: "1A73E8",
                isPinned: false
            ),
            WorkspaceAppItem(
                id: "classroom",
                name: "Google Classroom",
                category: .productivity,
                appDescription: "All-in-one place for teaching, assignments, and learning.",
                urlString: "https://classroom.google.com",
                newDocUrlString: nil,
                iconSymbol: "graduationcap.fill",
                colorHex: "0F9D58",
                secondaryColorHex: "34A853",
                isPinned: false
            ),
            WorkspaceAppItem(
                id: "cloud",
                name: "Google Cloud",
                category: .storageAndAdmin,
                appDescription: "Build, deploy, and scale applications on Google infrastructure.",
                urlString: "https://console.cloud.google.com",
                newDocUrlString: nil,
                iconSymbol: "cloud.fill",
                colorHex: "4285F4",
                secondaryColorHex: "1A73E8",
                isPinned: false
            ),
            WorkspaceAppItem(
                id: "admin",
                name: "Google Admin",
                category: .storageAndAdmin,
                appDescription: "Manage users, organizational units, and domain security.",
                urlString: "https://admin.google.com",
                newDocUrlString: nil,
                iconSymbol: "gearshape.2.fill",
                colorHex: "5F6368",
                secondaryColorHex: "1A73E8",
                isPinned: false
            )
        ]
    }
    
    // MARK: - App Actions
    public func launchApp(_ app: WorkspaceAppItem) {
        if let idx = apps.firstIndex(where: { $0.id == app.id }) {
            apps[idx].lastUsed = Date()
            apps[idx].launchCount += 1
            persistAppData()
        }
        
        if appViewMode == .separated {
            openSeparateWindow(for: app)
            return
        }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            selectedAppId = app.id
        }
    }
    
    public func launchNewItem(for app: WorkspaceAppItem) {
        if let idx = apps.firstIndex(where: { $0.id == app.id }) {
            apps[idx].lastUsed = Date()
            apps[idx].launchCount += 1
            persistAppData()
        }
        
        if appViewMode == .separated {
            openSeparateWindow(for: app)
            return
        }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            selectedAppId = app.id
        }
    }
    
    public func togglePin(appId: String) {
        if let idx = apps.firstIndex(where: { $0.id == appId }) {
            withAnimation(.easeInOut(duration: 0.2)) {
                apps[idx].isPinned.toggle()
            }
            persistAppData()
        }
    }
    
    public func setPinned(appId: String, pinned: Bool) {
        if let idx = apps.firstIndex(where: { $0.id == appId }) {
            if apps[idx].isPinned != pinned {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    apps[idx].isPinned = pinned
                }
                persistAppData()
            }
        }
    }
    
    public func openSeparateWindow(for app: WorkspaceAppItem, customUrl: URL? = nil) {
        StandaloneWindowManager.shared.openWindow(for: app, userEmail: userProfile.email, customUrl: customUrl)
    }
    
    // MARK: - Continue Where You Left Off Action
    public func resumeLastDocument() {
        guard let doc = lastOpenedDocument,
              let app = apps.first(where: { $0.id == doc.appId }) ?? apps.first(where: { $0.id == "docs" }) else {
            return
        }
        
        let targetUrl = URL(string: doc.documentUrl) ?? app.resolvedUrl(for: userProfile.email)
        
        if appViewMode == .separated {
            openSeparateWindow(for: app, customUrl: targetUrl)
            return
        }
        
        overrideUrlForApp[app.id] = targetUrl
        launchApp(app)
    }
    
    public func recordRecentDocument(appId: String, appName: String, title: String, urlString: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty,
              !urlString.isEmpty,
              !urlString.contains("accounts.google.com") else { return }
        
        // Clean off browser suffixes like " - Google Docs"
        let cleanTitle = cleanDocumentTitle(trimmedTitle, appName: appName)
        let item = RecentDocumentItem(
            appId: appId,
            appName: appName,
            documentTitle: cleanTitle,
            documentUrl: urlString,
            lastOpened: Date()
        )
        self.lastOpenedDocument = item
    }
    
    private func cleanDocumentTitle(_ raw: String, appName: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffixes = [
            " - Google Docs",
            " - Google Sheets",
            " - Google Slides",
            " - Google Drive",
            " - Google Calendar",
            " - Google Keep",
            " - Google Mail",
            " - Gmail",
            " - Google Meet",
            " - Google Chat",
            " - NotebookLM",
            " - Google"
        ]
        for s in suffixes {
            if t.hasSuffix(s) {
                t = String(t.dropLast(s.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if t.hasPrefix("(NEW) ") {
            t = String(t.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if t.hasPrefix("* ") {
            t = String(t.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // If empty or matches appName exactly, return fallback
        if t.isEmpty || t.caseInsensitiveCompare(appName) == .orderedSame {
            return "Active Document"
        }
        return t
    }
    
    public func goHome() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            selectedAppId = nil
        }
    }
    
    public func toggleSidebar() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            isSidebarCollapsed.toggle()
        }
    }
    
    public func selectProfilePicture() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image, .png, .jpeg]
        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            userProfile.avatarImageData = data
        }
    }
    
    public var selectedApp: WorkspaceAppItem? {
        guard let id = selectedAppId else { return nil }
        return apps.first(where: { $0.id == id })
    }
    
    public var recentlyUsedApps: [WorkspaceAppItem] {
        apps.filter { $0.lastUsed != nil }
            .sorted { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
    }
    
    public var pinnedApps: [WorkspaceAppItem] {
        apps.filter { $0.isPinned }
    }
    
    public var filteredApps: [WorkspaceAppItem] {
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return apps
        }
        
        let q = searchQuery.lowercased()
        return apps.filter {
            $0.name.lowercased().contains(q) ||
            $0.appDescription.lowercased().contains(q)
        }
    }
    
    // MARK: - Persistence Helpers
    private func persistAppData() {
        let pinnedIds = apps.filter { $0.isPinned }.map { $0.id }
        UserDefaults.standard.set(pinnedIds, forKey: kPinnedAppsKey)
        
        var recentsDict: [String: Double] = [:]
        for app in apps {
            if let date = app.lastUsed {
                recentsDict[app.id] = date.timeIntervalSince1970
            }
        }
        UserDefaults.standard.set(recentsDict, forKey: kRecentlyUsedKey)
    }
    
    private func loadPersistedAppData() {
        if let pinnedIds = UserDefaults.standard.stringArray(forKey: kPinnedAppsKey) {
            let set = Set(pinnedIds)
            for i in 0..<apps.count {
                apps[i].isPinned = set.contains(apps[i].id)
            }
        }
        
        if let recentsDict = UserDefaults.standard.dictionary(forKey: kRecentlyUsedKey) as? [String: Double] {
            for i in 0..<apps.count {
                if let timestamp = recentsDict[apps[i].id] {
                    apps[i].lastUsed = Date(timeIntervalSince1970: timestamp)
                }
            }
        }
    }
    
    public func saveUserProfile() {
        saveAccounts()
    }
    
    public func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: kAccountsKey)
        }
        UserDefaults.standard.set(activeAccountId, forKey: kActiveAccountIdKey)
        if let active = accounts.first(where: { $0.accountId == activeAccountId }),
           let legacyData = try? JSONEncoder().encode(active) {
            UserDefaults.standard.set(legacyData, forKey: kUserProfileKey)
        }
    }
    
    public func dataStore(for account: UserProfile) -> WKWebsiteDataStore {
        if #available(macOS 14.0, *) {
            return WKWebsiteDataStore(forIdentifier: account.dataStoreUuid)
        } else {
            return WKWebsiteDataStore.default()
        }
    }
    
    public var activeDataStore: WKWebsiteDataStore {
        dataStore(for: activeAccount)
    }
    
    public func switchAccount(to accountId: String) {
        guard activeAccountId != accountId,
              accounts.contains(where: { $0.accountId == accountId }) else { return }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            activeAccountId = accountId
        }
        UserDefaults.standard.set(activeAccountId, forKey: kActiveAccountIdKey)
        
        if selectedAppId != nil {
            webViewActionSignal = .reload
        }
    }
    
    public func addNewAccount(name: String, email: String, label: String = "") {
        guard accounts.count < Self.maxAccountsCount else { return }
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (cleanEmail.components(separatedBy: "@").first?.capitalized ?? "Google Account \(accounts.count + 1)")
            : name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let finalLabel = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Account \(accounts.count + 1)"
            : label.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let newAccount = UserProfile(
            accountId: UUID().uuidString,
            dataStoreUuid: UUID(),
            accountLabel: finalLabel,
            name: cleanName,
            firstName: cleanName.components(separatedBy: " ").first ?? cleanName,
            lastName: cleanName.components(separatedBy: " ").dropFirst().joined(separator: " "),
            email: cleanEmail,
            isLoggedIn: !cleanEmail.isEmpty
        )
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            accounts.append(newAccount)
            activeAccountId = newAccount.accountId
        }
        saveAccounts()
        
        if selectedAppId != nil {
            webViewActionSignal = .reload
        }
    }
    
    public func removeAccount(accountId: String) {
        guard accounts.count > 1 else { return }
        guard let idx = accounts.firstIndex(where: { $0.accountId == accountId }) else { return }
        
        let toRemove = accounts[idx]
        withAnimation(.easeInOut(duration: 0.2)) {
            accounts.remove(at: idx)
            if activeAccountId == accountId {
                activeAccountId = accounts.first?.accountId ?? ""
            }
        }
        saveAccounts()
        
        if #available(macOS 14.0, *) {
            let store = WKWebsiteDataStore(forIdentifier: toRemove.dataStoreUuid)
            store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { }
        }
        
        if selectedAppId != nil {
            webViewActionSignal = .reload
        }
    }
    
    private func saveLastOpenedDocument() {
        if let doc = lastOpenedDocument, let data = try? JSONEncoder().encode(doc) {
            UserDefaults.standard.set(data, forKey: kLastOpenedDocumentKey)
        }
    }
    
    private func saveAppearanceMode() {
        UserDefaults.standard.set(appearanceMode.rawValue, forKey: kAppearanceModeKey)
    }
    
    public func resetSetup() {
        hasCompletedSetup = false
        selectedAppId = nil
    }
    
    // MARK: - Single Account Sign-In
    public func loginWithAccount(
        name: String,
        email: String,
        usePasskey: Bool = false,
        tier: SubscriptionTier = .aiPro,
        completion: (() -> Void)? = nil
    ) {
        let finalEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalEmail.isEmpty else { return }
        
        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (finalEmail.components(separatedBy: "@").first?.capitalized ?? "Workspace User")
            : name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let parts = finalName.split(separator: " ")
        let first = parts.first.map(String.init) ?? finalName
        let last = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : ""
        
        // Clear previous cookies so Google starts clean for the new account
        clearWebKitCookies { [weak self] in
            guard let self = self else { return }
            self.userProfile = UserProfile(
                name: finalName,
                firstName: first,
                lastName: last,
                nickname: "",
                useNickname: false,
                email: finalEmail,
                avatarUrl: nil,
                avatarImageData: nil,
                tier: tier,
                isLoggedIn: true,
                hasPasskey: usePasskey
            )
            self.saveUserProfile()
            if self.selectedAppId != nil {
                self.webViewActionSignal = .reload
            }
            completion?()
        }
    }
    
    // MARK: - Thorough WebKit & Cookie Purge (Active Account)
    public func clearWebKitCookies(completion: (() -> Void)? = nil) {
        let dataStore = activeDataStore
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        
        dataStore.removeData(ofTypes: dataTypes, modifiedSince: Date.distantPast) {
            let cookieStore = dataStore.httpCookieStore
            cookieStore.getAllCookies { cookies in
                let group = DispatchGroup()
                for cookie in cookies {
                    group.enter()
                    cookieStore.delete(cookie) {
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    HTTPCookieStorage.shared.removeCookies(since: .distantPast)
                    URLCache.shared.removeAllCachedResponses()
                    print("Workspace: All WebKit cookies, caches, and Google sessions purged for active account.")
                    completion?()
                }
            }
        }
    }
    
    // MARK: - Unlink Account / Logout (Strictly removes the single account)
    public func unlinkAccount() {
        // Reset user profile to empty unlinked state
        userProfile = .empty
        
        // Remove saved profile from UserDefaults
        UserDefaults.standard.removeObject(forKey: kUserProfileKey)
        
        // Clear all cookies and web cache
        clearWebKitCookies()
        
        // Reset setup and selection
        selectedAppId = nil
        hasCompletedSetup = false
    }
}
