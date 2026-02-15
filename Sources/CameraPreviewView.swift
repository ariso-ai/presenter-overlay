import AVFoundation
import SwiftUI

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    let isMirrored: Bool

    func makeNSView(context: Context) -> CameraLayerView {
        let view = CameraLayerView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        updateMirroring(view)
        return view
    }

    func updateNSView(_ nsView: CameraLayerView, context: Context) {
        updateMirroring(nsView)
    }

    private func updateMirroring(_ view: CameraLayerView) {
        if let connection = view.previewLayer.connection {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
        }
    }
}

class CameraLayerView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer = previewLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}
