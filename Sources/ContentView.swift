import SwiftUI

struct ContentView: View {
    @ObservedObject var cameraManager: CameraManager

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            CameraPreviewView(
                session: cameraManager.session,
                isMirrored: cameraManager.isMirrored
            )
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
        }
    }
}
