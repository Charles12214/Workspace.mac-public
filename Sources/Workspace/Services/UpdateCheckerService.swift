import Foundation
import AppKit

public struct AppUpdateInfo: Identifiable, Sendable {
    public var id: String { tagName }
    public let tagName: String
    public let versionName: String
    public let releaseUrl: URL
}

public final class UpdateCheckerService: ObservableObject, @unchecked Sendable {
    public static let shared = UpdateCheckerService()
    
    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0"
    }
    
    private let releasesApiUrl = URL(string: "https://api.github.com/repos/Charles12214/Workspace.mac-public/releases/latest")!
    
    public func checkForUpdates(completion: @escaping @Sendable (AppUpdateInfo?) -> Void) {
        var request = URLRequest(url: releasesApiUrl)
        request.setValue("Workspace.mac-App", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlUrlStr = json["html_url"] as? String,
                  let releaseUrl = URL(string: htmlUrlStr) else {
                completion(nil)
                return
            }
            
            let name = (json["name"] as? String) ?? tagName
            let cleanRemote = tagName.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "v \t\n\r"))
            let cleanCurrent = self.currentVersion.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "v \t\n\r"))
            
            if self.isVersion(cleanRemote, newerThan: cleanCurrent) {
                let updateInfo = AppUpdateInfo(tagName: tagName, versionName: name, releaseUrl: releaseUrl)
                completion(updateInfo)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    public func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(parts1.count, parts2.count)
        for i in 0..<maxCount {
            let num1 = i < parts1.count ? parts1[i] : 0
            let num2 = i < parts2.count ? parts2[i] : 0
            if num1 > num2 { return true }
            if num1 < num2 { return false }
        }
        return false
    }
}
