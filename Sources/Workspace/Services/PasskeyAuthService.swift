import Foundation
import LocalAuthentication

@MainActor
public final class PasskeyAuthService: ObservableObject {
    public static let shared = PasskeyAuthService()
    
    @Published public var isAuthenticating: Bool = false
    @Published public var lastAuthError: String? = nil
    
    public var isBiometricsAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    public var biometricTypeString: String {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        if #available(macOS 10.15, *) {
            switch context.biometryType {
            case .touchID:
                return "Touch ID"
            case .faceID:
                return "Face ID"
            case .opticID:
                return "Optic ID"
            case .none:
                return "Passkey / Mac Password"
            @unknown default:
                return "Passkey"
            }
        }
        return "Touch ID"
    }
    
    public func authenticateWithPasskey(
        reason: String = "Authenticate to securely access Google Workspace with your Passkey or Touch ID",
        completion: @escaping @Sendable @MainActor (Bool, String?) -> Void
    ) {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        
        isAuthenticating = true
        lastAuthError = nil
        
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication
        
        context.evaluatePolicy(policy, localizedReason: reason) { success, evalError in
            Task { @MainActor in
                self.isAuthenticating = false
                if success {
                    self.lastAuthError = nil
                    completion(true, nil)
                } else {
                    let msg = evalError?.localizedDescription ?? "Passkey verification canceled or failed"
                    self.lastAuthError = msg
                    completion(false, msg)
                }
            }
        }
    }
}
