import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject private var weatherService = WeatherService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingClearCookiesAlert: Bool = false
    @State private var cookiesClearedMessage: Bool = false
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
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(Color(hex: "1A73E8"))
                    Text("Workspace.mac Settings")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(Color(hex: "1A73E8"))
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Appearance Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("APPEARANCE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                        
                        AppearancePickerView(selection: $state.appearanceMode)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                    }
                    .padding(16)
                    .liquidGlass(cornerRadius: 14)
                    
                    // MARK: - App Viewing Mode & "At a glance" Easter Egg
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
                        
                        // Mode Selector Row
                        HStack(spacing: 8) {
                            modeOptionCard(mode: .everything, title: "Everything", subtitle: "Sidebar + Top Bar")
                            modeOptionCard(mode: .essentials, title: "Essentials", subtitle: "Top Bar only")
                            modeOptionCard(mode: .minimalist, title: "Minimalist", subtitle: "'At a glance'")
                            modeOptionCard(mode: .separated, title: "Separated Apps", subtitle: "Separate window")
                        }
                        
                        Divider().opacity(0.3)
                        
                        // "At a glance" Easter Egg Toggle Card with Isolated Pulse Animation
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
                    
                    // MARK: - Live Weather & Local Time Widget Section
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("WEATHER & LOCAL CLOCK")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Top-Right Header Widget")
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
                                Text("Displays current temperature and weather conditions with interactive forecast popover.")
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
                                .frame(width: 180)
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
                    
                    // Home Screen Tile Customisation
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
                    
                    // MARK: - Dedicated Multi-Account Switcher (Up to 5 Accounts)
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
                        
                        // Accounts List
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
                        
                        // Add Account Area
                        if state.accounts.count < AppState.maxAccountsCount {
                            if state.isAddingNewAccount {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Add New Local Account")
                                        .font(.system(size: 12.5, weight: .bold))
                                        .foregroundStyle(.primary)
                                    
                                    // Label
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Account Label")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                        TextField("e.g. Work, School, Personal", text: $newAccountLabel)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(size: 11.5))
                                    }
                                    
                                    // First Name & Last Name
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
                                    
                                    // Nickname
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
                    
                    // Local Workspace Profile Section
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
                                HStack(spacing: 8) {
                                    Text(state.userProfile.displayName)
                                        .font(.system(size: 15, weight: .bold))
                                }
                                
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
                        
                        // Name Personalization for Greetings
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
                        
                        Text("Core Google Workspace web applications (Docs, Sheets, Slides, Drive, Keep, Calendar, and NotebookLM) are pre-warmed and stored in WebKit's persistent offline storage for fast loading and offline editing.")
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
                    
                    // App Updates Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("APP UPDATES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Workspace.mac v\(UpdateCheckerService.shared.currentVersion)")
                                    .font(.system(size: 12.5, weight: .semibold))
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
                    
                    // Reset / Re-run Setup Wizard
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SETUP WIZARD")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                        
                        Button(action: {
                            state.resetSetup()
                            dismiss()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Re-run Initial Setup Wizard")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "EA4335"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color(hex: "EA4335").opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .liquidGlass(cornerRadius: 14)
                }
                .padding(20)
            }
        }
        .frame(width: 530, height: 640)
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
