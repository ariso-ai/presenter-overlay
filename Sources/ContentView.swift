import SwiftUI

struct ContentView: View {
    @ObservedObject var cameraManager: CameraManager

    private let rectangleCornerRadius: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

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
            .shadow(color: .black.opacity(showChrome ? 0.4 : 0), radius: showChrome ? 4 : 0, x: 0, y: 2)
        }
    }

    private var showChrome: Bool {
        !cameraManager.backgroundRemoval
    }

    private var clipShape: AnyShape {
        switch cameraManager.overlayShape {
        case .circle:
            AnyShape(Circle())
        case .rectangle:
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
            case .rectangle:
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
