import Foundation
import SwiftUI
import AppKit

public struct TitleBarSegmentedControlMatcher: NSViewRepresentable {
    private let sourceSegmentCount: Int

    public init(sourceSegmentCount: Int) {
        self.sourceSegmentCount = sourceSegmentCount
    }

    public func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            syncControlAppearance(from: nsView)
        }
    }

    private func syncControlAppearance(from markerView: NSView) {
        guard let window = markerView.window else { return }
        let allSegmentedControls = window.allSubviews().compactMap { $0 as? NSSegmentedControl }
        guard !allSegmentedControls.isEmpty else { return }

        guard
            let target = nearestSegmentedControl(to: markerView, in: allSegmentedControls),
            let source = allSegmentedControls.first(where: { $0 !== target && $0.segmentCount == sourceSegmentCount })
        else {
            return
        }

        target.controlSize = source.controlSize
        target.segmentStyle = source.segmentStyle
        matchHeight(of: target, to: source.fittingSize.height)
    }

    private func nearestSegmentedControl(
        to markerView: NSView,
        in controls: [NSSegmentedControl]
    ) -> NSSegmentedControl? {
        let markerCenter = markerView.convert(markerView.bounds.center, to: nil)
        return controls.min { lhs, rhs in
            let lhsCenter = lhs.convert(lhs.bounds.center, to: nil)
            let rhsCenter = rhs.convert(rhs.bounds.center, to: nil)
            let lhsDistance = hypot(lhsCenter.x - markerCenter.x, lhsCenter.y - markerCenter.y)
            let rhsDistance = hypot(rhsCenter.x - markerCenter.x, rhsCenter.y - markerCenter.y)
            return lhsDistance < rhsDistance
        }
    }

    private func matchHeight(of control: NSSegmentedControl, to sourceHeight: CGFloat) {
        guard sourceHeight > 0 else { return }

        if let existingConstraint = control.constraints.first(where: { $0.identifier == "TitleBarMatchedHeight" }) {
            if abs(existingConstraint.constant - sourceHeight) > 0.5 {
                existingConstraint.constant = sourceHeight
            }
            return
        }

        let heightConstraint = control.heightAnchor.constraint(equalToConstant: sourceHeight)
        heightConstraint.identifier = "TitleBarMatchedHeight"
        heightConstraint.priority = .required
        heightConstraint.isActive = true
    }
}

private extension NSWindow {
    func allSubviews() -> [NSView] {
        guard let root = contentView else { return [] }
        return [root] + root.deepSubviews()
    }
}

private extension NSView {
    func deepSubviews() -> [NSView] {
        subviews + subviews.flatMap { $0.deepSubviews() }
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
