import UIKit
import AcresCore

/// The pixel-art look. The placeholder painters still paint every picture at
/// full size (128 px per tile); here it is shrunk exactly `shrink` times onto
/// a coarse pixel grid, so the world has small, crisp pixels (32 per tile).
/// Colours get punchier and step into a limited palette, edges go hard (no
/// soft anti-aliased fringe), and textures are drawn with nearest-neighbour
/// scaling so every art pixel stays a sharp square.
///
/// Real art dropped into `Assets.xcassets` is used as it is (still with
/// nearest-neighbour scaling, so pixel art stays sharp).
enum PixelArt {
    /// How many times smaller than the painted picture: 128 px per tile → 32.
    /// Bigger is chunkier.
    static let shrink = 4
    /// Colour punch around each pixel's brightness (1 = unchanged).
    static let saturation: CGFloat = 1.35
    static let contrast: CGFloat = 1.08
    /// Steps per colour channel: a limited palette.
    static let levels: CGFloat = 20
    /// Pictures that stay smooth: noise data for the ground shader, and the
    /// screen-edge vignette.
    static let smooth: Set<String> = ["terrain_variation", "fx_vignette"]

    /// Whether a texture is drawn with nearest-neighbour scaling.
    static func isPixelated(_ name: String) -> Bool { !smooth.contains(name) }

    /// The picture on the pixel grid (or unchanged if it's already small).
    static func pixelate(_ image: UIImage, spec: AssetSpec) -> UIImage {
        guard isPixelated(spec.name), let source = image.cgImage else { return image }
        let width = max(1, Int((Double(source.width) / Double(shrink)).rounded()))
        let height = max(1, Int((Double(source.height) / Double(shrink)).rounded()))
        guard width < source.width || height < source.height else { return image }
        // Soft things (shadows, smoke, glows) keep a few steps of see-through;
        // everything else gets a hard edge.
        let soft = spec.category == .effect || spec.layer == .light

        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow, space: space, bitmapInfo: info) else { return false }
            // High quality averages each block of painted pixels into one.
            ctx.interpolationQuality = .high
            ctx.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return image }

        for i in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = CGFloat(pixels[i + 3]) / 255
            guard alpha > 0 else { continue }
            let a = soft ? (alpha * 4).rounded() / 4 : (alpha >= 0.5 ? 1 : 0)
            guard a > 0 else {
                pixels[i] = 0; pixels[i + 1] = 0; pixels[i + 2] = 0; pixels[i + 3] = 0
                continue
            }
            // Un-premultiply, punch up, step into the palette, premultiply again.
            var r = CGFloat(pixels[i]) / 255 / alpha
            var g = CGFloat(pixels[i + 1]) / 255 / alpha
            var b = CGFloat(pixels[i + 2]) / 255 / alpha
            let luma = 0.299 * r + 0.587 * g + 0.114 * b
            r = luma + (r - luma) * saturation
            g = luma + (g - luma) * saturation
            b = luma + (b - luma) * saturation
            r = (r - 0.5) * contrast + 0.5
            g = (g - 0.5) * contrast + 0.5
            b = (b - 0.5) * contrast + 0.5
            pixels[i] = channel(r, a)
            pixels[i + 1] = channel(g, a)
            pixels[i + 2] = channel(b, a)
            pixels[i + 3] = UInt8((a * 255).rounded())
        }

        let result: CGImage? = pixels.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                      bytesPerRow: bytesPerRow, space: space, bitmapInfo: info)?.makeImage()
        }
        return result.map { UIImage(cgImage: $0) } ?? image
    }

    /// One colour channel: clamped, stepped to the palette, premultiplied.
    private static func channel(_ value: CGFloat, _ alpha: CGFloat) -> UInt8 {
        let stepped = (min(1, max(0, value)) * levels).rounded() / levels
        return UInt8((stepped * alpha * 255).rounded())
    }
}
