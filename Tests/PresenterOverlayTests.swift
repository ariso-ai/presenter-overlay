import AppKit
import CoreImage

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
    assertEqual(OverlayShape.squircle.rawValue, "squircle", "squircle raw value")
    assertEqual(OverlayShape.portrait.rawValue, "portrait", "portrait raw value")
    assertEqual(OverlayShape.landscape.rawValue, "landscape", "landscape raw value")
    assertEqual(OverlayShape(rawValue: "circle"), .circle, "init from circle")
    assertEqual(OverlayShape(rawValue: "squircle"), .squircle, "init from squircle")
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

    // Squircle: center should hit
    view.shape = .squircle
    assert(view.hitTest(NSPoint(x: 100, y: 100)) != nil, "squircle hit test: center hits")

    // Squircle: corner should miss
    assert(view.hitTest(NSPoint(x: 5, y: 5)) == nil, "squircle hit test: corner misses")

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
    assert(!window.hasShadow, "window has no shadow")
    assert(window.isMovableByWindowBackground, "window is movable by background")
    assert(window.collectionBehavior.contains(.canJoinAllSpaces), "window joins all spaces")
    assert(window.collectionBehavior.contains(.fullScreenAuxiliary), "window supports fullscreen auxiliary")
}

// MARK: - Run

func testVideoSurface() {
    print("Video surface: resize and backing changes (no camera required)")
    let window = OverlayWindow(
        contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
        styleMask: [], backing: .buffered, defer: false
    )
    let view = CameraLayerView(frame: .zero)
    window.contentView = view
    assert(view.layer != nil, "native image backing layer exists")
    var reportedSize = CGSize.zero
    view.onPixelSizeChange = { reportedSize = $0 }

    for width: CGFloat in [120, 200, 600, 200, 120] {
        for inset: CGFloat in [16, 0] {
            window.setContentSize(NSSize(width: width, height: width))
            let videoWidth = width - 2 * inset
            view.frame = NSRect(x: inset, y: inset, width: videoWidth, height: videoWidth)
            view.layout()
            view.viewDidChangeBackingProperties()
            assertEqual(view.layer?.bounds.size, Optional(view.bounds.size), "preview tracks \(videoWidth) pt video bounds")
            assertEqual(view.layer?.contentsScale, window.backingScaleFactor, "preview uses current window scale")
            assertEqual(view.layer?.minificationFilter, .linear, "preview enables reduction filtering")
            assert(view.layer?.shouldRasterize == false, "preview has no intermediate rasterization")
            assertEqual(reportedSize, view.convertToBacking(view.bounds).size, "resampler receives physical viewport size")
        }
    }

    let processed = CameraLayerView(frame: NSRect(x: 0, y: 0, width: 168, height: 168))
    window.contentView = processed
    processed.updateSurface()
    assertEqual(processed.layer?.contentsScale, window.backingScaleFactor, "processed geometry follows window scale")
    assertEqual(processed.convertToBacking(processed.bounds).width,
                processed.bounds.width * window.backingScaleFactor, "physical size uses backing conversion")
    window.contentView = nil
    processed.updateSurface()
    assertEqual(processed.layer?.contentsScale, 1, "detached surface has safe scale fallback")
}

func testLanczosResampling() {
    print("Lanczos: physical output size, aspect fill and alias suppression")
    let context = CIContext(options: [.useSoftwareRenderer: false,
                                      .workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
    let width = 2048
    let height = 2048
    // One-pixel black/white stripes lie above the output Nyquist frequency.
    var source = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * width + x) * 4
            let value: UInt8 = x % 2 == 0 ? 0 : 255
            source[offset] = value
            source[offset + 1] = value
            source[offset + 2] = value
        }
    }
    let input = CIImage(bitmapData: Data(source), bytesPerRow: width * 4,
                        size: CGSize(width: width, height: height), format: .RGBA8,
                        colorSpace: nil)
    for scale: CGFloat in [1, 2] {
        for points: CGFloat in [88, 168, 568, 168, 88] {
            let pixels = Int(points * scale)
            let target = CGSize(width: pixels, height: pixels)
            guard let result = VideoResampler.image(input, fitting: target) else {
                assert(false, "valid resampling produces output")
                continue
            }
            assertEqual(result.extent, CGRect(origin: .zero, size: target), "exact output at \(points) pt / \(scale)×")
            var bytes = [UInt8](repeating: 0, count: pixels * pixels * 4)
            bytes.withUnsafeMutableBytes {
                context.render(result, toBitmap: $0.baseAddress!, rowBytes: pixels * 4,
                               bounds: result.extent, format: .RGBA8, colorSpace: nil)
            }
            let samples = (10..<(pixels - 10)).map { Double(bytes[((pixels / 2) * pixels + $0) * 4]) }
            let mean = samples.reduce(0, +) / Double(samples.count)
            let deviation = sqrt(samples.map { pow($0 - mean, 2) }.reduce(0, +) / Double(samples.count))
            print("  stripe mean=\(mean) deviation=\(deviation) at \(pixels) px")
            assert(mean > 100 && mean < 200, "subpixel stripes converge to gray, not false detail")
            assert(deviation < 20, "Lanczos suppresses stripe aliasing")
            assertEqual(bytes[(pixels * (pixels / 2) + pixels / 2) * 4 + 3], 255, "opaque input remains opaque")
        }
    }
    let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 30, y: 50, width: 640, height: 480))
    let target = CGSize(width: 176, height: 234)
    assertEqual(VideoResampler.image(red, fitting: target)?.extent,
                CGRect(origin: .zero, size: target), "nonzero-origin non-HD source supports portrait crop")
    let transparent = CIImage(color: .clear).cropped(to: CGRect(x: 0, y: 0, width: 640, height: 480))
    if let output = VideoResampler.image(transparent, fitting: CGSize(width: 1, height: 1)),
       let image = context.createCGImage(output, from: output.extent) {
        assertEqual(image.width, 1, "transparent segmented output renders")
        let data = image.dataProvider!.data! as Data
        assert(data.allSatisfy { $0 == 0 }, "transparent background remains transparent")
    } else {
        assert(false, "transparent segmented output renders")
    }
    assert(VideoResampler.image(input, fitting: .zero) == nil, "ignore unattached zero-size viewport")
}

@main
struct TestRunner {
    static func main() {
        _ = NSApplication.shared
        print("Running tests...\n")
        testOverlayShape()
        testShapeHitTest()
        testOverlayWindow()
        testVideoSurface()
        testLanczosResampling()
        print("\n\(passed) passed, \(failed) failed")
        if failed > 0 { exit(1) }
    }
}
