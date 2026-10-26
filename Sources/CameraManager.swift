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

class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var isMirrored = true
    @Published var backgroundRemoval = false {
        didSet {
            print("[Video path] backgroundRemoval=\(backgroundRemoval)")
            updateRenderConfiguration()
        }
    }
    @Published var shade = true
    @Published var overlayShape: OverlayShape = .circle
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var currentCamera: AVCaptureDevice?
    @Published var processedFrame: CGImage?

    private var currentInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.shawnzhu.presenter-overlay.video", qos: .userInteractive)
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    // Accessed only by the serial sample-buffer delegate queue.
    private var lastFrameSize = CGSize.zero
    private var lastPixelFormat: OSType = 0
    private var lastProcessingSizes: [CGSize] = []
    // Requested state is main-thread owned; processing state is queue owned.
    private var requestedRenderSize = CGSize.zero
    private var renderRevision = 0
    private var renderSize = CGSize.zero
    private var renderBackgroundRemoval = false
    private var processingRevision = 0
    private let pendingPresentation = DispatchSemaphore(value: 1)
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
        updateRenderConfiguration()
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

        let dimensions = CMVideoFormatDescriptionGetDimensions(camera.activeFormat.formatDescription)
        let duration = camera.activeVideoMinFrameDuration
        let fps = duration.seconds > 0 ? 1 / duration.seconds : 0
        print("[Camera] name=\(camera.localizedName) type=\(camera.deviceType.rawValue) preset=\(session.sessionPreset.rawValue) activeFormat=\(camera.activeFormat) dimensions=\(dimensions.width)x\(dimensions.height) configuredFPS=\(fps) minDuration=\(duration) maxDuration=\(camera.activeVideoMaxFrameDuration)")
        processingQueue.async {
            self.lastFrameSize = .zero
            self.lastPixelFormat = 0
            self.lastProcessingSizes = []
        }

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
        updateRenderConfiguration()
    }

    func updateRenderSize(_ size: CGSize) {
        guard size != requestedRenderSize else { return }
        requestedRenderSize = size
        updateRenderConfiguration()
    }

    private func updateRenderConfiguration() {
        renderRevision += 1
        let revision = renderRevision
        let size = requestedRenderSize
        let removeBackground = backgroundRemoval
        processingQueue.async {
            self.renderSize = size
            self.renderBackgroundRemoval = removeBackground
            self.processingRevision = revision
            self.lastProcessingSizes = []
        }
    }
}

// MARK: - Video Frame Processing

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let frameSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        if frameSize != lastFrameSize || pixelFormat != lastPixelFormat {
            lastFrameSize = frameSize
            lastPixelFormat = pixelFormat
            print("[Video frames] size=\(frameSize) pixelFormat=\(pixelFormat)")
        }
        guard renderSize.width >= 1, renderSize.height >= 1 else { return }
        let cameraImage = CIImage(cvPixelBuffer: pixelBuffer)
        var image = cameraImage
        var maskSize = CGSize.zero
        if renderBackgroundRemoval {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([segmentationRequest])
            } catch {
                return
            }
            guard let maskBuffer = segmentationRequest.results?.first?.pixelBuffer else { return }
            let mask = CIImage(cvPixelBuffer: maskBuffer)
            maskSize = mask.extent.size
            let scaledMask = mask.transformed(by: CGAffineTransform(
                scaleX: cameraImage.extent.width / maskSize.width,
                y: cameraImage.extent.height / maskSize.height
            ))
            image = cameraImage.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: CIImage.empty(),
                kCIInputMaskImageKey: scaledMask
            ]).cropped(to: cameraImage.extent)
        }
        guard let resized = VideoResampler.image(image, fitting: renderSize),
              let cgImage = ciContext.createCGImage(resized, from: resized.extent) else { return }
        let processingSizes = [cameraImage.extent.size, maskSize,
                               CGSize(width: cgImage.width, height: cgImage.height)]
        if processingSizes != lastProcessingSizes {
            lastProcessingSizes = processingSizes
            print("[Video processing] backgroundRemoval=\(renderBackgroundRemoval) input=\(processingSizes[0]) mask=\(maskSize) output=\(processingSizes[2]) filter=Lanczos")
        }

        // Bound main-thread publications: never accumulate a queue of retained frames.
        guard pendingPresentation.wait(timeout: .now()) == .success else { return }
        let revision = processingRevision
        DispatchQueue.main.async {
            defer { self.pendingPresentation.signal() }
            guard revision == self.renderRevision else { return }
            self.processedFrame = cgImage
        }
    }
}
