import AppKit
import SwiftUI

class OverlayWindow: NSWindow {
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: backingStoreType,
            defer: flag
        )

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        hasShadow = true
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}

/// A container NSView that only accepts clicks within the visible shape region.
class ShapeHitTestView: NSView {
    var shape: OverlayShape = .circle
    var cornerRadius: CGFloat = 16

    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)

        switch shape {
        case .circle:
            let center = NSPoint(x: bounds.midX, y: bounds.midY)
            let radius = min(bounds.width, bounds.height) / 2
            let dx = localPoint.x - center.x
            let dy = localPoint.y - center.y
            if (dx * dx + dy * dy) > (radius * radius) {
                return nil
            }
        case .portrait, .landscape:
            let path = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
            if !path.contains(localPoint) {
                return nil
            }
        }

        return super.hitTest(point)
    }
}
