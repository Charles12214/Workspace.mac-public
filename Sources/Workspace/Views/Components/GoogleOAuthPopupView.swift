import SwiftUI
import WebKit

public struct GoogleOAuthPopupView: View {
    @ObservedObject var state: AppState
    @Binding var isPresented: Bool
    var onLoginSuccess: (() -> Void)? = nil
    
    @State private var emailInput: String = ""
    @State private var nameInput: String = ""
    @State private var selectedTab: Int = 0 // 0: Google Sign-In Form, 1: accounts.google.com Web Sign-In
    @State private var passkeyFeedback: String? = nil
    @State private var isSigningIn: Bool = false
    
    public init(state: AppState, isPresented: Binding<Bool>, onLoginSuccess: (() -> Void)? = nil) {
        self.state = state
        self._isPresented = isPresented
        self.onLoginSuccess = onLoginSuccess
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Popup Top Header
            HStack(spacing: 10) {
                GoogleGLogo(size: 22)
                Text("Google Sign-In (OAuth)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Mode Selector: "Credentials" vs "Google Web Sign-In"
            Picker("", selection: $selectedTab) {
                Text("Account Credentials").tag(0)
                Text("Google Web Form").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            
            if selectedTab == 0 {
                // MARK: - Direct Account Sign-In Form
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sign in to your Google Account")
                                .font(.system(size: 16, weight: .bold))
                            Text("Enter the Google email for your workspace (main account or sub-account).")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email Address")
                                .font(.system(size: 11, weight: .semibold))
                            
                            TextField("e.g. subaccount@gmail.com or work@company.com", text: $emailInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 13))
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Full Name (Optional)")
                                .font(.system(size: 11, weight: .semibold))
                            
                            TextField("e.g. Alex Smith", text: $nameInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 13))
                        }
                        
                        VStack(spacing: 10) {
                            // Continue with Google Button
                            Button(action: {
                                submitLogin(usePasskey: false)
                            }) {
                                HStack(spacing: 8) {
                                    if isSigningIn {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        GoogleGLogo(size: 16)
                                    }
                                    Text("Sign In with Google")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(hex: "1A73E8"))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .shadow(color: Color(hex: "1A73E8").opacity(0.3), radius: 6, y: 2)
                            }
                            .buttonStyle(.plain)
                            .disabled(emailInput.trimmingCharacters(in: .whitespaces).isEmpty)
                            
                            // Sign In with Passkey / Touch ID
                            Button(action: {
                                submitLogin(usePasskey: true)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "touchid")
                                        .font(.system(size: 14))
                                    Text("Sign In with Passkey / Touch ID")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(hex: "8B5CF6").opacity(0.12))
                                .foregroundStyle(Color(hex: "8B5CF6"))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color(hex: "8B5CF6").opacity(0.4), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(emailInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.top, 4)
                        
                        if let fb = passkeyFeedback {
                            Text(fb)
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "EA4335"))
                        }
                        
                        Divider().opacity(0.3)
                        
                        // System browser link
                        Button(action: {
                            if let url = URL(string: "https://accounts.google.com/ServiceLogin") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right.square")
                                Text("Open Google Sign-In in Default Browser")
                                    .font(.system(size: 11.5))
                            }
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                }
            } else {
                // MARK: - Live Google Web Sign-In (accounts.google.com)
                VStack(spacing: 0) {
                    OAuthWebViewRepresentable()
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Signed into your Google Account?")
                                .font(.system(size: 11, weight: .bold))
                            Text("Click Done to complete Workspace sign-in.")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Done & Apply Account") {
                            let email = emailInput.trimmingCharacters(in: .whitespaces).isEmpty ? "user@example.com" : emailInput
                            state.loginWithAccount(name: nameInput, email: email, usePasskey: false) {
                                onLoginSuccess?()
                                isPresented = false
                            }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color(hex: "1A73E8"))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color(nsColor: .windowBackgroundColor))
                }
            }
        }
        .frame(width: 500, height: 560)
        .onAppear {
            if !state.userProfile.email.isEmpty {
                emailInput = state.userProfile.email
                nameInput = state.userProfile.name
            }
        }
    }
    
    private func submitLogin(usePasskey: Bool) {
        let email = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return }
        
        if usePasskey {
            PasskeyAuthService.shared.authenticateWithPasskey(reason: "Sign in to \(email) with Passkey / Touch ID") { success, error in
                if success {
                    state.loginWithAccount(name: nameInput, email: email, usePasskey: true) {
                        onLoginSuccess?()
                        isPresented = false
                    }
                } else {
                    passkeyFeedback = error ?? "Passkey verification canceled"
                }
            }
        } else {
            isSigningIn = true
            state.loginWithAccount(name: nameInput, email: email, usePasskey: false) {
                isSigningIn = false
                onLoginSuccess?()
                isPresented = false
            }
        }
    }
}

// Dedicated WebView for OAuth login using genuine Safari User-Agent
public struct OAuthWebViewRepresentable: NSViewRepresentable {
    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        let wv = WKWebView(frame: .zero, configuration: config)
        // Authentic Safari User-Agent prevents "This browser or app may not be secure"
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"
        
        let url = URL(string: "https://accounts.google.com/ServiceLogin")!
        wv.load(URLRequest(url: url))
        return wv
    }
    
    public func updateNSView(_ nsView: WKWebView, context: Context) {}
}
