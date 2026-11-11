import SwiftUI
import WebKit

public struct OnboardingView: View {
    @ObservedObject var state: AppState
    @State private var currentStep: Int = 1
    
    // Step 5 Pin search query
    @State private var pinSearchQuery: String = ""
    
    // Final Step soft text animation
    @State private var animateFinalText: Bool = false
    @State private var geminiGlowPulse: Bool = false
    
    private let geminiGradient = GeminiPalette.linearGradient
    
    public init(state: AppState) {
        self.state = state
    }
    
    public var body: some View {
        ZStack {
            // Background Liquid Glass ambient glows (Preserved exclusively for initial setup)
            ambientBackground
            
            VStack(spacing: 0) {
                // Top Step Progress Indicator (7 steps)
                topStepBar
                    .padding(.top, 24)
                    .padding(.horizontal, 36)
                
                Spacer()
                
                // Step Content (7 Steps)
                ZStack {
                    switch currentStep {
                    case 1:
                        step1WelcomeView
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))
                    case 2:
                        step2V1OverviewAndRoadmapView
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))
                    case 3:
                        step3CustomisationView
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))
                    case 4:
                        step4ProfileSetupView
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))
                    case 5:
                        step5PinAppsView
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))
                    case 6:
                        step6GoogleAuthGuideView
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))
                    case 7:
                        step7FinalView
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: 720, minHeight: 460)
                
                Spacer()
                
                // Bottom navigation controls
                bottomActionBar
                    .padding(.horizontal, 36)
                    .padding(.bottom, 28)
            }
        }
        .frame(minWidth: 780, minHeight: 600)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                geminiGlowPulse = true
            }
        }
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
    }
    
    // MARK: - Top Step Bar (7 steps)
    private var topStepBar: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { step in
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
    
    // MARK: - Step 1: Welcome Screen
    private var step1WelcomeView: some View {
        VStack(spacing: 20) {
            // Glowing Gemini / Workspace Emblem
            ZStack {
                Circle()
                    .fill(geminiGradient.opacity(0.2))
                    .frame(width: 90, height: 90)
                    .blur(radius: 16)
                    .scaleEffect(geminiGlowPulse ? 1.15 : 0.95)
                
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(geminiGradient, lineWidth: 2)
                    )
                    .shadow(color: GeminiPalette.blue.opacity(0.4), radius: 14)
                
                GeminiSparkleShape()
                    .fill(GeminiPalette.starGradient)
                    .frame(width: 42, height: 42)
            }
            .padding(.bottom, 8)
            
            VStack(spacing: 8) {
                Text("Hey! Welcome to Workspace.mac.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("Here, you'll find all your google workspace apps... but better!")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Feature Highlights
            HStack(spacing: 16) {
                featureHighlightPill(
                    icon: "sparkles",
                    title: "Gemini Integrated",
                    subtitle: "AI powered workflow",
                    color: GeminiPalette.blue
                )
                featureHighlightPill(
                    icon: "macwindow.on.rectangle",
                    title: "Workspace.mac Client",
                    subtitle: "Native macOS desktop experience",
                    color: Color(hex: "1A73E8")
                )
                featureHighlightPill(
                    icon: "lock.shield.fill",
                    title: "100% Free & Local",
                    subtitle: "Zero paywalls or fees",
                    color: Color(hex: "34A853")
                )
            }
            .padding(.top, 14)
        }
        .padding(28)
        .liquidGlass(cornerRadius: 24)
    }
    
    // MARK: - Step 2: Welcome to workspace.mac V1.0 (Release Highlights & Roadmap)
    private var step2V1OverviewAndRoadmapView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 5) {
                HStack(spacing: 6) {
                    GeminiSparkleShape()
                        .fill(GeminiPalette.starGradient)
                        .frame(width: 14, height: 14)
                    
                    Text("WORKSPACE.MAC V1.0 RELEASE")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(geminiGradient)
                        .tracking(1.0)
                }
                
                Text("Welcome to workspace.mac V1.0")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("Your native Google Workspace desktop client. Here's what's included in V1.0 and what's coming next.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Dual-card layout for V1.0 Features and Roadmap
            HStack(alignment: .top, spacing: 14) {
                // Card 1: What's made for V1.0
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "34A853"))
                        
                        Text("What's in V1.0")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 7) {
                            v1FeatureItem(
                                icon: "square.grid.3x3.fill",
                                title: "18 Google Workspace Apps",
                                description: "Docs, Sheets, Slides, Drive, Gmail, Meet, Keep, NotebookLM & more."
                            )
                            v1FeatureItem(
                                icon: "person.2.circle.fill",
                                title: "Dedicated 5-Account Switcher",
                                description: "Connect up to 5 isolated Google accounts with 1-click switching in the sidebar or settings."
                            )
                            v1FeatureItem(
                                icon: "sparkles",
                                title: "Gemini AI Integration",
                                description: "Dedicated Gemini AI assistant built right into your workspace."
                            )
                            v1FeatureItem(
                                icon: "macwindow.on.rectangle",
                                title: "3 Layout Immersion Modes",
                                description: "Everything, Essentials (top bar only), and 'At a glance' fullscreen."
                            )
                            v1FeatureItem(
                                icon: "circle.lefthalf.filled",
                                title: "True macOS Appearance",
                                description: "Light, Dark, and real-time Auto system theme detection."
                            )
                            v1FeatureItem(
                                icon: "person.crop.circle",
                                title: "Local Workspace Profile",
                                description: "Personalized greetings, nickname support, and custom avatar photos."
                            )
                            v1FeatureItem(
                                icon: "touchid",
                                title: "Google Passkey Support",
                                description: "Use your Mac Touch ID / Passkey directly inside Google for fast, secure sign-in."
                            )
                            v1FeatureItem(
                                icon: "lock.shield.fill",
                                title: "Sandboxed Web Session",
                                description: "Authentic Google login with unified session & 1-click cookie clear."
                            )
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(maxHeight: 230)
                }
                .padding(14)
                .liquidGlass(cornerRadius: 16, tintColor: Color(hex: "34A853"))
                
                // Card 2: Future Roadmap
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 13))
                            .foregroundStyle(GeminiPalette.blue)
                        
                        Text("Future Roadmap")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 7) {
                            roadmapItem(
                                icon: "key.fill",
                                color: Color(hex: "1A73E8"),
                                title: "Inbuilt App Google Login",
                                description: "Seamless persistent preference sync and single-click profile switching."
                            )
                            roadmapItem(
                                icon: "doc.text.fill",
                                color: Color(hex: "0F9D58"),
                                title: "Offline Document Caching",
                                description: "Local document drafts and offline access for on-the-go productivity."
                            )
                            roadmapItem(
                                icon: "command",
                                color: Color(hex: "8B5CF6"),
                                title: "Global Cmd+K Quick Switcher",
                                description: "Instant keyboard palette to launch apps and find documents in seconds."
                            )
                            roadmapItem(
                                icon: "rectangle.split.2x1.fill",
                                color: Color(hex: "F4B400"),
                                title: "Split-View Multitasking",
                                description: "Side-by-side editing: draft Docs while consulting Gemini AI."
                            )
                            roadmapItem(
                                icon: "menubar.rectangle",
                                color: Color(hex: "00A4F9"),
                                title: "Menu Bar Quick Companion",
                                description: "Instant access to Tasks, Calendar events, and new document shortcuts."
                            )
                            roadmapItem(
                                icon: "bolt.shield.fill",
                                color: Color(hex: "EA4335"),
                                title: "Continuous Speed & Stability",
                                description: "Memory footprint reduction, faster WebKit boots, and enhanced battery life."
                            )
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(maxHeight: 230)
                }
                .padding(14)
                .liquidGlass(cornerRadius: 16, tintColor: GeminiPalette.blue)
            }
        }
        .padding(24)
        .liquidGlass(cornerRadius: 24)
    }
    
    private func v1FeatureItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: "34A853"))
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 1)
    }
    
    private func roadmapItem(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 1)
    }
    
    private func featureHighlightPill(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)
            
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    // MARK: - Step 3: Customisation Screen
    private var step3CustomisationView: some View {
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
    
    // MARK: - Step 4: Local Profile Setup
    private var step4ProfileSetupView: some View {
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
    
    // MARK: - Step 5: Pin Your Favorite Apps
    private var step5PinAppsView: some View {
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
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(app.primaryColor.opacity(0.18))
                                    .frame(width: 32, height: 32)
                                Image(systemName: app.iconSymbol)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(app.primaryColor)
                            }
                            
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
    
    // MARK: - Step 6: Google Workspace Sign-In Guide
    private var step6GoogleAuthGuideView: some View {
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
    
    // MARK: - Step 7: Final Setup Screen
    private var step7FinalView: some View {
        VStack(spacing: 28) {
            // Animated Soft Pulsing Gemini Sparkle Orb
            ZStack {
                Circle()
                    .fill(geminiGradient.opacity(0.25))
                    .frame(width: 130, height: 130)
                    .blur(radius: 28)
                    .scaleEffect(animateFinalText ? 1.2 : 0.85)
                
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(geminiGradient, lineWidth: 2.5)
                    )
                    .shadow(color: GeminiPalette.blue.opacity(0.5), radius: 20)
                
                GeminiSparkleShape()
                    .fill(GeminiPalette.starGradient)
                    .frame(width: 52, height: 52)
                    .scaleEffect(animateFinalText ? 1.08 : 0.96)
            }
            
            // Letter-by-letter uprise animation with blur decay
            VStack(spacing: 12) {
                AnimatedUpriseBlurText(
                    "You're all setup!",
                    font: .system(size: 38, weight: .bold, design: .rounded),
                    gradient: GeminiPalette.linearGradient,
                    baseStaggerDelay: 0.032
                )
                
                Text("All your Google Workspace tools are ready locally in workspace.mac. Enjoy seamless collaboration!")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            
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
            .padding(.top, 10)
        }
        .padding(36)
        .liquidGlass(cornerRadius: 28, isHighlighted: true)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animateFinalText = true
            }
        }
    }
    
    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        HStack {
            if currentStep > 1 {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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
            
            if currentStep < 7 {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentStep += 1
                    }
                }) {
                    HStack(spacing: 6) {
                        Text(currentStep == 6 ? "Review Final Step" : "Continue")
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
