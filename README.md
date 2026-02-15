# Presenter Overlay

A lightweight macOS menu bar app that shows your camera in a small, circular, always-on-top floating window — similar to the presenter overlay in FaceTime screen sharing.

## Features

- **Multiple shapes** — circle, portrait (3:4 vertical rectangle), or landscape (4:3 horizontal rectangle)
- **Floating camera preview** — borderless, always on top, works across all spaces and fullscreen
- **Background removal** — uses Apple Vision framework person segmentation to show just you with a transparent background, perfect for overlaying on presentations
- **Draggable** — click and drag to reposition anywhere on screen
- **Resizable** — pinch-to-zoom on trackpad (80px–400px range, 200px default)
- **Menu bar controls** — size presets, background removal toggle, mirror toggle, camera selection
- **No dock icon** — just the floating circle and a menu bar item

## Requirements

- macOS 14.0+
- Apple Silicon (arm64)

## Build & Run

```bash
# Build and launch
make run

# Build only
make build

# Clean
make clean
```

On first launch, grant camera permission when prompted.

## Menu Bar Options

| Option | Shortcut | Description |
|---|---|---|
| Shape → Circle / Portrait / Landscape | | Switch between circle, vertical (3:4), or horizontal (4:3) rectangle |
| Size → Small / Medium / Large | | Resize to 120px / 200px / 300px |
| Remove Background | ⌘B | Toggle person segmentation with transparent background |
| Mirror Camera | ⌘M | Toggle horizontal mirror (selfie mode) |
| Camera | | Switch between available cameras |
| Quit | ⌘Q | Exit the app |
