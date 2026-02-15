import AppKit
import SwiftUI

class CircularWindow: NSWindow {
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

/// A container NSView that only accepts clicks within a circular region.
class CircularHitTestView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2
        let dx = localPoint.x - center.x
        let dy = localPoint.y - center.y
        if (dx * dx + dy * dy) > (radius * radius) {
            return nil // Click outside circle — pass through
        }
        return super.hitTest(point)
    }
}
