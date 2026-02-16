import Foundation
import AppKit

public enum UpdateCheckResult {
    case upToDate
    case newVersionAvailable(release: GitHubRelease)
    case error(Error)
}

public struct GitHubRelease: Codable {
    public let tagName: String
    public let name: String
    public let body: String?
    public let htmlUrl: String
    public let publishedAt: String
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
    }
    
    public var version: String {
        tagName.replacingOccurrences(of: "v", with: "")
    }
}

public actor UpdateCheckService {
    public static let shared = UpdateCheckService()
    
    private let repository = "Lumen01/VibeWave"
    private let apiUrl = "https://api.github.com/repos/Lumen01/VibeWave/releases/latest"
    
    private init() {}
    
    public func checkForUpdates() async -> UpdateCheckResult {
        guard let url = URL(string: apiUrl) else {
            return .error(UpdateError.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .error(UpdateError.invalidResponse)
            }
            
            guard httpResponse.statusCode == 200 else {
                return .error(UpdateError.httpError(statusCode: httpResponse.statusCode))
            }
            
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let currentVersion = AppConfiguration.App.version
            let latestVersion = release.version
            
            if isNewerVersion(latest: latestVersion, current: currentVersion) {
                return .newVersionAvailable(release: release)
            } else {
                return .upToDate
            }
            
        } catch let decodingError as DecodingError {
            return .error(UpdateError.decodingError(decodingError))
        } catch {
            return .error(UpdateError.networkError(error))
        }
    }
    
    private func isNewerVersion(latest: String, current: String) -> Bool {
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(latestParts.count, currentParts.count)
        
        for i in 0..<maxLength {
            let latestPart = i < latestParts.count ? latestParts[i] : 0
            let currentPart = i < currentParts.count ? currentParts[i] : 0
            
            if latestPart > currentPart {
                return true
            } else if latestPart < currentPart {
                return false
            }
        }
        
        return false
    }
    
    public func openReleasePage(url: String) {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
    }
}

public enum UpdateError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError:
            return "Failed to parse response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
