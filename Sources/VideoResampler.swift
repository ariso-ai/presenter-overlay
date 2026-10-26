import CoreImage

enum VideoResampler {
    /// Aspect-fill with isotropic Lanczos filtering, then center-crop in output pixels.
    /// Never render a full-resolution CGImage only to shrink it again in the UI.
    static func image(_ source: CIImage, fitting target: CGSize) -> CIImage? {
        let extent = source.extent
        guard target.width.isFinite, target.height.isFinite,
              target.width >= 1, target.height >= 1,
              extent.width > 0, extent.height > 0, !extent.isInfinite else { return nil }
        let pixels = CGSize(width: ceil(target.width), height: ceil(target.height))
        let scale = max(pixels.width / extent.width, pixels.height / extent.height)
        let normalized = source.transformed(by: CGAffineTransform(
            translationX: -extent.minX, y: -extent.minY
        ))
        let scaled = normalized.clampedToExtent().applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: scale,
            kCIInputAspectRatioKey: 1
        ])
        // Clamp before filtering to prevent transparent fringes around opaque frames.
        let origin = CGPoint(x: (extent.width * scale - pixels.width) / 2,
                             y: (extent.height * scale - pixels.height) / 2)
        return scaled.transformed(by: CGAffineTransform(translationX: -origin.x, y: -origin.y))
            .cropped(to: CGRect(origin: .zero, size: pixels))
    }
}
