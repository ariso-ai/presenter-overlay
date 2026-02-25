import AppKit
import SwiftUI

class OverlayWindow: NSWindow {
    var onResize: ((CGFloat) -> Void)?

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
        hasShadow = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override func scrollWheel(with event: NSEvent) {
        // Use deltaY for scroll-based resizing
        let delta = event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 1 : 3)
        guard abs(delta) > 0.1 else { return }
        onResize?(delta)
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
        case .squircle:
            let r = min(bounds.width, bounds.height) * 0.4
            let path = NSBezierPath(roundedRect: bounds, xRadius: r, yRadius: r)
            if !path.contains(localPoint) {
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
