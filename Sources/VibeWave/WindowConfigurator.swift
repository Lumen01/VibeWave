import AppKit

public enum FixedWidthWindowConfigurator {
    public static let fixedWidth: CGFloat = 900
    public static let minHeight: CGFloat = 600

    public static func apply(to window: NSWindow) {
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: fixedWidth, height: minHeight)
        window.maxSize = NSSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude)
        window.resizeIncrements = NSSize(width: 1, height: 1)
    }
}
