import SwiftUI
import WebKit
import CoreLocation

public struct OnboardingView: View {
    @ObservedObject var state: AppState
    @ObservedObject private var weatherService = WeatherService.shared
    @State private var currentStep: Int = 1
    
    // Directional Carousel Navigation
    private enum CarouselDirection {
        case forward
        case backward
    }
    @State private var carouselDirection: CarouselDirection = .forward
    
    // Step 6 Pin search query
    @State private var pinSearchQuery: String = ""
    
    private let geminiGradient = GeminiPalette.linearGradient
    
    public init(state: AppState) {
        self.state = state
    }
    
    public var body: some View {
        ZStack {
            // Background Liquid Glass ambient glows (Preserved exclusively for initial setup)
            ambientBackground
            
            VStack(spacing: 0) {
                // Top Step Progress Indicator (8 steps)
                topStepBar
                    .padding(.top, 24)
                    .padding(.horizontal, 36)
                
                Spacer()
                
                // Step Content Carousel (8 Steps, True Bidirectional Carousel)
                ZStack {
                    stepContent(for: currentStep)
                        .id(currentStep)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: carouselDirection == .forward ? .trailing : .leading).combined(with: .opacity),
                                removal: .move(edge: carouselDirection == .forward ? .leading : .trailing).combined(with: .opacity)
                            )
                        )
                }
                .frame(maxWidth: 720, minHeight: 480)
                .clipped()
                
                Spacer()
                
                // Bottom navigation controls
                bottomActionBar
                    .padding(.horizontal, 36)
                    .padding(.bottom, 28)
            }
        }
        .frame(minWidth: 780, minHeight: 620)
    }
    
    // MARK: - Ambient Background
    private var ambientBackground: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            
            Circle()
                .fill(Color(hex: "4285F4").opacity(0.12))
                .frame(width: 500, height: 500)
                .blur(radius: 120)
                .offset(x: -200, y: -150)
            
            Circle()
                .fill(GeminiPalette.blue.opacity(0.12))
                .frame(width: 450, height: 450)
                .blur(radius: 110)
                .offset(x: 220, y: -100)
            
            Circle()
                .fill(GeminiPalette.yellow.opacity(0.10))
                .frame(width: 380, height: 380)
                .blur(radius: 90)
                .offset(x: 150, y: 220)
        }
        .drawingGroup()
    }
    
    // MARK: - Top Step Bar (8 steps)
    private var topStepBar: some View {
        HStack(spacing: 8) {
            ForEach(1...8, id: \.self) { step in
                Capsule()
                    .fill(
                        step <= currentStep
                            ? Color(hex: "4B5563")
                            : Color.primary.opacity(0.12)
                    )
                    .frame(height: 4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
            }
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Step Router
    @ViewBuilder
    private func stepContent(for step: Int) -> some View {
        switch step {
        case 1:
            step1WelcomeView
        case 2:
            step2PrivacyView
        case 3:
            step3WeatherSetupView
        case 4:
            step4CustomisationView
        case 5:
            step5ProfileSetupView
        case 6:
            step6PinAppsView
        case 7:
            step7GoogleAuthGuideView
        case 8:
            step8FinalView
        default:
            EmptyView()
        }
    }
    
    // MARK: - Step 1: Welcome Screen
    private var step1WelcomeView: some View {
        VStack(spacing: 16) {
            // Workspace App Icon Emblem (Isolated Animation)
            WelcomePulsingEmblem()
                .padding(.bottom, 2)
            
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10.5, weight: .bold))
                    Text("WHAT'S NEW IN V1.3.1")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                }
                .foregroundStyle(Color(hex: "1A73E8"))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(hex: "1A73E8").opacity(0.12)))
                
                Text("Hey! Welcome to Workspace.mac.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("All 18 Google Workspace apps & Gemini in one fast, private, open-source macOS client.")
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // V1.3.0 Feature Highlights (2x2 Grid)
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                featureHighlightPill(
                    icon: "bolt.shield.fill",
                    title: "OfflineSuite.mac",
                    subtitle: "Edit Google Docs & Slides offline & auto-sync in place",
                    color: Color(hex: "34A853")
                )
                featureHighlightPill(
                    icon: "cloud.sun.rain.fill",
                    title: "Dynamic Atmosphere",
                    subtitle: "Live weather-reactive animated Home skies",
                    color: Color(hex: "FF9500")
                )
                featureHighlightPill(
                    icon: "lock.shield.fill",
                    title: "Encrypted Location Vault",
                    subtitle: "Save up to 5 cities privately with AES-GCM",
                    color: Color(hex: "1A73E8")
                )
                featureHighlightPill(
                    icon: "macwindow.on.rectangle",
                    title: "Custom Home & Groups",
                    subtitle: "Collapsible sections, split tiling, & Tabbed Settings",
                    color: GeminiPalette.blue
                )
            }
            .padding(.top, 6)
        }
        .padding(26)
        .liquidGlass(cornerRadius: 24)
    }
    
    // MARK: - Step 2: Dedicated Privacy Screen (Zero Trackers & Local Security)
    private var step2PrivacyView: some View {
        VStack(spacing: 18) {
            // Shield & Lock Emblem
            ZStack {
                Circle()
                    .fill(Color(hex: "34A853").opacity(0.18))
                    .frame(width: 78, height: 78)
                    .blur(radius: 16)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "34A853"), Color(hex: "4285F4")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(hex: "34A853").opacity(0.3), radius: 10, y: 4)
            }
            .padding(.bottom, 2)
            
            VStack(spacing: 5) {
                Text("Privacy by Design. Zero Trackers.")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("Workspace.mac is built with 100% local privacy. What you do on your Mac stays on your Mac.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 580)
            }
            
            // 3 Clean Reassurance Pillars
            VStack(spacing: 10) {
                privacyPillarRow(
                    icon: "eye.slash.fill",
                    color: Color(hex: "8B5CF6"),
                    title: "Zero Telemetry or Trackers",
                    description: "No Google Analytics, no crash uploaders, and no background telemetry pings. We collect 0 bytes of your personal activity, search queries, or keystrokes."
                )
                
                privacyPillarRow(
                    icon: "internaldrive.fill",
                    color: Color(hex: "34A853"),
                    title: "Sandboxed Apple WebKit Storage",
                    description: "Your Google session cookies, authentication tokens, and cached documents remain strictly inside macOS's native sandboxed storage."
                )
                
                privacyPillarRow(
                    icon: "network.badge.shield.half.filled",
                    color: Color(hex: "1A73E8"),
                    title: "Direct Official Google Endpoints",
                    description: "All connections route directly to Google's official servers over end-to-end TLS encryption. Zero intermediary proxy servers."
                )
            }
            .padding(16)
            .liquidGlass(cornerRadius: 18, tintColor: Color(hex: "34A853"))
            
            // Bottom guarantee pill
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color(hex: "34A853"))
                    .font(.system(size: 13))
                
                Text("Verified 100% local desktop client • Zero telemetry • No account or payment required")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.primary.opacity(0.04)))
        }
        .padding(26)
        .liquidGlass(cornerRadius: 24)
    }
    
    private func privacyPillarRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.16))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Step 3: Optional Ambient Weather & Local Clock
    private var step3WeatherSetupView: some View {
        VStack(spacing: 16) {
            // Weather Icon Header
            ZStack {
                Circle()
                    .fill(Color(hex: "FF9500").opacity(0.18))
                    .frame(width: 78, height: 78)
                    .blur(radius: 16)
                
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 42))
                    .symbolRenderingMode(.multicolor)
                    .shadow(color: Color(hex: "FF9500").opacity(0.3), radius: 10, y: 4)
            }
            .padding(.bottom, 2)
            
            VStack(spacing: 5) {
                Text("Ambient Weather & Local Time (Optional)")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("Glance at real-time weather and local time right on your Home dashboard and top bar.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Live Preview Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("LIVE WIDGET PREVIEW")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)
                    
                    Spacer()
                    
                    if weatherService.isWeatherEnabled {
                        Text(weatherService.detectedCity)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack(spacing: 14) {
                    if weatherService.isWeatherEnabled {
                        if let info = weatherService.weatherInfo {
                            HStack(spacing: 7) {
                                Image(systemName: info.symbolName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(WeatherService.symbolColor(for: info.symbolName))
                                
                                Text("\(info.formattedTemp)\(weatherService.temperatureUnit.symbol)")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                
                                Text("• \(info.conditionName)")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(.secondary)
                            }
                        } else if weatherService.isLoadingWeather {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.65)
                                    .frame(width: 14, height: 14)
                                Text("Fetching forecast...")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "location.circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                Text("Awaiting location access")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Text("Weather Widget Disabled")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if weatherService.isTimeEnabled {
                        HStack(spacing: 5) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text(weatherService.currentTimeString)
                                .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 1))
            }
            
            // Settings & Toggles Card
            VStack(alignment: .leading, spacing: 12) {
                // Master Toggle
                Toggle(isOn: $weatherService.isWeatherEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Ambient Weather")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("If switched off, weather will not show on the top bar or home screen.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                
                if weatherService.isWeatherEnabled {
                    Divider().opacity(0.3)
                    
                    // Location & Zero Trackers Explanation
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "1A73E8"))
                                .padding(.top, 1)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Requires macOS Location Permission")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.primary)
                                
                                Text("Used strictly on your Mac to fetch weather from Open-Meteo. Coordinates stay in your encrypted local vault so updates won't re-prompt.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(1.5)
                            }
                        }
                        
                        // Location Action Button / Status
                        HStack {
                            if weatherService.activeLocation != nil || weatherService.isLocationAuthorized {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color(hex: "34A853"))
                                        Text("Saved Location: \(weatherService.activeLocation?.name ?? weatherService.detectedCity)")
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .foregroundStyle(Color(hex: "34A853"))
                                    }
                                    Text("Stored in your encrypted local vault so app updates won't re-prompt.")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Button(action: {
                                    weatherService.requestLocationAuthorization()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "location.circle.fill")
                                            .font(.system(size: 11.5))
                                        Text("Request Location Permission")
                                            .font(.system(size: 11.5, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color(hex: "1A73E8")))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Spacer()
                            
                            // Pickers with hidden native labels to prevent vertical letter wrapping
                            HStack(spacing: 12) {
                                HStack(spacing: 6) {
                                    Text("Unit")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                    
                                    Picker("", selection: $weatherService.temperatureUnit) {
                                        ForEach(TemperatureUnit.allCases) { unit in
                                            Text(unit.symbol).tag(unit)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .labelsHidden()
                                    .frame(width: 76)
                                }
                                .fixedSize(horizontal: true, vertical: false)
                                
                                HStack(spacing: 6) {
                                    Text("Time")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                    
                                    Picker("", selection: $weatherService.is24HourTime) {
                                        Text("12h").tag(false)
                                        Text("24h").tag(true)
                                    }
                                    .pickerStyle(.segmented)
                                    .labelsHidden()
                                    .frame(width: 80)
                                }
                                .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    Divider().opacity(0.3)
                    
                    Toggle(isOn: $state.isWeatherAtmosphereEnabled) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Dynamic Weather Atmosphere Background")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("Subtle animated glow, clouds, rain, snow, or frost on Home matching your weather (save up to 5 locations in Settings).")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
            }
            .padding(14)
            .liquidGlass(cornerRadius: 18, tintColor: Color(hex: "FF9500"))
            
            // Bottom reassurance note
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(Color(hex: "1A73E8"))
                    .font(.system(size: 12))
                
                Text("Completely optional • Encrypted local vault • Customize atmosphere & up to 5 locations anytime in Settings")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .liquidGlass(cornerRadius: 24)
    }
    
    private func featureHighlightPill(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.14))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    // MARK: - Step 4: Customisation Screen
    private var step4CustomisationView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Select Appearance")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                
                Text("Choose how Workspace looks on your Mac. You can always change this in Settings.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            
            // Professional Vector Replica (No screenshot artifacts)
            AppearancePickerView(selection: $state.appearanceMode)
                .padding(.vertical, 12)
            
            HStack(spacing: 8) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "FF9500"))
                
                Text("Current selection: **\(state.appearanceMode.rawValue)** mode")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.primary.opacity(0.04)))
        }
        .padding(32)
        .liquidGlass(cornerRadius: 24)
    }
    
    // MARK: - Step 5: Local Profile Setup
    private var step5ProfileSetupView: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text("Set Up Your Profile")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                
                Text("Personalize your local Workspace.mac client. All profile data stays on your Mac.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Avatar & Name Card
            VStack(spacing: 16) {
                // Avatar preview with button
                HStack(spacing: 16) {
                    GoogleProfileAvatarView(
                        avatarData: state.userProfile.avatarImageData,
                        name: state.userProfile.displayName,
                        size: 64,
                        tier: state.userProfile.tier,
                        showEditButton: true,
                        action: { state.selectProfilePicture() }
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.userProfile.displayName)
                            .font(.system(size: 16, weight: .bold))
                        
                        Text("Click photo to change avatar")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        
                        Button(action: { state.selectProfilePicture() }) {
                            Text("Choose Profile Picture...")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(Color(hex: "1A73E8"))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                    
                    Spacer()
                }
                
                Divider().opacity(0.3)
                
                // Name Fields
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("First Name")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        TextField("First name", text: Binding(
                            get: { state.userProfile.firstName },
                            set: { val in
                                state.userProfile.firstName = val
                                state.userProfile.name = "\(val) \(state.userProfile.lastName)".trimmingCharacters(in: .whitespaces)
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 4) {
                            Text("Last Name")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("(Optional)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        
                        TextField("Last name", text: Binding(
                            get: { state.userProfile.lastName },
                            set: { val in
                                state.userProfile.lastName = val
                                state.userProfile.name = "\(state.userProfile.firstName) \(val)".trimmingCharacters(in: .whitespaces)
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                    }
                }
                
                // Nickname & Checkbox
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 4) {
                            Text("Nickname")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("(Optional)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        
                        TextField("e.g. Alex, Ace, Boss", text: $state.userProfile.nickname)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                    }
                    
                    Toggle(isOn: $state.userProfile.useNickname) {
                        Text("I want my nickname to be used instead.")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    .toggleStyle(.checkbox)
                }
            }
            .padding(20)
            .liquidGlass(cornerRadius: 18)
            
            // Live Greeting Preview
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(GeminiPalette.blue)
                
                Text("Greeting preview:")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text("\"What's the groove, **\(state.userProfile.greetingName)**?\"")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.primary.opacity(0.04)))
        }
        .padding(32)
        .liquidGlass(cornerRadius: 24)
    }
    
    // MARK: - Step 6: Pin Your Favorite Apps
    private var step6PinAppsView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Pin Your Favorite Apps")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                
                Text("Choose the Google Workspace apps you use most for instant access.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
            }
            
            // Search Bar for pins
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                TextField("Search apps to pin...", text: $pinSearchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !pinSearchQuery.isEmpty {
                    Button(action: { pinSearchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
            
            // Scrollable List of Apps with pin checkboxes
            ScrollView {
                LazyVStack(spacing: 6) {
                    let filtered = pinSearchQuery.isEmpty ? state.apps : state.apps.filter {
                        $0.name.localizedCaseInsensitiveContains(pinSearchQuery) ||
                        $0.category.rawValue.localizedCaseInsensitiveContains(pinSearchQuery)
                    }
                    
                    ForEach(filtered) { app in
                        HStack(spacing: 12) {
                            GoogleAppIconView(appId: app.id, size: 30)
                                .frame(width: 32, height: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(app.category.rawValue)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                state.togglePin(appId: app.id)
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: app.isPinned ? "pin.fill" : "pin")
                                        .font(.system(size: 12))
                                    Text(app.isPinned ? "Pinned" : "Pin")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(app.isPinned ? Color.white : Color.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule().fill(app.isPinned ? Color(hex: "F4B400") : Color.primary.opacity(0.08))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.02)))
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxHeight: 220)
            
            HStack {
                Text("\(state.pinnedApps.count) apps pinned to Home")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 6)
        }
        .padding(26)
        .liquidGlass(cornerRadius: 24)
    }
    
    // MARK: - Step 7: Google Workspace Sign-In Guide
    private var step7GoogleAuthGuideView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Google Workspace Sign-In")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                
                Text("How your Google account connects with Workspace apps")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 14) {
                // Header with Google G Logo
                HStack(spacing: 12) {
                    GoogleGLogo(size: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Direct & Authentic Google Sign-In")
                            .font(.system(size: 14, weight: .bold))
                        Text("No fake OAuth or third-party credential interception.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                Divider().opacity(0.3)
                
                // Explanatory bullets
                VStack(alignment: .leading, spacing: 12) {
                    guideBulletRow(
                        icon: "lock.shield.fill",
                        color: Color(hex: "34A853"),
                        title: "Official Google Authentication",
                        description: "When you open Docs, Drive, or Gmail, you sign into Google directly on Google's official login screen. Passwords and 2FA are handled 100% securely by Google."
                    )
                    
                    guideBulletRow(
                        icon: "macwindow.on.rectangle",
                        color: Color(hex: "1A73E8"),
                        title: "Single Sign-In for All Apps",
                        description: "Because Workspace.mac shares a sandboxed WebKit data store, logging into Google in one app keeps you logged in across Sheets, Slides, Drive, and Gmail."
                    )
                    
                    guideBulletRow(
                        icon: "person.2.circle.fill",
                        color: Color(hex: "00A4F9"),
                        title: "Up to 5 Dedicated Google Accounts",
                        description: "Add up to 5 separate Google accounts (Work, Personal, School). Each account runs in an isolated container so all accounts stay signed in without logging out."
                    )
                    
                    guideBulletRow(
                        icon: "sparkles",
                        color: Color(hex: "8B5CF6"),
                        title: "Gemini Workspace Ready",
                        description: "Gemini features and Google Workspace access work seamlessly once logged into Google in the app window."
                    )
                }
            }
            .padding(18)
            .liquidGlass(cornerRadius: 18, tintColor: Color(hex: "1A73E8"))
            
            // Bottom reassurance note
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: "34A853"))
                    .font(.system(size: 12))
                
                Text("You're all set! You can log into Google whenever you launch an app from Home.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(30)
        .liquidGlass(cornerRadius: 24)
    }
    
    private func guideBulletRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(color)
                .frame(width: 22, height: 22)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
    }
    
    // MARK: - Step 8: Final Setup Screen
    private var step8FinalView: some View {
        VStack(spacing: 20) {
            // Animated Soft Pulsing Workspace App Icon (Isolated Animation)
            FinalePulsingEmblem()
            
            // Sentence-level smooth gradient animation with blur decay
            VStack(spacing: 10) {
                AnimatedUpriseBlurText(
                    "You're all setup!",
                    font: .system(size: 36, weight: .bold, design: .rounded),
                    gradient: GeminiPalette.linearGradient,
                    baseStaggerDelay: 0.032
                )
                
                Text("All your Google Workspace tools are ready locally in Workspace.mac. Enjoy seamless collaboration!")
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
            
            // V1.3.0 Release Highlights & Roadmap Card
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "1A73E8"))
                    
                    Text("V1.3.1 HIGHLIGHTS & ROADMAP")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)
                    
                    Spacer()
                    
                    Text("Open Settings with ⌘,")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: "1A73E8"))
                }
                
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ready in v1.3.1")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(Color(hex: "34A853"))
                        Text("• OfflineSuite.mac offline Docs & Slides auto-sync\n• Minute-aligned low-power idle & paused background skies\n• Encrypted 5-city weather vault & collapsible Home")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider().frame(height: 54).opacity(0.3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Up Next on Roadmap")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(GeminiPalette.blue)
                        Text("• v1.3.2 — Google Sheets offline compatibility & first-load fixes\n• Offline Drive folder smart-sync & Gemini actions")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.035)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))
            .frame(maxWidth: 560)
            
            // Pill blue button: "Lets Go! ->"
            Button(action: {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    state.hasCompletedSetup = true
                }
            }) {
                HStack(spacing: 8) {
                    Text("Lets Go! ->")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 36)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "1A73E8"), Color(hex: "4285F4")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1.2)
                )
                .shadow(color: Color(hex: "1A73E8").opacity(0.45), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(28)
        .liquidGlass(cornerRadius: 28, isHighlighted: true)
    }
    
    // MARK: - Bottom Action Bar (Bidirectional Carousel Direction)
    private var bottomActionBar: some View {
        HStack {
            if currentStep > 1 {
                Button(action: {
                    carouselDirection = .backward
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        currentStep -= 1
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                        Text("Back")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            if currentStep < 8 {
                Button(action: {
                    carouselDirection = .forward
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        currentStep += 1
                    }
                }) {
                    HStack(spacing: 6) {
                        Text(currentStep == 7 ? "Review Final Step" : "Continue")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(Color(hex: "1A73E8"))
                    )
                    .shadow(color: Color(hex: "1A73E8").opacity(0.3), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Isolated Emblem Leaf Views (Zero Parent Invalidation)
private struct WelcomePulsingEmblem: View {
    @State private var isPulsing: Bool = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.18))
                .frame(width: 96, height: 96)
                .blur(radius: 16)
                .scaleEffect(isPulsing ? 1.10 : 0.95)
            
            if let logoImg = AppIconAssetLoader.shared.image(for: "workspace") ?? AppIconAssetLoader.shared.image(for: "workspace_icon") {
                Image(nsImage: logoImg)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 82, height: 82)
                    .shadow(color: Color.black.opacity(0.25), radius: 14, y: 5)
            } else {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 14)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

private struct FinalePulsingEmblem: View {
    @State private var isPulsing: Bool = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.22))
                .frame(width: 130, height: 130)
                .blur(radius: 28)
                .scaleEffect(isPulsing ? 1.15 : 0.90)
            
            if let logoImg = AppIconAssetLoader.shared.image(for: "workspace") ?? AppIconAssetLoader.shared.image(for: "workspace_icon") {
                Image(nsImage: logoImg)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .shadow(color: Color.black.opacity(0.3), radius: 18, y: 6)
                    .scaleEffect(isPulsing ? 1.05 : 0.97)
            } else {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: 2.5)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 20)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
