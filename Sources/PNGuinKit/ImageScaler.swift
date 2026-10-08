import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Lanczos downsampling: letting the GPU minify a screenshot by ~8x (1x displays) aliases text into illegibility.
public enum ImageScaler {

    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// Scales `image` to exactly `width` × `height` pixels; runs off the caller's actor.
    @concurrent
    public static func scaled(_ image: CGImage, width: Int, height: Int) async -> CGImage? {
        guard width > 0, height > 0, image.width > 0, image.height > 0 else { return nil }

        let scale = Double(height) / Double(image.height)
        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = CIImage(cgImage: image)
        filter.scale = Float(scale)
        filter.aspectRatio = Float(Double(width) / (Double(image.width) * scale))
        guard let output = filter.outputImage else { return nil }

        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        return context.createCGImage(output, from: CGRect(x: 0, y: 0, width: width, height: height), format: .RGBA8, colorSpace: colorSpace)
    }
}
