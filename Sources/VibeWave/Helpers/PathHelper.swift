import Foundation

/// Helper functions for path manipulation
public enum PathHelper {
    /// Extract the project name (last path component) from a full path
    /// For example: "/Users/lumen/projects/zt_server" -> "zt_server"
    public static func extractProjectName(from path: String?) -> String? {
        guard let path = path, !path.isEmpty else { return nil }

        // Remove all trailing slashes
        var trimmed = path
        while trimmed.hasSuffix("/") {
            trimmed = String(trimmed.dropLast())
        }

        guard !trimmed.isEmpty else { return nil }

        // Find the last slash
        guard let lastSlashIndex = trimmed.lastIndex(of: "/") else {
            // No slash found, the entire string is the project name
            return trimmed
        }

        // Get the substring after the last slash
        let projectName = String(trimmed[trimmed.index(after: lastSlashIndex)...])

        // Return nil if empty
        return projectName.isEmpty ? nil : projectName
    }
}
