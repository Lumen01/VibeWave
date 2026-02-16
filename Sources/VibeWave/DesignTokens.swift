import Foundation
import SwiftUI

public struct DesignTokens {
    public struct Colors {
        public static let settingsSectionIcon: Color = .accentColor
    }

    public struct Spacing {
        public static let xs: CGFloat = 4.0
        public static let s: CGFloat = 8.0  
        public static let m: CGFloat = 12.0
        public static let l: CGFloat = 16.0
        public static let large: CGFloat = 20.0
        public static let xl: CGFloat = 24.0
        public static let xxl: CGFloat = 32.0
    }
    
    public struct Radius {
        public static let small: CGFloat = 4.0
        public static let medium: CGFloat = 8.0
        public static let large: CGFloat = 12.0
    }
    
    public struct Typography {
        public static let kpiValue = Font.system(.title, design: .rounded).weight(.bold)
        public static let kpiTitle = Font.system(.caption, design: .rounded)
    }
}
