import SwiftUI

/// Presents an image already resampled to the viewport's physical pixels.
struct CameraPreviewView: NSViewRepresentable {
    let frame: CGImage?
    let onPixelSizeChange: (CGSize) -> Void

    func makeNSView(context: Context) -> CameraLayerView {
        let view = CameraLayerView()
        view.onPixelSizeChange = onPixelSizeChange
        return view
    }

    func updateNSView(_ view: CameraLayerView, context: Context) {
        view.onPixelSizeChange = onPixelSizeChange
        view.display(frame)
        view.updateSurface()
    }
}

class CameraLayerView: NSView {
    var onPixelSizeChange: ((CGSize) -> Void)?
    private var lastPixelSize = CGSize.zero
    private var lastGeometry = ""

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.contentsGravity = .resize
        layer?.minificationFilter = .linear
        layer?.magnificationFilter = .linear
        layer?.shouldRasterize = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func display(_ image: CGImage?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.contents = image
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateSurface()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateSurface()
    }

    override func layout() {
        super.layout()
        updateSurface()
    }

    func updateSurface() {
        let scale = window?.backingScaleFactor ?? 1
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.contentsScale = scale
        CATransaction.commit()
        guard let window else { return }
        let backingSize = convertToBacking(bounds).size
        let pixels = CGSize(width: ceil(backingSize.width), height: ceil(backingSize.height))
        if pixels != lastPixelSize {
            lastPixelSize = pixels
            onPixelSizeChange?(pixels)
        }
        let message = "windowPt=\(window.frame.size) videoPt=\(bounds.size) backingScale=\(scale) contentsScale=\(layer?.contentsScale ?? 0) targetPx=\(pixels) renderer=CoreImage/Lanczos"
        if message != lastGeometry {
            lastGeometry = message
            print("[Video geometry] \(message)")
        }
    }
}
