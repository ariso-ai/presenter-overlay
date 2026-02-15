import SwiftUI

struct ContentView: View {
    @ObservedObject var cameraManager: CameraManager

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            Group {
                if cameraManager.backgroundRemoval, let frame = cameraManager.processedFrame {
                    // Segmented view: person with transparent background
                    Image(decorative: frame, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Normal camera preview
                    CameraPreviewView(
                        session: cameraManager.session,
                        isMirrored: cameraManager.isMirrored
                    )
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                cameraManager.backgroundRemoval ? nil :
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.4), radius: cameraManager.backgroundRemoval ? 0 : 4, x: 0, y: 2)
        }
    }
}
