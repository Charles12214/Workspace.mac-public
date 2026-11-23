import SwiftUI
import AppKit

// MARK: - Settings Navigation Tabs
public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general
    case homeScreen
    case appearance
    case weather
    case accounts
    case offline
    case updates
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .general: return "General"
        case .homeScreen: return "Home Screen"
        case .appearance: return "Appearance"
        case .weather: return "Weather & Clock"
        case .accounts: return "Accounts & Profile"
        case .offline: return "Offline & Privacy"
        case .updates: return "Updates & About"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .general: return "Configure viewing modes and setup preferences."
        case .homeScreen: return "Customize visible home sections, tiles, and dynamic weather atmosphere."
        case .appearance: return "Choose how Workspace.mac looks on your Mac."
        case .weather: return "Manage local time display, units, and encrypted weather locations."
        case .accounts: return "Personalize your profile and switch between up to 5 local accounts."
        case .offline: return "Manage pre-downloaded Workspace apps and browser cookies."
        case .updates: return "Check for new Workspace.mac releases and version info."
        }
    }
    
    public var iconName: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .homeScreen: return "house.fill"
        case .appearance: return "circle.lefthalf.filled"
        case .weather: return "cloud.sun.fill"
        case .accounts: return "person.2.fill"
        case .offline: return "internaldrive.fill"
        case .updates: return "arrow.down.circle.fill"
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject private var weatherService = WeatherService.shared
    @ObservedObject private var offlineManager = OfflineManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: SettingsTab = .general
    @State private var hoveredTab: SettingsTab? = nil
    @State private var showingClearCookiesAlert: Bool = false
    @State private var showingFreshResetPopup: Bool = false
    @State private var cookiesClearedMessage: Bool = false
    @State private var citySearchQuery: String = ""
    
    @State private var newAccountLabel: String = "Work"
    @State private var newAccountFirstName: String = ""
    @State private var newAccountLastName: String = ""
    @State private var newAccountNickname: String = ""
    @State private var newAccountUseNickname: Bool = false
    
    private func resetNewAccountFields() {
        newAccountLabel = "Work"
        newAccountFirstName = ""
        newAccountLastName = ""
        newAccountNickname = ""
        newAccountUseNickname = false
    }
    
    public init(state: AppState) {
        self.state = state
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            sidebarNavigation
            
            Divider().opacity(0.25)
            
            rightContentPane
        }
        .frame(width: 820, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay {
            if showingFreshResetPopup {
                freshResetConfirmationOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .alert("Clear Google Web Cookies?", isPresented: $showingClearCookiesAlert) {
            Button("Clear All Cookies", role: .destructive) {
                state.clearWebKitCookies {
                    cookiesClearedMessage = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        cookiesClearedMessage = false
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will purge all cached Google login cookies from the app. You will need to sign in again when opening Google web apps.")
        }
    }
    
    // MARK: - Left Sidebar (Antigravity Style)
    private var sidebarNavigation: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(SettingsTab.allCases) { tab in
                        sidebarTabRow(tab)
                    }
                }
                .padding(.horizontal, 10)
            }
            
            Spacer()
            
            Divider().opacity(0.2)
            
            // Bottom Active Account Pill
            Button(action: {
                selectedTab = .accounts
            }) {
                HStack(spacing: 10) {
                    GoogleProfileAvatarView(
                        avatarData: state.userProfile.avatarImageData,
                        name: state.userProfile.displayName,
                        size: 30,
                        tier: state.userProfile.tier,
                        showEditButton: false
                    )
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(state.userProfile.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        Text(state.userProfile.email.isEmpty ? state.activeAccount.accountLabel : state.userProfile.email)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Manage local accounts & profile")
        }
        .frame(width: 210)
        .background(Color.primary.opacity(0.025))
    }
    
    private func sidebarTabRow(_ tab: SettingsTab) -> some View {
        let isSelected = selectedTab == tab
        let isHovered = hoveredTab == tab
        return Button(action: {
            selectedTab = tab
        }) {
            HStack(spacing: 9) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color(hex: "1A73E8") : .secondary)
                    .frame(width: 18, alignment: .center)
                
                Text(tab.title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7.5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.09) : (isHovered ? Color.primary.opacity(0.045) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredTab = hovering ? tab : (hoveredTab == tab ? nil : hoveredTab)
        }
    }
    
    // MARK: - Right Content Pane
    private var rightContentPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Content Header + Close Button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedTab.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text(selectedTab.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Close Settings")
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 14)
            
            Divider().opacity(0.2)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    tabContent
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .general:
            generalTabContent
        case .homeScreen:
            homeScreenTabContent
        case .appearance:
            appearanceTabContent
        case .weather:
            weatherTabContent
        case .accounts:
            accountsTabContent
        case .offline:
            offlineTabContent
        case .updates:
            updatesTabContent
        }
    }
    
    // MARK: - Tab 1: General
    @ViewBuilder
    private var generalTabContent: some View {
        // App Viewing Mode & "At a glance"
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("APP VIEWING MODE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("Default: Essentials")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 8) {
                modeOptionCard(mode: .everything, title: "Everything", subtitle: "Sidebar + Top Bar")
                modeOptionCard(mode: .essentials, title: "Essentials", subtitle: "Top Bar only")
                modeOptionCard(mode: .minimalist, title: "Minimalist", subtitle: "'At a glance'")
                modeOptionCard(mode: .separated, title: "Separated Apps", subtitle: "Separate window")
            }
            
            Divider().opacity(0.3)
            
            HStack(spacing: 12) {
                PulsingGlanceEmblem()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("At a glance")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Edge-to-edge immersion. Controls emerge on top-middle hover; draggable bookmark tab on left.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { state.appViewMode == .minimalist },
                    set: { enabled in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            state.appViewMode = enabled ? .minimalist : .essentials
                        }
                    }
                ))
                .toggleStyle(.switch)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "00A4F9").opacity(0.4),
                                Color(hex: "8B5CF6").opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
        }
        .padding(16)
        .liquidGlass(cornerRadius: 14)
        
        // Reset / Re-run Setup Wizard
        VStack(alignment: .leading, spacing: 10) {
            Text("SETUP WIZARD")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            HStack {
                Text("Walk through the welcome tour, weather opt-in, theme, and profile customization again.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(action: {
                    state.resetSetup()
                    dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Re-run Setup Wizard")
                    }
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color(hex: "EA4335"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "EA4335").opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 14)
        
        // Fresh Reset (Dangerous Session Wipe)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color(hex: "EA4335"))
                Text("FRESH RESET")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "EA4335"))
            }
            
            HStack {
                Text("Erase local session data, cookies, and saved state for this account or start completely fresh across all accounts.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        showingFreshResetPopup = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        Text("Fresh Reset...")
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6.5)
                    .background(Color(hex: "DC2626"))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "DC2626").opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "EF4444").opacity(0.32), lineWidth: 1)
        )
    }
    
    // MARK: - Red Fresh Reset Confirmation Modal
    private var freshResetConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showingFreshResetPopup = false
                    }
                }
            
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "EF4444").opacity(0.22))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color(hex: "EF4444"))
                }
                
                VStack(spacing: 6) {
                    Text("Fresh Reset Local Session?")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("All local session data, Google cookies, and cached state will be permanently deleted on this Mac. Choose whether to reset \"\(state.activeAccount.displayName)\" only or delete all \(state.accounts.count) local account\(state.accounts.count == 1 ? "" : "s").")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.84))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                
                VStack(spacing: 8) {
                    Button(action: {
                        showingFreshResetPopup = false
                        state.freshResetAllAccounts()
                        dismiss()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                            Text("Delete all accounts")
                                .font(.system(size: 12.5, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(hex: "DC2626")))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        showingFreshResetPopup = false
                        state.freshResetCurrentAccount()
                        dismiss()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.crop.circle.badge.minus")
                                .font(.system(size: 12))
                            Text("Delete this account only")
                                .font(.system(size: 12.5, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(hex: "EF4444").opacity(0.22)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(Color(hex: "EF4444").opacity(0.6), lineWidth: 1)
                        )
                        .foregroundStyle(Color(hex: "FCA5A5"))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showingFreshResetPopup = false
                        }
                    }) {
                        Text("Cancel")
                            .font(.system(size: 12.5, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8.5)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.10)))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .frame(width: 400)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "3F0D0D"), Color(hex: "220808")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(hex: "EF4444").opacity(0.65), lineWidth: 1.5)
            )
            .shadow(color: Color(hex: "DC2626").opacity(0.35), radius: 24, y: 8)
        }
    }
    
    // MARK: - Tab 2: Home Screen
    @ViewBuilder
    private var homeScreenTabContent: some View {
        // 1. Dynamic Weather Atmosphere Card
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DYNAMIC WEATHER ATMOSPHERE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("Subtle animated sky & weather effects behind your Home dashboard")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Toggle("", isOn: $state.isWeatherAtmosphereEnabled)
                    .toggleStyle(.switch)
            }
            
            Text("When enabled, Clear skies emit a subtle yellow glow from the top-right corner, Fog drifts translucent clouds, Rain and Thunderstorms bring falling droplets, Snow drops flurries, and freezing conditions bloom stationary frost crystals.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            if state.isWeatherAtmosphereEnabled {
                Divider().opacity(0.3)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("ATMOSPHERE MODE (AUTO OR PREVIEW)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 155, maximum: 195), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(WeatherAtmosphereMode.allCases) { mode in
                            let isSelected = state.weatherAtmosphereMode == mode
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    state.weatherAtmosphereMode = mode
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: mode.iconName)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(isSelected ? Color(hex: "1A73E8") : .secondary)
                                        .frame(width: 16)
                                    
                                    Text(mode.rawValue)
                                        .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                                        .foregroundStyle(isSelected ? Color(hex: "1A73E8") : .primary)
                                        .lineLimit(1)
                                    
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(isSelected ? Color(hex: "1A73E8").opacity(0.10) : Color.primary.opacity(0.03))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .stroke(isSelected ? Color(hex: "1A73E8").opacity(0.55) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 14)
        
        // 2. Visible Home Sections Card
        VStack(alignment: .leading, spacing: 14) {
            Text("VISIBLE HOME SECTIONS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            Toggle(isOn: $state.showOfflineDocsSection) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Recent & Offline Documents")
                        .font(.system(size: 12.5, weight: .medium))
                    Text("Show quick-resume cards for offline-enabled Google Docs & Slides (Sheets in v1.3.2).")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            
            Divider().opacity(0.25)
            
            Toggle(isOn: $state.showRecentlyUsedSection) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Recently Used Apps")
                        .font(.system(size: 12.5, weight: .medium))
                    Text("Show recently launched Google Workspace app tiles on the Home screen.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            
            Divider().opacity(0.25)
            
            Toggle(isOn: $state.showContinueSection) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Continue Where You Left Off")
                        .font(.system(size: 12.5, weight: .medium))
                    Text("Show the hero resume banner for your most recently opened document.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "1A73E8"))
                    .padding(.top, 1)
                
                Text("Pinned Apps and Groups automatically hide when empty and reappear as soon as you pin an app or save a group. All sections except Continue Where You Left Off can also be collapsed directly on the Home screen.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "1A73E8").opacity(0.07)))
            
            if !offlineManager.trackedDocuments.isEmpty {
                Divider().opacity(0.25)
                
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Recent & Offline Document History")
                            .font(.system(size: 12, weight: .medium))
                        Text("\(offlineManager.trackedDocuments.count) tracked document\(offlineManager.trackedDocuments.count == 1 ? "" : "s") shown on Home.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        offlineManager.clearTrackedDocuments()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                                .font(.system(size: 10.5))
                            Text("Clear Offline Recents")
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color(hex: "EA4335"))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color(hex: "EA4335").opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 14)
        
        // 3. Home Screen Tile Customisation
        VStack(alignment: .leading, spacing: 12) {
            Text("HOME SCREEN TILES")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            Toggle("Hide Home tile titles (Keep titles in sidebar)", isOn: $state.hideTileTitles)
                .toggleStyle(.switch)
            
            Text("When enabled, Home screen tiles display minimalist enlarged icon watermarks without text, while full titles remain in the sidebar.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .liquidGlass(cornerRadius: 14)
    }
    
    // MARK: - Tab 2: Appearance
    @ViewBuilder
    private var appearanceTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COLOR THEME")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            AppearancePickerView(selection: $state.appearanceMode)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            
            Text("Current selection: **\(state.appearanceMode.rawValue)**")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .liquidGlass(cornerRadius: 14)
    }
    
    // MARK: - Tab 3: Weather & Clock
    @ViewBuilder
    private var weatherTabContent: some View {
        // Clock & Temperature Card
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("CLOCK & TEMPERATURE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Top-Right Header & Home Dashboard")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            
            Toggle(isOn: $weatherService.isTimeEnabled) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Show Local Time")
                        .font(.system(size: 12, weight: .medium))
                    Text("Display current time in the top-right header.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)
            
            if weatherService.isTimeEnabled {
                Picker("Time Format", selection: $weatherService.is24HourTime) {
                    Text("24-Hour (16:40)").tag(true)
                    Text("12-Hour (4:40 PM)").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.leading, 20)
            }
            
            Divider().opacity(0.3)
            
            Toggle(isOn: $weatherService.isWeatherEnabled) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Show Live Weather & Forecast")
                        .font(.system(size: 12, weight: .medium))
                    Text("Default: Off. Only requests Location permission when enabled with no saved locations.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)
            
            if weatherService.isWeatherEnabled {
                HStack {
                    Text("Temperature Unit")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Picker("", selection: $weatherService.temperatureUnit) {
                        Text("Celsius (°C)").tag(TemperatureUnit.celsius)
                        Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }
                .padding(.leading, 20)
                
                HStack {
                    Spacer()
                    Button(action: {
                        weatherService.fetchWeather()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Weather Now")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "1A73E8"))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 14)
        
        // Saved Locations Card (Up to 5)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SAVED LOCATIONS (UP TO 5)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("Switch quickly between locations right from the weather popover")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Text("\(weatherService.savedLocations.count)/\(WeatherService.maxLocationsCount) Locations")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: "1A73E8"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: "1A73E8").opacity(0.1)))
            }
            
            // Encrypted Vault Status Pill
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "34A853"))
                Text("Encrypted Local Location Vault • Persists across app updates")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "34A853").opacity(0.08)))
            
            // Saved Location Rows
            if weatherService.savedLocations.isEmpty {
                Text("No saved locations yet. Search for a city below or use your current GPS location.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(weatherService.savedLocations) { loc in
                        savedLocationRow(loc)
                    }
                }
            }
            
            // Search & GPS Add Section (when under max 5 limit)
            if weatherService.savedLocations.count < WeatherService.maxLocationsCount {
                Divider().opacity(0.3)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField("Search city (e.g. London, Tokyo, New York)...", text: $citySearchQuery)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                            .onSubmit {
                                weatherService.searchCities(query: citySearchQuery)
                            }
                        
                        Button("Search") {
                            weatherService.searchCities(query: citySearchQuery)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11.5, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(hex: "1A73E8")))
                        .foregroundStyle(.white)
                        .disabled(citySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        Button(action: {
                            weatherService.requestLocationAuthorization()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10.5))
                                Text("Use Current GPS")
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.primary.opacity(0.07)))
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if weatherService.isSearchingCities {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.65)
                                .frame(width: 14, height: 14)
                            Text("Searching cities...")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    } else if !weatherService.citySearchResults.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(weatherService.citySearchResults) { result in
                                citySearchResultRow(result)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 14)
    }
    
    private func savedLocationRow(_ loc: SavedWeatherLocation) -> some View {
        let isActive = weatherService.activeLocation?.id == loc.id
        return HStack(spacing: 10) {
            Image(systemName: loc.isCurrentGPS ? "location.circle.fill" : "mappin.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(isActive ? Color(hex: "1A73E8") : .secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(loc.name)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    if loc.isCurrentGPS {
                        Text("GPS")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Color.primary.opacity(0.07)))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(loc.subtitle.isEmpty ? String(format: "%.2f°, %.2f°", loc.latitude, loc.longitude) : loc.subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isActive {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                    Text("Active")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Color(hex: "0F9D58"))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(hex: "0F9D58").opacity(0.12)))
            } else {
                Button("Select") {
                    weatherService.selectLocation(id: loc.id)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(hex: "1A73E8")))
                .foregroundStyle(.white)
            }
            
            Button(action: {
                weatherService.removeLocation(id: loc.id)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.red.opacity(0.7))
                    .padding(6)
            }
            .buttonStyle(.plain)
            .help("Remove location")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? Color(hex: "1A73E8").opacity(0.06) : Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isActive ? Color(hex: "1A73E8").opacity(0.35) : Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
    
    private func citySearchResultRow(_ result: GeocodedCityResult) -> some View {
        let alreadySaved = weatherService.savedLocations.contains {
            abs($0.latitude - result.latitude) < 0.05 && abs($0.longitude - result.longitude) < 0.05
        }
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(result.name)
                    .font(.system(size: 12, weight: .semibold))
                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button(alreadySaved ? "Added" : "Add") {
                weatherService.addLocation(result)
                weatherService.citySearchResults = []
                citySearchQuery = ""
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(alreadySaved ? Color.primary.opacity(0.08) : Color(hex: "1A73E8").opacity(0.14)))
            .foregroundStyle(alreadySaved ? Color.secondary : Color(hex: "1A73E8"))
            .disabled(alreadySaved)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
    }
    
    // MARK: - Tab 4: Accounts & Profile
    @ViewBuilder
    private var accountsTabContent: some View {
        // Active Local Workspace Profile
        VStack(alignment: .leading, spacing: 14) {
            Text("WORKSPACE PROFILE (LOCAL ACCOUNT)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 14) {
                GoogleProfileAvatarView(
                    avatarData: state.userProfile.avatarImageData,
                    name: state.userProfile.displayName,
                    size: 52,
                    tier: state.userProfile.tier,
                    showEditButton: true,
                    action: { state.selectProfilePicture() }
                )
                .help("Click to change profile picture")
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.userProfile.displayName)
                        .font(.system(size: 15, weight: .bold))
                    
                    Text(state.userProfile.email.isEmpty ? "Local macOS Profile" : state.userProfile.email)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    Button(action: { state.selectProfilePicture() }) {
                        Text("Change Profile Picture...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(hex: "1A73E8"))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            
            Divider().opacity(0.3)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("First Name")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.primary)
                        TextField("First Name", text: Binding(
                            get: { state.userProfile.firstName },
                            set: { val in
                                state.userProfile.firstName = val
                                state.userProfile.name = "\(val) \(state.userProfile.lastName)".trimmingCharacters(in: .whitespaces)
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("Last Name")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("(Optional)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        TextField("Last Name", text: Binding(
                            get: { state.userProfile.lastName },
                            set: { val in
                                state.userProfile.lastName = val
                                state.userProfile.name = "\(state.userProfile.firstName) \(val)".trimmingCharacters(in: .whitespaces)
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Nickname")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("(Optional)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    TextField("Nickname", text: $state.userProfile.nickname)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }
                
                Toggle(isOn: $state.userProfile.useNickname) {
                    Text("I want my nickname to be used instead.")
                        .font(.system(size: 12, weight: .medium))
                }
                .toggleStyle(.checkbox)
                
                HStack {
                    Spacer()
                    Button("Clear & Reset Profile") {
                        state.userProfile = .empty
                        state.saveUserProfile()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 14)
        
        // Multi-Account Switcher (Up to 5 Accounts)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LOCAL ACCOUNTS (UP TO 5)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("Switch between up to 5 local accounts with separate sessions")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Text("\(state.accounts.count)/\(AppState.maxAccountsCount) Accounts")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: "1A73E8"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: "1A73E8").opacity(0.1)))
            }
            
            VStack(spacing: 8) {
                ForEach(state.accounts) { account in
                    let isActive = account.accountId == state.activeAccountId
                    HStack(spacing: 12) {
                        GoogleProfileAvatarView(
                            avatarData: account.avatarImageData,
                            name: account.displayName,
                            size: 34,
                            tier: account.tier,
                            showEditButton: false
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(account.displayName)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.primary)
                                
                                Text(account.accountLabel)
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1.5)
                                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text(account.email.isEmpty ? "No Google email configured" : account.email)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        if isActive {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                Text("Active")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(Color(hex: "0F9D58"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(hex: "0F9D58").opacity(0.12)))
                        } else {
                            Button(action: {
                                state.switchAccount(to: account.accountId)
                            }) {
                                Text("Switch")
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color(hex: "1A73E8")))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if state.accounts.count > 1 {
                            Button(action: {
                                state.removeAccount(accountId: account.accountId)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.red.opacity(0.7))
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                            .help("Remove this account")
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isActive ? Color(hex: "1A73E8").opacity(0.06) : Color.primary.opacity(0.02))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isActive ? Color(hex: "1A73E8").opacity(0.4) : Color.primary.opacity(0.05), lineWidth: 1)
                    )
                }
            }
            
            if state.accounts.count < AppState.maxAccountsCount {
                if state.isAddingNewAccount {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Add New Local Account")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Account Label")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            TextField("e.g. Work, School, Personal", text: $newAccountLabel)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11.5))
                        }
                        
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("First Name")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                TextField("First Name", text: $newAccountFirstName)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11.5))
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    Text("Last Name")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text("(Optional)")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                TextField("Last Name", text: $newAccountLastName)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11.5))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Text("Nickname")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text("(Optional)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            TextField("Nickname", text: $newAccountNickname)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11.5))
                        }
                        
                        Toggle(isOn: $newAccountUseNickname) {
                            Text("I want my nickname to be used instead.")
                                .font(.system(size: 11.5, weight: .medium))
                        }
                        .toggleStyle(.checkbox)
                        
                        HStack {
                            Button("Cancel") {
                                state.isAddingNewAccount = false
                                resetNewAccountFields()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Button("Add & Switch Account") {
                                state.addNewAccount(
                                    label: newAccountLabel,
                                    firstName: newAccountFirstName,
                                    lastName: newAccountLastName,
                                    nickname: newAccountNickname,
                                    useNickname: newAccountUseNickname
                                )
                                state.isAddingNewAccount = false
                                resetNewAccountFields()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11.5, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color(hex: "1A73E8")))
                            .foregroundStyle(.white)
                            .disabled(newAccountFirstName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.top, 4)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "1A73E8").opacity(0.3), lineWidth: 1))
                } else {
                    Button(action: {
                        state.isAddingNewAccount = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 12))
                            Text("Add Another Local Account (\(state.accounts.count)/\(AppState.maxAccountsCount))")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: "1A73E8"))
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 14)
    }
    
    // MARK: - Tab 5: Offline & Privacy
    @ViewBuilder
    private var offlineTabContent: some View {
        // Offline Workspace & Pre-downloaded Apps
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("OFFLINE WORKSPACE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                HStack(spacing: 5) {
                    Circle()
                        .fill(OfflineCacheService.shared.isPrewarming ? Color.orange : Color(hex: "0F9D58"))
                        .frame(width: 7, height: 7)
                    Text(OfflineCacheService.shared.isPrewarming ? "Syncing Cache..." : "Pre-downloaded & Offline Ready")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(OfflineCacheService.shared.isPrewarming ? Color.orange : Color(hex: "0F9D58"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill((OfflineCacheService.shared.isPrewarming ? Color.orange : Color(hex: "0F9D58")).opacity(0.1))
                )
            }
            
            Text("Google Docs & Google Slides offline compatibility is active in v1.3.1, with core Workspace apps pre-warmed in WebKit's persistent offline storage. Google Sheets offline compatibility arrives in v1.3.2.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
            
            Button(action: {
                OfflineCacheService.shared.prewarmOfflineCache()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: OfflineCacheService.shared.isPrewarming ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .rotationEffect(.degrees(OfflineCacheService.shared.isPrewarming ? 360 : 0))
                    Text(OfflineCacheService.shared.isPrewarming ? "Updating Cache..." : "Refresh Pre-downloaded Apps")
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color(hex: "1A73E8"))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color(hex: "1A73E8").opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(OfflineCacheService.shared.isPrewarming)
        }
        .padding(16)
        .liquidGlass(cornerRadius: 14)
        
        // Google Workspace Web Session Section
        VStack(alignment: .leading, spacing: 12) {
            Text("GOOGLE WEB APPS (DOCS, DRIVE, GMAIL)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            Text("Workspace apps run in a sandboxed WebKit browser session. Signing into Google inside any app (Docs, Sheets, Drive) keeps you logged in across all apps.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clear Google Session & Cookies")
                        .font(.system(size: 12, weight: .bold))
                    Text("Logs out of Google in all Workspace apps and resets web cookies.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showingClearCookiesAlert = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                        Text("Clear Web Cookies")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "EA4335"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "EA4335").opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            if cookiesClearedMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: "34A853"))
                    Text("Google cookies and sessions purged successfully.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "34A853"))
                }
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 14)
    }
    
    // MARK: - Tab 6: Updates & About
    @ViewBuilder
    private var updatesTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APP UPDATES")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workspace.mac v\(UpdateCheckerService.shared.currentVersion)")
                        .font(.system(size: 13, weight: .semibold))
                    Text(state.availableUpdate != nil ? "New update available!" : "Up to date with GitHub Releases.")
                        .font(.system(size: 11))
                        .foregroundStyle(state.availableUpdate != nil ? Color(hex: "D97706") : .secondary)
                }
                
                Spacer()
                
                if let update = state.availableUpdate {
                    Button("Download \(update.versionName)") {
                        NSWorkspace.shared.open(update.releaseUrl)
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color(hex: "D97706"))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                } else {
                    Button("Check for Updates") {
                        state.checkForUpdates()
                    }
                    .font(.system(size: 11.5, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 14)
        
        VStack(alignment: .leading, spacing: 10) {
            Text("RELEASE ROADMAP")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("v1.3.0")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("— Google Docs offline compatibility & OfflineSuite.mac")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text("v1.3.1")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("— Google Slides offline compatibility & idle power optimization")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text("v1.3.1.1 (Current)")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(Color(hex: "34A853"))
                    Text("— Fixes double-character typing glitch & multitasking split-screen loading")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text("v1.3.2")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(Color(hex: "1A73E8"))
                    Text("— Google Sheets offline compatibility & first-load reliability fixes")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 14)
    }
    
    // Mode Option Card helper
    private func modeOptionCard(mode: AppViewMode, title: String, subtitle: String) -> some View {
        let isSelected = state.appViewMode == mode
        return Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                state.appViewMode = mode
            }
        }) {
            VStack(spacing: 6) {
                ViewModeIcon(mode: mode, isSelected: isSelected)
                
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color(hex: "1A73E8") : Color.primary)
                
                Text(subtitle)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color(hex: "1A73E8").opacity(0.08) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color(hex: "1A73E8").opacity(0.6) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Isolated Leaf View for Repeating Animation (Zero Root Invalidation)
private struct PulsingGlanceEmblem: View {
    @State private var isPulsing: Bool = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "00A4F9"), Color(hex: "8B5CF6"), Color(hex: "F7646F")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
                .scaleEffect(isPulsing ? 1.15 : 0.95)
                .blur(radius: isPulsing ? 4 : 2)
            
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
