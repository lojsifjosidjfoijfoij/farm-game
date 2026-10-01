import UIKit
import AcresCore

/// The pixel-art look. The placeholder painters still paint every picture at
/// full size (128 px per tile); here it is shrunk onto the pixel grid the
/// Blender art uses: 32 pixels per tile in the world. Colours get punchier and step into a limited palette, edges
/// go hard (no soft anti-aliased fringe), things that stand in the world get
/// a crisp dark one-pixel outline, and textures are drawn with
/// nearest-neighbour scaling so every art pixel stays a sharp square.
///
/// Real art dropped into `Assets.xcassets` is used as it is (still with
/// nearest-neighbour scaling, so pixel art stays sharp).
enum PixelArt {
    /// How many times smaller than the painted picture, in the world:
    /// 128 px per tile → 32, the same grid as the Blender art. Bigger is chunkier.
    static let worldShrink = 4
    /// Menu and HUD pictures (item icons, Tom) are a little finer, so they read at icon size.
    static let uiShrink = 4
    /// Art pixels per world tile (the ground shader snaps to the same grid).
    static var pixelsPerTile: Double { AssetSpec.pixelsPerTile / Double(worldShrink) }
    /// Colour punch around each pixel's brightness (1 = unchanged); the same
    /// as the Blender art's, so drawn and rendered sprites sit together.
    static let saturation: CGFloat = 1.15
    static let contrast: CGFloat = 1.05
    /// Steps per colour channel: a limited palette.
    static let levels: CGFloat = 16
    /// How dark the outline is, relative to the colour it wraps.
    static let outlineShade: CGFloat = 0.28
    /// Pictures that stay smooth: noise data for the ground shader, and the
    /// screen-edge vignette.
    static let smooth: Set<String> = ["terrain_variation", "fx_vignette"]

    /// Whether a texture is drawn with nearest-neighbour scaling.
    static func isPixelated(_ name: String) -> Bool { !smooth.contains(name) }

    /// The picture on the pixel grid (or unchanged if it's already small).
    static func pixelate(_ image: UIImage, spec: AssetSpec) -> UIImage {
        guard isPixelated(spec.name), let source = image.cgImage else { return image }
        let shrink = Double(spec.layer == .ui ? uiShrink : worldShrink)
        let width = max(1, Int((Double(source.width) / shrink).rounded()))
        let height = max(1, Int((Double(source.height) / shrink).rounded()))
        guard width < source.width || height < source.height else { return image }
        // Soft things (shadows, smoke, glows) keep a few steps of see-through;
        // everything else gets a hard edge, and standing things and item icons an outline.
        let soft = spec.category == .effect || spec.layer == .light
        let tinyClutter = spec.name.hasPrefix("nature_grass_tuft") || spec.name.hasPrefix("nature_flowers")
        let outlined = !soft && !tinyClutter && (spec.layer == .standing || spec.category == .item)

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

        if outlined { outline(&pixels, width: width, height: height) }

        let result: CGImage? = pixels.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                      bytesPerRow: bytesPerRow, space: space, bitmapInfo: info)?.makeImage()
        }
        return result.map { UIImage(cgImage: $0) } ?? image
    }

    /// A one-pixel outline just outside the shape, in a dark shade of the
    /// colour it wraps (pixels are opaque or clear by now).
    private static func outline(_ pixels: inout [UInt8], width: Int, height: Int) {
        let source = pixels
        func opaque(_ x: Int, _ y: Int) -> Int? {
            guard x >= 0, y >= 0, x < width, y < height else { return nil }
            let i = (y * width + x) * 4
            return source[i + 3] == 255 ? i : nil
        }
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                guard source[i + 3] == 0,
                      let n = opaque(x, y - 1) ?? opaque(x, y + 1) ?? opaque(x - 1, y) ?? opaque(x + 1, y) else { continue }
                pixels[i] = UInt8(CGFloat(source[n]) * outlineShade)
                pixels[i + 1] = UInt8(CGFloat(source[n + 1]) * outlineShade)
                pixels[i + 2] = UInt8(CGFloat(source[n + 2]) * outlineShade)
                pixels[i + 3] = 255
            }
        }
    }

    /// One colour channel: clamped, stepped to the palette, premultiplied.
    private static func channel(_ value: CGFloat, _ alpha: CGFloat) -> UInt8 {
        let stepped = (min(1, max(0, value)) * levels).rounded() / levels
        return UInt8((stepped * alpha * 255).rounded())
    }
}
