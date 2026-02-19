import AppKit

// Minimal test harness
var passed = 0
var failed = 0

func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition {
        passed += 1
        print("  ✓ \(message)")
    } else {
        failed += 1
        print("  ✗ \(message) (\(file):\(line))")
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String, file: String = #file, line: Int = #line) {
    if a == b {
        passed += 1
        print("  ✓ \(message)")
    } else {
        failed += 1
        print("  ✗ \(message): expected \(b), got \(a) (\(file):\(line))")
    }
}

// MARK: - OverlayShape Tests

func testOverlayShape() {
    print("OverlayShape")
    assertEqual(OverlayShape.circle.rawValue, "circle", "circle raw value")
    assertEqual(OverlayShape.portrait.rawValue, "portrait", "portrait raw value")
    assertEqual(OverlayShape.landscape.rawValue, "landscape", "landscape raw value")
    assertEqual(OverlayShape(rawValue: "circle"), .circle, "init from circle")
    assertEqual(OverlayShape(rawValue: "portrait"), .portrait, "init from portrait")
    assertEqual(OverlayShape(rawValue: "landscape"), .landscape, "init from landscape")
    assert(OverlayShape(rawValue: "invalid") == nil, "invalid raw value returns nil")
}

// MARK: - ShapeHitTestView Tests

func testShapeHitTest() {
    print("ShapeHitTestView")

    let view = ShapeHitTestView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))

    // Circle: center should hit
    view.shape = .circle
    assert(view.hitTest(NSPoint(x: 100, y: 100)) != nil, "circle hit test: center hits")

    // Circle: corner should miss (outside radius)
    assert(view.hitTest(NSPoint(x: 5, y: 5)) == nil, "circle hit test: corner misses")

    // Rectangle: center should hit
    view.shape = .portrait
    assert(view.hitTest(NSPoint(x: 100, y: 100)) != nil, "portrait hit test: center hits")

    // Rectangle: outside bounds should miss
    view.shape = .landscape
    assert(view.hitTest(NSPoint(x: 300, y: 300)) == nil, "landscape hit test: outside misses")
}

// MARK: - OverlayWindow Tests

func testOverlayWindow() {
    print("OverlayWindow")

    let window = OverlayWindow(
        contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
        styleMask: [],
        backing: .buffered,
        defer: false
    )

    assert(!window.isOpaque, "window is not opaque")
    assertEqual(window.backgroundColor, .clear, "window background is clear")
    assertEqual(window.level, .floating, "window level is floating")
    assert(window.hasShadow, "window has shadow")
    assert(window.isMovableByWindowBackground, "window is movable by background")
    assert(window.collectionBehavior.contains(.canJoinAllSpaces), "window joins all spaces")
    assert(window.collectionBehavior.contains(.fullScreenAuxiliary), "window supports fullscreen auxiliary")
}

// MARK: - Run

@main
struct TestRunner {
    static func main() {
        print("Running tests...\n")
        testOverlayShape()
        testShapeHitTest()
        testOverlayWindow()
        print("\n\(passed) passed, \(failed) failed")
        if failed > 0 { exit(1) }
    }
}
