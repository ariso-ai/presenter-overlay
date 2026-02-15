import AppKit
import AVFoundation
import SwiftUI

@main
struct PresenterOverlayApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // No dock icon
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: CircularWindow!
    var statusItem: NSStatusItem!
    let cameraManager = CameraManager()

    private let minSize: CGFloat = 80
    private let maxSize: CGFloat = 400
    private let defaultSize: CGFloat = 200

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
        setupMenuBar()
        cameraManager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        cameraManager.stop()
    }

    // MARK: - Window

    private func setupWindow() {
        let frame = NSRect(x: 0, y: 0, width: defaultSize, height: defaultSize)
        overlayWindow = CircularWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        let contentView = ContentView(cameraManager: cameraManager)
        let hostingView = NSHostingView(rootView: contentView)

        // Wrap in circular hit-test view for click-through outside the circle
        let containerView = CircularHitTestView(frame: NSRect(x: 0, y: 0, width: defaultSize, height: defaultSize))
        containerView.autoresizingMask = [.width, .height]
        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        containerView.addSubview(hostingView)
        overlayWindow.contentView = containerView

        // Add gesture recognizers for resizing
        let magnification = NSMagnificationGestureRecognizer(
            target: self, action: #selector(handleMagnification(_:))
        )
        containerView.addGestureRecognizer(magnification)

        // Position at bottom-right of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - defaultSize - 20
            let y = screenFrame.minY + 20
            overlayWindow.setFrameOrigin(NSPoint(x: x, y: y))
        }

        overlayWindow.makeKeyAndOrderFront(nil)
    }

    @objc private func handleMagnification(_ gesture: NSMagnificationGestureRecognizer) {
        guard let window = gesture.view?.window else { return }
        let currentSize = window.frame.size.width
        let delta = currentSize * gesture.magnification
        let newSize = max(minSize, min(maxSize, currentSize + delta))

        if gesture.state == .changed {
            gesture.magnification = 0
            resizeWindow(to: newSize)
        }
    }

    private func resizeWindow(to size: CGFloat) {
        let oldFrame = overlayWindow.frame
        let centerX = oldFrame.midX
        let centerY = oldFrame.midY
        let newOrigin = NSPoint(x: centerX - size / 2, y: centerY - size / 2)
        let newFrame = NSRect(origin: newOrigin, size: NSSize(width: size, height: size))
        overlayWindow.setFrame(newFrame, display: true, animate: false)
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "camera.circle.fill",
                accessibilityDescription: "Presenter Overlay"
            )
        }

        let menu = NSMenu()

        // Size submenu
        let sizeMenu = NSMenu()
        for (label, size) in [("Small", 120.0), ("Medium", 200.0), ("Large", 300.0)] {
            let item = NSMenuItem(title: label, action: #selector(setSizePreset(_:)), keyEquivalent: "")
            item.tag = Int(size)
            item.target = self
            sizeMenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        // Background removal toggle
        let bgRemovalItem = NSMenuItem(
            title: "Remove Background",
            action: #selector(toggleBackgroundRemoval(_:)),
            keyEquivalent: "b"
        )
        bgRemovalItem.target = self
        bgRemovalItem.state = cameraManager.backgroundRemoval ? .on : .off
        menu.addItem(bgRemovalItem)

        // Mirror toggle
        let mirrorItem = NSMenuItem(
            title: "Mirror Camera",
            action: #selector(toggleMirror(_:)),
            keyEquivalent: "m"
        )
        mirrorItem.target = self
        mirrorItem.state = cameraManager.isMirrored ? .on : .off
        menu.addItem(mirrorItem)

        // Camera submenu (if multiple cameras)
        if cameraManager.availableCameras.count > 1 {
            let cameraMenu = NSMenu()
            for camera in cameraManager.availableCameras {
                let item = NSMenuItem(
                    title: camera.localizedName,
                    action: #selector(selectCamera(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = camera
                item.target = self
                if camera == cameraManager.currentCamera {
                    item.state = .on
                }
                cameraMenu.addItem(item)
            }
            let cameraItem = NSMenuItem(title: "Camera", action: nil, keyEquivalent: "")
            cameraItem.submenu = cameraMenu
            menu.addItem(cameraItem)
        }

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func setSizePreset(_ sender: NSMenuItem) {
        resizeWindow(to: CGFloat(sender.tag))
    }

    @objc private func toggleBackgroundRemoval(_ sender: NSMenuItem) {
        cameraManager.backgroundRemoval.toggle()
        sender.state = cameraManager.backgroundRemoval ? .on : .off
    }

    @objc private func toggleMirror(_ sender: NSMenuItem) {
        cameraManager.isMirrored.toggle()
        cameraManager.updateMirroring()
        sender.state = cameraManager.isMirrored ? .on : .off
    }

    @objc private func selectCamera(_ sender: NSMenuItem) {
        guard let camera = sender.representedObject as? AVCaptureDevice else { return }
        cameraManager.switchCamera(to: camera)

        // Update menu checkmarks
        if let menu = sender.menu {
            for item in menu.items {
                item.state = (item.representedObject as? AVCaptureDevice) == camera ? .on : .off
            }
        }
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }
}
