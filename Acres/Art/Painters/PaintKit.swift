import UIKit
import AcresCore

// Small toolkit for the procedural placeholder art.
//
// All placeholder painters draw with Core Graphics into bitmaps at the pixel
// size listed in the asset manifest. Coordinates are UIKit-style: origin at
// the top-left, y pointing down. The "painterly" look comes from layering many
// soft, slightly varied dabs and strokes instead of flat fills.

extension UIColor {
    /// `UIColor(hex: 0x7FA05A)`
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
    }

    /// Lighter (positive) or darker (negative) version, keeping the hue.
    func shaded(_ amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        // Darker shades get slightly more saturated, lighter ones slightly less: feels painted.
        let newS = min(1, max(0, s - amount * 0.35))
        return UIColor(hue: h, saturation: newS, brightness: min(1, max(0, b + amount)), alpha: a)
    }

    func mixed(with other: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        _ = getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        _ = other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: a1 + (a2 - a1) * t)
    }

    func withAlpha(_ alpha: CGFloat) -> UIColor { withAlphaComponent(alpha) }
}

extension SeededRandom {
    mutating func cg(_ range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat(next(in: Double(range.lowerBound)...Double(range.upperBound)))
    }

    mutating func chance(_ probability: Double) -> Bool { nextUnit() < probability }

    mutating func pick<T>(_ options: [T]) -> T {
        options[Int(nextUnit() * Double(options.count)) % options.count]
    }

    /// A random point inside a rectangle.
    mutating func point(in rect: CGRect) -> CGPoint {
        CGPoint(x: cg(rect.minX...rect.maxX), y: cg(rect.minY...rect.maxY))
    }

    /// Color with slight random brightness variation.
    mutating func vary(_ color: UIColor, _ amount: CGFloat) -> UIColor {
        color.shaded(cg(-amount...amount))
    }
}

enum Canvas {
    /// Renders an image at exactly `size` pixels (scale 1).
    static func image(_ size: CGSize, opaque: Bool = false, _ draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = opaque
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            draw(context.cgContext)
        }
    }
}

enum Paint {
    static let rgb = CGColorSpaceCreateDeviceRGB()

    static func gradient(_ colors: [UIColor], _ locations: [CGFloat]? = nil) -> CGGradient {
        let cgColors = colors.map(\.cgColor) as CFArray
        if let locations {
            return CGGradient(colorsSpace: rgb, colors: cgColors, locations: locations)!
        }
        return CGGradient(colorsSpace: rgb, colors: cgColors, locations: nil)!
    }

    /// Filled ellipse, optionally rotated (radians).
    static func dab(_ ctx: CGContext, _ center: CGPoint, _ rx: CGFloat, _ ry: CGFloat, _ color: UIColor, rotation: CGFloat = 0) {
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        if rotation != 0 { ctx.rotate(by: rotation) }
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
        ctx.restoreGState()
    }

    /// Soft round glow/blotch fading to transparent.
    static func softSpot(_ ctx: CGContext, _ center: CGPoint, _ radius: CGFloat, _ color: UIColor, scaleY: CGFloat = 1) {
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.scaleBy(x: 1, y: scaleY)
        let g = gradient([color, color.withAlpha(0)])
        ctx.drawRadialGradient(g, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: radius, options: [])
        ctx.restoreGState()
    }

    /// A short painted stroke (quadratic curve), e.g. a grass blade.
    static func stroke(_ ctx: CGContext, from a: CGPoint, to b: CGPoint, bend: CGFloat, width: CGFloat, color: UIColor) {
        let mid = CGPoint(x: (a.x + b.x) / 2 + bend, y: (a.y + b.y) / 2)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.move(to: a)
        ctx.addQuadCurve(to: b, control: mid)
        ctx.strokePath()
    }

    /// A lumpy, organic closed shape around `center` (canopies, bushes, rocks).
    static func blobPath(_ center: CGPoint, rx: CGFloat, ry: CGFloat, lumps: Int, lumpiness: CGFloat, rng: inout SeededRandom) -> CGPath {
        let count = max(5, lumps)
        var radii: [CGFloat] = []
        for _ in 0..<count { radii.append(1 + rng.cg(-lumpiness...lumpiness)) }
        let path = CGMutablePath()
        func point(_ i: Int) -> CGPoint {
            let angle = CGFloat(i) / CGFloat(count) * .pi * 2
            let r = radii[(i % count + count) % count]
            return CGPoint(x: center.x + cos(angle) * rx * r, y: center.y + sin(angle) * ry * r)
        }
        // Smooth closed curve through midpoints, using the points as controls.
        func midpoint(_ i: Int) -> CGPoint {
            let p = point(i), q = point(i + 1)
            return CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2)
        }
        path.move(to: midpoint(count - 1))
        for i in 0..<count {
            path.addQuadCurve(to: midpoint(i), control: point(i))
        }
        path.closeSubpath()
        return path
    }

    /// Fills a path with a vertical gradient (top color → bottom color).
    static func fill(_ ctx: CGContext, _ path: CGPath, top: UIColor, bottom: UIColor) {
        let box = path.boundingBoxOfPath
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(gradient([top, bottom]), start: CGPoint(x: box.midX, y: box.minY),
                               end: CGPoint(x: box.midX, y: box.maxY), options: [])
        ctx.restoreGState()
    }

    /// Fills a path with a horizontal gradient (left → right), for cylinders like trunks.
    static func fillHorizontal(_ ctx: CGContext, _ path: CGPath, left: UIColor, right: UIColor) {
        let box = path.boundingBoxOfPath
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(gradient([left, right]), start: CGPoint(x: box.minX, y: box.midY),
                               end: CGPoint(x: box.maxX, y: box.midY), options: [])
        ctx.restoreGState()
    }

    static func fill(_ ctx: CGContext, _ path: CGPath, _ color: UIColor) {
        ctx.addPath(path)
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
    }

    /// Gentle outline: a thin darker line, never pure black.
    static func outline(_ ctx: CGContext, _ path: CGPath, _ color: UIColor, width: CGFloat = 2) {
        ctx.addPath(path)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineJoin(.round)
        ctx.strokePath()
    }

    /// Runs `body` with drawing clipped to `path`.
    static func clipped(_ ctx: CGContext, to path: CGPath, _ body: () -> Void) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        body()
        ctx.restoreGState()
    }

    static func polygon(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points)
        path.closeSubpath()
        return path
    }

    static func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
        CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    /// Scatters leaf/texture dabs inside `path`: lighter toward the light
    /// (upper left), darker away from it.
    static func leafDabs(_ ctx: CGContext, in path: CGPath, base: UIColor, count: Int, size: ClosedRange<CGFloat>, rng: inout SeededRandom) {
        let box = path.boundingBoxOfPath
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        for _ in 0..<count {
            let p = rng.point(in: box)
            // Light comes from the upper left: -1 (lit) … +1 (shadow).
            let fx: CGFloat = (p.x - box.minX) / max(box.width, 1)
            let fy: CGFloat = (p.y - box.minY) / max(box.height, 1)
            let darkness: CGFloat = (fx * 0.6 + fy) / 1.6 * 2 - 1
            let jitter: CGFloat = rng.cg(-0.07...0.07)
            let shade: CGFloat = jitter - darkness * 0.14
            let r = rng.cg(size)
            dab(ctx, p, r, r * rng.cg(0.55...0.85), base.shaded(shade).withAlpha(rng.cg(0.55...0.9)), rotation: rng.cg(0...(.pi)))
        }
        ctx.restoreGState()
    }
}

/// Helpers for seamless (tileable) textures: anything drawn near an edge is
/// also drawn on the opposite side.
enum Tiling {
    static func wrapped(_ size: CGSize, _ point: CGPoint, margin: CGFloat, _ draw: (CGPoint) -> Void) {
        var xs: [CGFloat] = [0]
        var ys: [CGFloat] = [0]
        if point.x < margin { xs.append(size.width) }
        if point.x > size.width - margin { xs.append(-size.width) }
        if point.y < margin { ys.append(size.height) }
        if point.y > size.height - margin { ys.append(-size.height) }
        for dx in xs {
            for dy in ys {
                draw(CGPoint(x: point.x + dx, y: point.y + dy))
            }
        }
    }
}
