import AVFoundation
import Combine

class CameraManager: ObservableObject {
    let session = AVCaptureSession()
    @Published var isMirrored = true
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var currentCamera: AVCaptureDevice?

    private var currentInput: AVCaptureDeviceInput?

    init() {
        discoverCameras()
    }

    func discoverCameras() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        availableCameras = discovery.devices
    }

    func start(with device: AVCaptureDevice? = nil) {
        session.beginConfiguration()

        // Remove existing input
        if let currentInput = currentInput {
            session.removeInput(currentInput)
        }

        // Select camera
        let camera = device
            ?? currentCamera
            ?? AVCaptureDevice.default(for: .video)

        guard let camera = camera else {
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
                currentInput = input
                currentCamera = camera
            }
        } catch {
            print("Failed to create camera input: \(error)")
        }

        session.commitConfiguration()

        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    func switchCamera(to device: AVCaptureDevice) {
        start(with: device)
    }
}
