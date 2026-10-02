import UIKit
import AcresCore

/// Painted HUD icons: the tools on the farmer's belt. Drawn in a 96 × 96
/// design box (32 pt at 3×) and scaled to the asset's size.
enum UIIconPainter {

    static func paint(_ spec: AssetSpec) -> UIImage? {
        if spec.name == "ui_portrait_mentor" { return mentorPortrait(spec) }
        let draw: ((CGContext) -> Void)?
        switch spec.name {
        case "ui_icon_hand": draw = glove
        case "ui_icon_hoe": draw = hoe
        case "ui_icon_watering_can": draw = wateringCan
        case "ui_icon_sickle": draw = sickle
        case "ui_icon_axe": draw = axe
        case "ui_icon_rod": draw = rod
        default: draw = nil
        }
        guard let draw else { return nil }
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        return Canvas.image(size) { ctx in
            ctx.scaleBy(x: size.width / 96, y: size.height / 96)
            draw(ctx)
        }
    }

    /// Arne, head and shoulders, for his speech bubble. The figure is drawn by
    /// `FarmerPainter` on a larger virtual canvas so the head fills the frame.
    private static func mentorPortrait(_ spec: AssetSpec) -> UIImage {
        let side = CGFloat(spec.pixelWidth)
        let tom = FarmerPainter.Outfit(skin: UIColor(hex: 0xEAB994), hair: UIColor(hex: 0xC8C2BA), shirt: UIColor(hex: 0x5E8A45),
                                       trousers: UIColor(hex: 0x4F6FA3), boots: UIColor(hex: 0x5A3C28),
                                       overalls: true, checks: true, beard: true, hat: .straw)
        return Canvas.image(CGSize(width: side, height: side)) { ctx in
            // Head at 45 % of the height, shoulders near the bottom, centred.
            ctx.translateBy(x: -0.068 * side, y: 0)
            FarmerPainter.draw(ctx, size: CGSize(width: 1.136 * side, height: 1.84 * side), ground: 1.75 * side,
                               facing: .down, pose: .idle, outfit: tom)
        }
    }

    private static let wood = UIColor(hex: 0xA57A4C)
    private static let woodDark = UIColor(hex: 0x6E4B2E)
    private static let metal = UIColor(hex: 0xA9AFB5)
    private static let ink = UIColor(hex: 0x3A2A1C).withAlpha(0.7)

    /// A wooden handle with a dark edge.
    private static func handle(_ ctx: CGContext, from a: CGPoint, to b: CGPoint, width: CGFloat = 9) {
        Paint.stroke(ctx, from: a, to: b, bend: 0, width: width + 3, color: ink)
        Paint.stroke(ctx, from: a, to: b, bend: 0, width: width, color: wood)
        Paint.stroke(ctx, from: CGPoint(x: a.x - 1.5, y: a.y - 1.5), to: CGPoint(x: b.x - 1.5, y: b.y - 1.5), bend: 0,
                     width: 2.5, color: UIColor.white.withAlpha(0.25))
    }

    private static func glove(_ ctx: CGContext) {
        let leather = UIColor(hex: 0xD9A45E)
        var parts: [CGPath] = [Paint.roundedRect(CGRect(x: 26, y: 40, width: 40, height: 42), 12)]
        for (i, height) in [30.0, 36, 34, 28].enumerated() {
            let x = 26 + CGFloat(i) * 10.5
            parts.append(Paint.roundedRect(CGRect(x: x, y: 50 - height, width: 10, height: height + 8), 5))
        }
        // The thumb, sticking out to the left.
        parts.append(Paint.polygon([CGPoint(x: 10, y: 46), CGPoint(x: 17, y: 41), CGPoint(x: 34, y: 54),
                                    CGPoint(x: 32, y: 66), CGPoint(x: 24, y: 64), CGPoint(x: 9, y: 52)]))
        for part in parts { Paint.outline(ctx, part, ink, width: 5) }
        for part in parts { Paint.fill(ctx, part, top: leather.shaded(0.08), bottom: leather.shaded(-0.1)) }
        // Cuff.
        let cuff = Paint.roundedRect(CGRect(x: 24, y: 76, width: 44, height: 12), 4)
        Paint.outline(ctx, cuff, ink, width: 4)
        Paint.fill(ctx, cuff, UIColor(hex: 0x8C5A34))
    }

    private static func hoe(_ ctx: CGContext) {
        handle(ctx, from: CGPoint(x: 20, y: 86), to: CGPoint(x: 70, y: 16))
        let blade = Paint.polygon([CGPoint(x: 62, y: 12), CGPoint(x: 86, y: 18), CGPoint(x: 84, y: 42), CGPoint(x: 74, y: 44),
                                   CGPoint(x: 72, y: 24), CGPoint(x: 60, y: 20)])
        Paint.outline(ctx, blade, ink, width: 5)
        Paint.fill(ctx, blade, top: metal.shaded(0.12), bottom: metal.shaded(-0.15))
    }

    private static func wateringCan(_ ctx: CGContext) {
        let green = UIColor(hex: 0x5E9E4C)
        // Spout and rose.
        Paint.stroke(ctx, from: CGPoint(x: 34, y: 60), to: CGPoint(x: 10, y: 32), bend: 0, width: 11, color: ink)
        Paint.stroke(ctx, from: CGPoint(x: 34, y: 60), to: CGPoint(x: 10, y: 32), bend: 0, width: 7, color: green.shaded(-0.1))
        let rose = CGPath(ellipseIn: CGRect(x: 2, y: 22, width: 16, height: 14), transform: nil)
        Paint.outline(ctx, rose, ink, width: 4)
        Paint.fill(ctx, rose, green.shaded(-0.2))
        // Handle over the top.
        ctx.setStrokeColor(ink.cgColor)
        ctx.setLineWidth(10)
        ctx.move(to: CGPoint(x: 44, y: 44)); ctx.addQuadCurve(to: CGPoint(x: 80, y: 50), control: CGPoint(x: 66, y: 10))
        ctx.strokePath()
        ctx.setStrokeColor(green.shaded(-0.05).cgColor)
        ctx.setLineWidth(6)
        ctx.move(to: CGPoint(x: 44, y: 44)); ctx.addQuadCurve(to: CGPoint(x: 80, y: 50), control: CGPoint(x: 66, y: 10))
        ctx.strokePath()
        // Body.
        let body = Paint.roundedRect(CGRect(x: 30, y: 42, width: 52, height: 42), 9)
        Paint.outline(ctx, body, ink, width: 5)
        Paint.fill(ctx, body, top: green.shaded(0.1), bottom: green.shaded(-0.12))
        ctx.setFillColor(UIColor.white.withAlpha(0.25).cgColor)
        ctx.fill(CGRect(x: 36, y: 48, width: 6, height: 28))
        // Water drops.
        for (x, y) in [(6.0, 46.0), (14, 54), (4, 60)] {
            Paint.dab(ctx, CGPoint(x: x, y: y), 3, 4, UIColor(hex: 0x7EC0E0))
        }
    }

    private static func sickle(_ ctx: CGContext) {
        // The curved blade: an arc over the top, from the handle end round to a point.
        let center = CGPoint(x: 50, y: 50), radius: CGFloat = 30
        func point(_ degrees: CGFloat, _ r: CGFloat) -> CGPoint {
            let a = degrees * .pi / 180
            return CGPoint(x: center.x + cos(a) * r, y: center.y - sin(a) * r)
        }
        let blade = CGMutablePath()
        let outer = stride(from: CGFloat(215), through: -10, by: -5).map { point($0, radius) }
        let inner = stride(from: CGFloat(-10), through: 200, by: 5).map { point($0, radius - 11 + ($0 + 10) / 210 * 7) }
        blade.addLines(between: outer + inner)
        blade.closeSubpath()
        Paint.outline(ctx, blade, ink, width: 5)
        Paint.fill(ctx, blade, top: metal.shaded(0.15), bottom: metal.shaded(-0.1))
        handle(ctx, from: point(212, radius - 4), to: CGPoint(x: 14, y: 88), width: 10)
    }

    private static func rod(_ ctx: CGContext) {
        // A bamboo rod leaning across, the line hanging to a bobber.
        Paint.stroke(ctx, from: CGPoint(x: 14, y: 90), to: CGPoint(x: 84, y: 8), bend: -4, width: 9, color: ink)
        Paint.stroke(ctx, from: CGPoint(x: 14, y: 90), to: CGPoint(x: 84, y: 8), bend: -4, width: 6, color: UIColor(hex: 0xD9B464))
        for t in [0.3, 0.5, 0.7] as [CGFloat] {
            let p = CGPoint(x: 14 + 70 * t, y: 90 - 82 * t)
            Paint.dab(ctx, p, 5, 2, UIColor(hex: 0x8A6A2E), rotation: -0.86)
        }
        Paint.dab(ctx, CGPoint(x: 26, y: 76), 8, 8, UIColor(hex: 0x6E757C))
        Paint.dab(ctx, CGPoint(x: 26, y: 76), 3, 3, UIColor(hex: 0x3A3E42))
        Paint.stroke(ctx, from: CGPoint(x: 84, y: 8), to: CGPoint(x: 80, y: 62), bend: 3, width: 1.6, color: UIColor(hex: 0x3A3A3A))
        let ball = CGPath(ellipseIn: CGRect(x: 71, y: 60, width: 18, height: 18), transform: nil)
        Paint.outline(ctx, ball, ink, width: 3)
        Paint.fill(ctx, ball, UIColor.white)
        Paint.clipped(ctx, to: ball) {
            ctx.setFillColor(UIColor(hex: 0xD8403A).cgColor)
            ctx.fill(CGRect(x: 70, y: 58, width: 20, height: 10))
        }
    }

    private static func axe(_ ctx: CGContext) {
        handle(ctx, from: CGPoint(x: 24, y: 88), to: CGPoint(x: 62, y: 14))
        let head = Paint.polygon([CGPoint(x: 52, y: 14), CGPoint(x: 70, y: 10), CGPoint(x: 90, y: 4), CGPoint(x: 88, y: 42),
                                  CGPoint(x: 70, y: 32), CGPoint(x: 54, y: 30)])
        Paint.outline(ctx, head, ink, width: 5)
        Paint.fill(ctx, head, top: metal.shaded(0.1), bottom: metal.shaded(-0.18))
        Paint.stroke(ctx, from: CGPoint(x: 86, y: 8), to: CGPoint(x: 84, y: 38), bend: 2, width: 3, color: UIColor.white.withAlpha(0.6))
    }
}
