import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var pulseAtAGlance: Bool = false
    @State private var showingClearCookiesAlert: Bool = false
    @State private var cookiesClearedMessage: Bool = false
    @State private var passkeyFeedbackText: String? = nil
    @State private var passkeySuccess: Bool = false
    
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
                        HStack(spacing: 10) {
                            modeOptionCard(mode: .everything, title: "Everything", subtitle: "Sidebar + Top Bar")
                            modeOptionCard(mode: .essentials, title: "Essentials", subtitle: "Top Bar only")
                            modeOptionCard(mode: .minimalist, title: "Minimalist", subtitle: "'At a glance'")
                        }
                        
                        Divider().opacity(0.3)
                        
                        // "At a glance" Easter Egg Toggle Card with Repeating Pulse Animation
                        HStack(spacing: 12) {
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
                                    .scaleEffect(pulseAtAGlance ? 1.15 : 0.95)
                                    .blur(radius: pulseAtAGlance ? 4 : 2)
                                
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            
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
                                            Color(hex: "00A4F9").opacity(pulseAtAGlance ? 0.7 : 0.2),
                                            Color(hex: "8B5CF6").opacity(pulseAtAGlance ? 0.7 : 0.2)
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
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                            pulseAtAGlance = true
                        }
                    }
                    
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
                                    AiTierBadgeView(tier: state.userProfile.tier)
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
                            
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11))
                                    .foregroundStyle(GeminiPalette.blue)
                                Text("Greeting text: \"What's the groove, **\(state.userProfile.greetingName)**?\"")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 2)
                        }
                        
                        Divider().opacity(0.3)
                        
                        // Workspace Badge & AI Tier Selection
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 13))
                                    .foregroundStyle(GeminiPalette.linearGradient)
                                
                                Text("Workspace Plan & AI Badge")
                                    .font(.system(size: 13, weight: .bold))
                                
                                Spacer()
                                
                                AiTierBadgeView(tier: state.userProfile.tier)
                            }
                            
                            Picker("", selection: $state.userProfile.tier) {
                                Text("Google AI Pro").tag(SubscriptionTier.aiPro)
                                Text("Google AI Plus").tag(SubscriptionTier.aiPlus)
                                Text("Google AI Ultra").tag(SubscriptionTier.aiUltra)
                                Text("Personal (Free)").tag(SubscriptionTier.standard)
                            }
                            .pickerStyle(.segmented)
                            
                            Text(state.userProfile.tier.summaryText(name: state.userProfile.greetingName))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.03)))
                        
                        Divider().opacity(0.3)
                        
                        // Passkey Functionality
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.badge.key.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(hex: "1A73E8"))
                                
                                Text("Passkey & Biometrics")
                                    .font(.system(size: 12.5, weight: .bold))
                                
                                Spacer()
                                
                                if state.userProfile.hasPasskey {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color(hex: "34A853"))
                                        Text("Active")
                                            .font(.system(size: 10.5, weight: .semibold))
                                            .foregroundStyle(Color(hex: "34A853"))
                                    }
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color(hex: "34A853").opacity(0.12))
                                    .clipShape(Capsule())
                                } else {
                                    Text("Not Registered")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Text("Fast, passwordless sign-in using Touch ID and your Mac's secure enclave keychain.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 10) {
                                Button(action: {
                                    PasskeyAuthService.shared.authenticateWithPasskey(reason: "Verify your Passkey for Google Workspace") { success, error in
                                        if success {
                                            state.userProfile.hasPasskey = true
                                            passkeySuccess = true
                                            passkeyFeedbackText = "Passkey verified successfully via Touch ID!"
                                        } else {
                                            passkeySuccess = false
                                            passkeyFeedbackText = error ?? "Passkey verification canceled"
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                            passkeyFeedbackText = nil
                                        }
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "touchid")
                                            .font(.system(size: 12))
                                        Text(state.userProfile.hasPasskey ? "Test / Verify Touch ID" : "Register Passkey on this Mac")
                                            .font(.system(size: 11.5, weight: .semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: "1A73E8").opacity(0.12))
                                    .foregroundStyle(Color(hex: "1A73E8"))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                
                                if let feedback = passkeyFeedbackText {
                                    Text(feedback)
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(passkeySuccess ? Color(hex: "34A853") : Color(hex: "EA4335"))
                                        .transition(.opacity)
                                }
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.03)))
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
