import AppKit
import Foundation

internal enum MenuBarIcon {
    internal static let targetSize = NSSize(width: 18, height: 18)

    internal static let image: NSImage = {
        if let url = Bundle.module.url(forResource: "menu-bar", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        
        let baseImage = Bundle.module.url(forResource: "bar", withExtension: "png")
            .flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: nil)
            ?? NSImage()
        
        return baseImage
    }()
}

private extension NSImage {
    func resizedToFit(_ targetSize: NSSize) -> NSImage {
        guard targetSize.width > 0, targetSize.height > 0 else { return self }

        let result = NSImage(size: targetSize)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: targetSize).fill()

        let sourceSize = size
        let widthScale = targetSize.width / max(sourceSize.width, 1)
        let heightScale = targetSize.height / max(sourceSize.height, 1)
        let scale = min(widthScale, heightScale)
        let drawSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let drawOrigin = NSPoint(
            x: (targetSize.width - drawSize.width) / 2,
            y: (targetSize.height - drawSize.height) / 2
        )

        draw(
            in: NSRect(origin: drawOrigin, size: drawSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )

        result.unlockFocus()
        return result
    }
}
