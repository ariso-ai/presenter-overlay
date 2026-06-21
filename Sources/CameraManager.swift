import AVFoundation
import Combine
import CoreImage
import Vision

enum OverlayShape: String {
    case circle
    case squircle
    case portrait
    case landscape
}

enum BackgroundMode: String, CaseIterable {
    case off
    case blur
    case remove
}

class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var isMirrored = true
    @Published var backgroundMode: BackgroundMode = .off
    @Published var shade = true
    @Published var overlayShape: OverlayShape = .circle
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var currentCamera: AVCaptureDevice?
    @Published var processedFrame: CGImage?

    private var currentInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.shawnzhu.presenter-overlay.video", qos: .userInteractive)
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let segmentationRequest: VNGeneratePersonSegmentationRequest = {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        return request
    }()

    override init() {
        super.init()
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

        // Add video output for frame processing (if not already added)
        if !session.outputs.contains(videoOutput) {
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
        }

        // Set mirroring on the video output connection
        if let connection = videoOutput.connection(with: .video) {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
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

    func updateMirroring() {
        if let connection = videoOutput.connection(with: .video) {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
        }
    }
}

// MARK: - Video Frame Processing

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        if backgroundMode != .off {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([segmentationRequest])
            } catch {
                return
            }

            guard let maskBuffer = segmentationRequest.results?.first?.pixelBuffer else { return }

            let cameraImage = CIImage(cvPixelBuffer: pixelBuffer)
            let maskImage = CIImage(cvPixelBuffer: maskBuffer)

            let scaleX = cameraImage.extent.width / maskImage.extent.width
            let scaleY = cameraImage.extent.height / maskImage.extent.height
            let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

            let background: CIImage
            if backgroundMode == .blur {
                background = cameraImage.applyingFilter("CIGaussianBlur", parameters: [
                    kCIInputRadiusKey: 30.0
                ]).cropped(to: cameraImage.extent)
            } else {
                background = CIImage.empty()
            }

            let blended = cameraImage.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: background,
                kCIInputMaskImageKey: scaledMask
            ])

            guard let cgImage = ciContext.createCGImage(blended, from: cameraImage.extent) else { return }

            DispatchQueue.main.async {
                self.processedFrame = cgImage
            }
        } else {
            if processedFrame != nil {
                DispatchQueue.main.async { self.processedFrame = nil }
            }
        }
    }
}
