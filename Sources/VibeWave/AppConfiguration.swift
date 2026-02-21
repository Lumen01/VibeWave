import Foundation
import AppKit

public enum AppConfiguration {
    public enum App {
        public static let name = "VibeWave"
        public static let identifier = "com.lumen.VibeWave"
        public static let version: String = {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        }()
        public static let build: String = {
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        }()
    }
    
    public enum BuildInfo {
        public static let buildNumber = 10005
        public static let buildDate = "2026-02-21 12:50:38"
        public static let gitCommit = "2649e05"
    }
    
    public enum Developer {
        public static let name = "Lumen"
        public static let copyright = "Copyright © 2026 Lumen. All rights reserved."
    }
    
    public enum Links {
        public static let github = URL(string: "https://github.com/Lumen01/VibeWave")!
        public static let githubRepository = "Lumen01/VibeWave"
        public static let twitter = URL(string: "https://x.com/byZh")!
    }
    
    public enum Support {
        public static func openGitHub() {
            NSWorkspace.shared.open(Links.github)
        }

        public static func openTwitter() {
            NSWorkspace.shared.open(Links.twitter)
        }
    }
}
