import UIKit
import AcresCore

/// Seamless ground textures. Each covers 4 × 4 tiles and repeats.
enum TerrainPainter {

    static func paint(_ name: String, size: CGSize, rng: inout SeededRandom) -> UIImage? {
        switch name {
        case "terrain_grass": return grass(size, rng: &rng)
        case "terrain_dirt": return dirt(size, rng: &rng)
        case "terrain_gravel": return gravel(size, rng: &rng)
        case "terrain_asphalt": return asphalt(size, rng: &rng)
        case "terrain_variation": return variation(size, seed: rng.next())
        default: return nil
        }
    }

    // MARK: Grass

    static func grass(_ size: CGSize, rng: inout SeededRandom) -> UIImage {
        let base = UIColor(hex: 0x7C9E57)
        return Canvas.image(size, opaque: true) { ctx in
            ctx.setFillColor(base.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))

            // Broad, soft color variation.
            for _ in 0..<46 {
                let p = rng.point(in: CGRect(origin: .zero, size: size))
                let r = rng.cg(40...120)
                let tint = rng.chance(0.5) ? UIColor(hex: 0x93B266) : UIColor(hex: 0x66874A)
                let alpha = rng.cg(0.10...0.2)
                Tiling.wrapped(size, p, margin: r) { q in Paint.softSpot(ctx, q, r, tint.withAlpha(alpha)) }
            }
            // Short blades, mostly pointing up, light from the upper left.
            let dark = UIColor(hex: 0x5B7D40), light = UIColor(hex: 0xA6C476)
            for _ in 0..<2600 {
                let p = rng.point(in: CGRect(origin: .zero, size: size))
                let length = rng.cg(6...14)
                let angle = -CGFloat.pi / 2 + rng.cg(-0.55...0.55)
                let tip = CGPoint(x: p.x + cos(angle) * length, y: p.y + sin(angle) * length)
                let color = dark.mixed(with: light, rng.cg(0...1)).withAlpha(rng.cg(0.45...0.8))
                let width = rng.cg(1.4...2.6)
                let bend = rng.cg(-3...3)
                Tiling.wrapped(size, p, margin: 16) { q in
                    let offset = CGPoint(x: q.x - p.x, y: q.y - p.y)
                    Paint.stroke(ctx, from: q, to: CGPoint(x: tip.x + offset.x, y: tip.y + offset.y), bend: bend, width: width, color: color)
                }
            }
            // A few sunlit specks.
            for _ in 0..<140 {
                let p = rng.point(in: CGRect(origin: .zero, size: size))
                Paint.dab(ctx, p, 1.4, 1.1, UIColor(hex: 0xC9DB8E).withAlpha(0.6))
            }
        }
    }

    // MARK: Dirt

    static func dirt(_ size: CGSize, rng: inout SeededRandom) -> UIImage {
        Canvas.image(size, opaque: true) { ctx in
            ctx.setFillColor(UIColor(hex: 0x9A7550).cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
            for _ in 0..<40 {
                let p = rng.point(in: CGRect(origin: .zero, size: size))
                let r = rng.cg(30...110)
                let tint = rng.chance(0.5) ? UIColor(hex: 0xAE8B62) : UIColor(hex: 0x82603F)
                let alpha = rng.cg(0.12...0.25)
                Tiling.wrapped(size, p, margin: r) { q in Paint.softSpot(ctx, q, r, tint.withAlpha(alpha), scaleY: 0.8) }
            }
            let specks = [UIColor(hex: 0x7A5A3B), UIColor(hex: 0xB59470), UIColor(hex: 0x6B4E33), UIColor(hex: 0xC4A884)]
            for _ in 0..<1500 {
                let p = rng.point(in: CGRect(origin: .zero, size: size))
                let r = rng.cg(0.8...2.4)
                let color = rng.pick(specks).withAlpha(rng.cg(0.35...0.75))
                Tiling.wrapped(size, p, margin: 4) { q in Paint.dab(ctx, q, r, r * 0.8, color) }
            }
            for _ in 0..<80 {
                let p = rng.point(in: CGRect(origin: .zero, size: size))
                let r = rng.cg(2.5...5.5)
                Tiling.wrapped(size, p, margin: 8) { q in pebble(ctx, q, r, UIColor(hex: 0xB7A48B)) }
            }
        }
    }

    // MARK: Gravel

    static func gravel(_ size: CGSize, rng: inout SeededRandom) -> UIImage {
        Canvas.image(size, opaque: true) { ctx in
            ctx.setFillColor(UIColor(hex: 0xA59A86).cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
            for _ in 0..<30 {
                let p = rng.point(in: CGRect(origin: .zero, size: size))
                let r = rng.cg(30...90)
                let tint = rng.chance(0.5) ? UIColor(hex: 0xBDB29C) : UIColor(hex: 0x8C826F)
                let alpha = rng.cg(0.15...0.3)
                Tiling.wrapped(size, p, margin: r) { q in Paint.softSpot(ctx, q, r, tint.withAlpha(alpha)) }
            }
            let stones = [UIColor(hex: 0xC4BAA5), UIColor(hex: 0x8E8472), UIColor(hex: 0xB3A88F), UIColor(hex: 0x7C7466), UIColor(hex: 0xD2C8B2)]
            for _ in 0..<2300 {
                let p = rng.point(in: CGRect(origin: .zero, size: size))
                let r = rng.cg(1.5...4.2)
                let color = rng.pick(stones)
                Tiling.wrapped(size, p, margin: 6) { q in pebble(ctx, q, r, color) }
            }
        }
    }

    // MARK: Asphalt

    static func asphalt(_ size: CGSize, rng: inout SeededRandom) -> UIImage {
        Canvas.image(size, opaque: true) { ctx in
            ctx.setFillColor(UIColor(hex: 0x575350).cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
            for _ in 0..<26 {
                let p = rng.point(in: CGRect(origin: .zero, size: size))
                let r = rng.cg(40...120)
                let tint = rng.chance(0.5) ? UIColor(hex: 0x65605B) : UIColor(hex: 0x4A4745)
                let alpha = rng.cg(0.2...0.35)
                Tiling.wrapped(size, p, margin: r) { q in Paint.softSpot(ctx, q, r, tint.withAlpha(alpha)) }
            }
            for _ in 0..<5200 {
                let p = rng.point(in: CGRect(origin: .zero, size: size))
                let color = rng.chance(0.5) ? UIColor(hex: 0x77716B) : UIColor(hex: 0x3E3B39)
                Paint.dab(ctx, p, 0.9, 0.9, color.withAlpha(rng.cg(0.3...0.7)))
            }
            // Hairline cracks.
            for _ in 0..<5 {
                var p = rng.point(in: CGRect(origin: .zero, size: size).insetBy(dx: 60, dy: 60))
                ctx.setStrokeColor(UIColor(hex: 0x33302E).withAlpha(0.55).cgColor)
                ctx.setLineWidth(1.2)
                ctx.move(to: p)
                for _ in 0..<6 {
                    p = CGPoint(x: p.x + rng.cg(-9...9), y: p.y + rng.cg(4...10))
                    ctx.addLine(to: p)
                }
                ctx.strokePath()
            }
        }
    }

    // MARK: Variation (technical)

    /// Red = large soft blotches, green = medium noise. Seamless periodic value noise.
    static func variation(_ size: CGSize, seed: UInt64) -> UIImage? {
        let width = Int(size.width), height = Int(size.height)
        let large = PeriodicNoise(period: 4, seed: seed)
        let large2 = PeriodicNoise(period: 8, seed: seed &+ 1)
        let medium = PeriodicNoise(period: 16, seed: seed &+ 2)
        let medium2 = PeriodicNoise(period: 32, seed: seed &+ 3)
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let u = Double(x) / Double(width), v = Double(y) / Double(height)
                let r = large.value(u, v) * 0.65 + large2.value(u, v) * 0.35
                let g = medium.value(u, v) * 0.6 + medium2.value(u, v) * 0.4
                let i = (y * width + x) * 4
                bytes[i] = UInt8(max(0, min(255, r * 255)))
                bytes[i + 1] = UInt8(max(0, min(255, g * 255)))
                bytes[i + 2] = 128
            }
        }
        guard let image = RawImage.cgImage(rgbx: bytes, width: width, height: height) else { return nil }
        return UIImage(cgImage: image)
    }

    // MARK: Helpers

    /// A small stone with a lit top-left and shaded bottom-right.
    static func pebble(_ ctx: CGContext, _ p: CGPoint, _ r: CGFloat, _ color: UIColor) {
        Paint.dab(ctx, CGPoint(x: p.x + r * 0.25, y: p.y + r * 0.3), r, r * 0.75, UIColor.black.withAlpha(0.18))
        Paint.dab(ctx, p, r, r * 0.75, color)
        Paint.dab(ctx, CGPoint(x: p.x - r * 0.3, y: p.y - r * 0.25), r * 0.45, r * 0.3, UIColor.white.withAlpha(0.25))
    }
}

/// Value noise that repeats every unit square (u, v in 0…1), for seamless textures.
struct PeriodicNoise {
    let period: Int
    private let lattice: [Double]

    init(period: Int, seed: UInt64) {
        self.period = period
        var rng = SeededRandom(seed: seed)
        lattice = (0..<(period * period)).map { _ in rng.nextUnit() }
    }

    func value(_ u: Double, _ v: Double) -> Double {
        let x = u * Double(period), y = v * Double(period)
        let x0 = Int(x.rounded(.down)), y0 = Int(y.rounded(.down))
        let tx = smooth(x - Double(x0)), ty = smooth(y - Double(y0))
        let a = at(x0, y0), b = at(x0 + 1, y0), c = at(x0, y0 + 1), d = at(x0 + 1, y0 + 1)
        let top = a + (b - a) * tx, bottom = c + (d - c) * tx
        return top + (bottom - top) * ty
    }

    private func at(_ x: Int, _ y: Int) -> Double {
        let px = ((x % period) + period) % period
        let py = ((y % period) + period) % period
        return lattice[py * period + px]
    }

    private func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }
}

/// Builds CGImages from raw bytes (used for data textures like splat maps).
enum RawImage {
    /// `bytes` is RGBX, 4 bytes per pixel, rows top to bottom. The 4th byte is ignored.
    static func cgImage(rgbx bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// `bytes` is premultiplied RGBA, 4 bytes per pixel, rows top to bottom.
    static func cgImage(rgba bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
