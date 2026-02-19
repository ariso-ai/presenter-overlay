# Presenter Overlay

A lightweight macOS menu bar app that floats your camera feed on top of any window — so your audience sees you while you present, demo, or teach.

No extra software needed. Just build, launch, and you appear as a small floating overlay on screen, ready to be seen alongside your slides, code editor, or any app.

<img alt="menu bar options image" src="https://github.com/user-attachments/assets/ff894478-6601-44c0-b9a0-beaeace0593b" width="524" height="209" />

## Why

Screen recordings and live presentations feel more personal when your face is visible. Presenter Overlay gives you a always-on-top camera window with **background removal**, so only you appear — no cluttered room behind you. Drag it to any corner, resize it, and keep presenting.

## Features

- **Always on top** — floats above all windows, across all spaces and fullscreen apps
- **Background removal** — Apple Vision person segmentation shows just you with a transparent background
- **Multiple shapes** — circle, portrait (3:4), or landscape (4:3)
- **Draggable** — click and drag to reposition anywhere
- **Resizable** — pinch-to-zoom on trackpad (80–400px)
- **Menu bar controls** — shape, size presets, background toggle, mirror toggle, camera selection
- **Minimal footprint** — no dock icon, just the overlay and a menu bar item

## Requirements

- macOS 14.0+
- Apple Silicon (arm64)

## Security

It will need to grant this app to access your camera.

## Build & Run

```bash
make run
```

On first launch, grant camera permission when prompted.

Other targets:

```bash
make build   # build only
make test    # run unit tests
make clean   # remove build artifacts
```

## Menu Bar Options

| Option | Shortcut | Description |
|---|---|---|
| Shape | | Circle, portrait (3:4), or landscape (4:3) |
| Size | | Small (120px) / Medium (200px) / Large (300px) |
| Remove Background | ⌘B | Toggle person segmentation |
| Mirror Camera | ⌘M | Toggle horizontal flip |
| Camera | | Switch between available cameras |
| Quit | ⌘Q | Exit |

## How It Works

Built with Swift and native macOS frameworks:

- **AVFoundation** for camera capture
- **Vision** for real-time person segmentation
- **CoreImage** for compositing the segmentation mask
- **SwiftUI + AppKit** for the overlay window and menu bar

The app runs as a macOS accessory (no dock icon). The floating window is borderless, transparent, and always on top. When background removal is enabled, each video frame is processed through Apple's Vision framework to isolate the person and remove the background.

## License

MIT
