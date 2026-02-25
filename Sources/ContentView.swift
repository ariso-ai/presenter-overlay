import SwiftUI

struct ContentView: View {
    @ObservedObject var cameraManager: CameraManager

    private let rectangleCornerRadius: CGFloat = 16

    private let shadePadding: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            let inset = cameraManager.shade ? shadePadding : 0
            let width = geometry.size.width - inset * 2
            let height = geometry.size.height - inset * 2

            Group {
                if cameraManager.backgroundRemoval, let frame = cameraManager.processedFrame {
                    Image(decorative: frame, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    CameraPreviewView(
                        session: cameraManager.session,
                        isMirrored: cameraManager.isMirrored
                    )
                }
            }
            .frame(width: width, height: height)
            .clipShape(clipShape)
            .overlay(borderOverlay)
            .shadow(color: .black.opacity(cameraManager.shade ? 0.4 : 0), radius: cameraManager.shade ? 6 : 0, x: 0, y: cameraManager.shade ? 4 : 0)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var showChrome: Bool {
        !cameraManager.backgroundRemoval && !cameraManager.shade
    }

    private var clipShape: AnyShape {
        switch cameraManager.overlayShape {
        case .circle:
            AnyShape(Circle())
        case .portrait, .landscape:
            AnyShape(RoundedRectangle(cornerRadius: rectangleCornerRadius, style: .continuous))
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if showChrome {
            switch cameraManager.overlayShape {
            case .circle:
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            case .portrait, .landscape:
                RoundedRectangle(cornerRadius: rectangleCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            }
        }
    }
}

struct AnyShape: Shape {
    private let pathFunc: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathFunc = { rect in shape.path(in: rect) }
    }

    func path(in rect: CGRect) -> Path {
        pathFunc(rect)
    }
}
