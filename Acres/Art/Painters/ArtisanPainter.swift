import UIKit
import AcresCore

/// Workshops (as they stand on the farm and as pouch icons) and the goods
/// they make: jars, bottles, sacks, cheeses, planks and cloth.
enum ArtisanPainter {

    static func paint(_ spec: AssetSpec, rng: inout SeededRandom) -> UIImage? {
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        if spec.name.hasPrefix("prop_workshop_") {
            let kind = String(spec.name.dropFirst("prop_workshop_".count))
            guard WorkshopCatalog.workshop(kind) != nil else { return nil }
            let ground = size.height * (1 - CGFloat(spec.anchorY))
            return Canvas.image(size) { ctx in
                Paint.dab(ctx, CGPoint(x: size.width / 2, y: ground - 2), size.width * 0.42, size.width * 0.1, UIColor.black.withAlpha(0.16))
                workshop(ctx, kind, foot: CGPoint(x: size.width / 2, y: ground), s: size.width / 100, rng: &rng)
            }
        }
        guard spec.name.hasPrefix("item_") else { return nil }
        let name = String(spec.name.dropFirst("item_".count))
        if WorkshopCatalog.workshop(name) != nil {
            return Canvas.image(size) { ctx in
                workshop(ctx, name, foot: CGPoint(x: size.width / 2, y: size.height * 0.92), s: size.width / 118, rng: &rng)
            }
        }
        guard let draw = goods(name) else { return nil }
        return Canvas.image(size) { ctx in
            draw(ctx, CGPoint(x: size.width / 2, y: size.height / 2), size.width / 100)
        }
    }

    private static let ink = UIColor(hex: 0x2E2419).withAlpha(0.55)
    private static let wood = UIColor(hex: 0xA5784A)
    private static let woodDark = UIColor(hex: 0x6E4B2E)

    // MARK: Goods

    private static func goods(_ name: String) -> ((CGContext, CGPoint, CGFloat) -> Void)? {
        switch name {
        case "strawberry_jam": { jar($0, $1, $2, fill: UIColor(hex: 0xC8283A), lid: UIColor(hex: 0xD84A4A)) }
        case "blueberry_jam": { jar($0, $1, $2, fill: UIColor(hex: 0x3E3A7A), lid: UIColor(hex: 0x5A6FB8)) }
        case "tomato_sauce": { jar($0, $1, $2, fill: UIColor(hex: 0xD8412F), lid: UIColor(hex: 0x4E8A4A)) }
        case "honey": { jar($0, $1, $2, fill: UIColor(hex: 0xE8A628), lid: UIColor(hex: 0xC9A06A), honey: true) }
        case "pickled_onions": { jar($0, $1, $2, fill: UIColor(hex: 0xE6DDA0), lid: UIColor(hex: 0x8A9A5A), balls: UIColor(hex: 0xF4EEDC)) }
        case "sauerkraut": { jar($0, $1, $2, fill: UIColor(hex: 0xD9D39A), lid: UIColor(hex: 0x7A8A6A), strands: true) }
        case "apple_juice": { bottle($0, $1, $2, fill: UIColor(hex: 0xE3B03A), label: UIColor(hex: 0xC8403A)) }
        case "carrot_juice": { bottle($0, $1, $2, fill: UIColor(hex: 0xEE8A2E), label: UIColor(hex: 0x4E8A4A)) }
        case "cherry_juice": { bottle($0, $1, $2, fill: UIColor(hex: 0x9A1E30), label: UIColor(hex: 0xF4ECD8)) }
        case "sunflower_oil": { bottle($0, $1, $2, fill: UIColor(hex: 0xF2C93E), label: UIColor(hex: 0x6E4A26), tall: true) }
        case "flour": { sack($0, $1, $2, color: UIColor(hex: 0xF2ECDC), mark: UIColor(hex: 0xD9B04F)) }
        case "cornmeal": { sack($0, $1, $2, color: UIColor(hex: 0xEAD9A0), mark: UIColor(hex: 0xE0B43A)) }
        case "cheese": { cheese($0, $1, $2, color: UIColor(hex: 0xF2C85A), rind: UIColor(hex: 0xD9A23A)) }
        case "goat_cheese": { cheese($0, $1, $2, color: UIColor(hex: 0xF6F2E6), rind: UIColor(hex: 0xDCD4C0), herbs: true) }
        case "plank": { planks($0, $1, $2) }
        case "cloth": { cloth($0, $1, $2) }
        case "goat_milk": { jug($0, $1, $2) }
        default: nil
        }
    }

    private static func jar(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat, fill: UIColor, lid: UIColor, honey: Bool = false,
                            balls: UIColor? = nil, strands: Bool = false) {
        let body = Paint.roundedRect(CGRect(x: c.x - 27 * s, y: c.y - 22 * s, width: 54 * s, height: 60 * s), 12 * s)
        Paint.outline(ctx, body, ink, width: 2.5 * s)
        Paint.fill(ctx, body, top: fill.shaded(0.1), bottom: fill.shaded(-0.15))
        Paint.clipped(ctx, to: body) {
            if let balls {
                for (dx, dy) in [(-12, 0), (10, 4), (-2, 18), (14, 22), (-14, 26)] as [(CGFloat, CGFloat)] {
                    Paint.dab(ctx, CGPoint(x: c.x + dx * s, y: c.y + dy * s), 8 * s, 8 * s, balls)
                }
            }
            if strands {
                ctx.setStrokeColor(UIColor(hex: 0xF0EBC0).cgColor)
                ctx.setLineWidth(2 * s)
                for k in 0..<7 {
                    let y = c.y + (CGFloat(k) * 8 - 16) * s
                    ctx.move(to: CGPoint(x: c.x - 26 * s, y: y))
                    ctx.addQuadCurve(to: CGPoint(x: c.x + 26 * s, y: y + 3 * s), control: CGPoint(x: c.x, y: y - 6 * s))
                }
                ctx.strokePath()
            }
            ctx.setFillColor(UIColor.white.withAlpha(0.3).cgColor)
            ctx.fill(CGRect(x: c.x - 20 * s, y: c.y - 18 * s, width: 7 * s, height: 50 * s))
        }
        // Paper label.
        let label = Paint.roundedRect(CGRect(x: c.x - 18 * s, y: c.y + 2 * s, width: 36 * s, height: 20 * s), 3 * s)
        Paint.fill(ctx, label, UIColor(hex: 0xF4ECD8))
        Paint.outline(ctx, label, ink, width: 1.2 * s)
        Paint.dab(ctx, CGPoint(x: c.x, y: c.y + 12 * s), 9 * s, 5 * s, fill.withAlpha(0.8))
        // Cloth lid tied with string.
        let top = Paint.polygon([CGPoint(x: c.x - 30 * s, y: c.y - 24 * s), CGPoint(x: c.x + 30 * s, y: c.y - 24 * s),
                                 CGPoint(x: c.x + 22 * s, y: c.y - 38 * s), CGPoint(x: c.x - 22 * s, y: c.y - 38 * s)])
        Paint.outline(ctx, top, ink, width: 2 * s)
        Paint.fill(ctx, top, top: lid.shaded(0.1), bottom: lid.shaded(-0.1))
        ctx.setFillColor(UIColor(hex: 0xE8DCC0).cgColor)
        ctx.fill(CGRect(x: c.x - 28 * s, y: c.y - 27 * s, width: 56 * s, height: 3 * s))
        if honey {
            Paint.stroke(ctx, from: CGPoint(x: c.x + 18 * s, y: c.y - 50 * s), to: CGPoint(x: c.x + 6 * s, y: c.y - 26 * s), bend: 0,
                         width: 4 * s, color: woodDark)
            Paint.dab(ctx, CGPoint(x: c.x + 20 * s, y: c.y - 52 * s), 6 * s, 5 * s, wood)
        }
    }

    private static func bottle(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat, fill: UIColor, label: UIColor, tall: Bool = false) {
        let h: CGFloat = tall ? 58 : 48
        let path = CGMutablePath()
        path.addPath(Paint.roundedRect(CGRect(x: c.x - 18 * s, y: c.y - 8 * s, width: 36 * s, height: h * s), 8 * s))
        path.addPath(Paint.roundedRect(CGRect(x: c.x - 8 * s, y: c.y - 36 * s, width: 16 * s, height: 32 * s), 4 * s))
        Paint.outline(ctx, path, ink, width: 2.5 * s)
        Paint.fill(ctx, path, top: fill.shaded(0.12), bottom: fill.shaded(-0.15))
        ctx.setFillColor(woodDark.cgColor)
        ctx.fill(CGRect(x: c.x - 7 * s, y: c.y - 42 * s, width: 14 * s, height: 8 * s))
        let tag = Paint.roundedRect(CGRect(x: c.x - 15 * s, y: c.y + 8 * s, width: 30 * s, height: 18 * s), 3 * s)
        Paint.fill(ctx, tag, label)
        Paint.dab(ctx, CGPoint(x: c.x - 10 * s, y: c.y - 2 * s), 3 * s, 10 * s, UIColor.white.withAlpha(0.35))
    }

    private static func sack(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat, color: UIColor, mark: UIColor) {
        let body = Paint.polygon([
            CGPoint(x: c.x - 22 * s, y: c.y - 26 * s), CGPoint(x: c.x + 22 * s, y: c.y - 26 * s),
            CGPoint(x: c.x + 34 * s, y: c.y + 30 * s), CGPoint(x: c.x + 26 * s, y: c.y + 40 * s),
            CGPoint(x: c.x - 26 * s, y: c.y + 40 * s), CGPoint(x: c.x - 34 * s, y: c.y + 30 * s),
        ])
        Paint.outline(ctx, body, ink, width: 2.5 * s)
        Paint.fill(ctx, body, top: color.shaded(0.06), bottom: color.shaded(-0.14))
        // Tied top.
        Paint.dab(ctx, CGPoint(x: c.x, y: c.y - 30 * s), 16 * s, 8 * s, color.shaded(-0.05))
        ctx.setFillColor(UIColor(hex: 0x9A7148).cgColor)
        ctx.fill(CGRect(x: c.x - 16 * s, y: c.y - 27 * s, width: 32 * s, height: 4 * s))
        // A wheat-ear mark.
        for k in -1...1 {
            Paint.dab(ctx, CGPoint(x: c.x + CGFloat(k) * 7 * s, y: c.y + 8 * s - abs(CGFloat(k)) * 3 * s), 3.5 * s, 9 * s, mark,
                      rotation: CGFloat(k) * 0.4)
        }
        Paint.stroke(ctx, from: CGPoint(x: c.x, y: c.y + 26 * s), to: CGPoint(x: c.x, y: c.y + 12 * s), bend: 0, width: 2 * s, color: mark)
    }

    private static func cheese(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat, color: UIColor, rind: UIColor, herbs: Bool = false) {
        // A wheel with a wedge cut out.
        let wheel = CGPath(ellipseIn: CGRect(x: c.x - 38 * s, y: c.y - 8 * s, width: 76 * s, height: 44 * s), transform: nil)
        Paint.outline(ctx, wheel, ink, width: 2.5 * s)
        Paint.fill(ctx, wheel, top: rind.shaded(0.05), bottom: rind.shaded(-0.18))
        let top = CGPath(ellipseIn: CGRect(x: c.x - 38 * s, y: c.y - 24 * s, width: 76 * s, height: 36 * s), transform: nil)
        Paint.outline(ctx, top, ink, width: 2 * s)
        Paint.fill(ctx, top, top: color.shaded(0.1), bottom: color.shaded(-0.05))
        if herbs {
            for (dx, dy) in [(-18, -10), (6, -14), (16, -4), (-6, -2)] as [(CGFloat, CGFloat)] {
                Paint.dab(ctx, CGPoint(x: c.x + dx * s, y: c.y + dy * s), 3 * s, 1.5 * s, UIColor(hex: 0x5E8F3E), rotation: 0.6)
            }
        } else {
            for (dx, dy, r) in [(-16, -8, 4), (10, -12, 3), (18, -2, 2.5)] as [(CGFloat, CGFloat, CGFloat)] {
                Paint.dab(ctx, CGPoint(x: c.x + dx * s, y: c.y + dy * s), r * s, r * 0.7 * s, color.shaded(-0.18))
            }
        }
    }

    private static func planks(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat) {
        for k in 0..<3 {
            let rect = CGRect(x: c.x - 38 * s + CGFloat(k) * 4 * s, y: c.y + (18 - CGFloat(k) * 14) * s, width: 72 * s, height: 12 * s)
            let path = Paint.roundedRect(rect, 2 * s)
            Paint.outline(ctx, path, ink, width: 2 * s)
            Paint.fill(ctx, path, top: UIColor(hex: 0xE2C08A), bottom: UIColor(hex: 0xC49A60))
            ctx.setStrokeColor(UIColor(hex: 0xA87C48).withAlpha(0.6).cgColor)
            ctx.setLineWidth(1.2 * s)
            ctx.move(to: CGPoint(x: rect.minX + 6 * s, y: rect.midY)); ctx.addLine(to: CGPoint(x: rect.maxX - 10 * s, y: rect.midY + 1 * s))
            ctx.strokePath()
        }
    }

    private static func cloth(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat) {
        let bolt = Paint.roundedRect(CGRect(x: c.x - 36 * s, y: c.y - 14 * s, width: 72 * s, height: 34 * s), 16 * s)
        Paint.outline(ctx, bolt, ink, width: 2.5 * s)
        Paint.fill(ctx, bolt, top: UIColor(hex: 0x5A7AB8), bottom: UIColor(hex: 0x3E5A94))
        Paint.clipped(ctx, to: bolt) {
            ctx.setStrokeColor(UIColor(hex: 0xE8DCC0).withAlpha(0.7).cgColor)
            ctx.setLineWidth(2 * s)
            var x = c.x - 34 * s
            while x < c.x + 36 * s {
                ctx.move(to: CGPoint(x: x, y: c.y - 14 * s)); ctx.addLine(to: CGPoint(x: x, y: c.y + 20 * s))
                x += 10 * s
            }
            ctx.strokePath()
        }
        // The loose end draped down.
        let end = Paint.polygon([CGPoint(x: c.x + 10 * s, y: c.y + 18 * s), CGPoint(x: c.x + 34 * s, y: c.y + 18 * s),
                                 CGPoint(x: c.x + 38 * s, y: c.y + 40 * s), CGPoint(x: c.x + 6 * s, y: c.y + 40 * s)])
        Paint.outline(ctx, end, ink, width: 2 * s)
        Paint.fill(ctx, end, top: UIColor(hex: 0x4E6EAA), bottom: UIColor(hex: 0x3E5A94))
    }

    private static func jug(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat) {
        let body = CGMutablePath()
        body.addPath(CGPath(ellipseIn: CGRect(x: c.x - 26 * s, y: c.y - 12 * s, width: 52 * s, height: 50 * s), transform: nil))
        body.addPath(Paint.roundedRect(CGRect(x: c.x - 10 * s, y: c.y - 34 * s, width: 20 * s, height: 26 * s), 4 * s))
        Paint.outline(ctx, body, ink, width: 2.5 * s)
        Paint.fill(ctx, body, top: UIColor(hex: 0xF8F6F0), bottom: UIColor(hex: 0xDCD6C8))
        ctx.setStrokeColor(ink.cgColor)
        ctx.setLineWidth(5 * s)
        ctx.addArc(center: CGPoint(x: c.x + 26 * s, y: c.y + 6 * s), radius: 12 * s, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
        ctx.strokePath()
        ctx.setFillColor(UIColor(hex: 0x8C6A3A).cgColor)
        ctx.fill(CGRect(x: c.x - 11 * s, y: c.y - 38 * s, width: 22 * s, height: 6 * s))
        let tag = Paint.roundedRect(CGRect(x: c.x - 16 * s, y: c.y + 6 * s, width: 32 * s, height: 16 * s), 3 * s)
        Paint.fill(ctx, tag, UIColor(hex: 0xB8864A))
    }

    // MARK: Workshops

    /// A workshop standing on the ground at `foot` (design units of `s`, ~100 wide).
    static func workshop(_ ctx: CGContext, _ kind: String, foot f: CGPoint, s: CGFloat, rng: inout SeededRandom) {
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: f.x + x * s, y: f.y - y * s) }
        func beam(_ a: CGPoint, _ b: CGPoint, _ w: CGFloat = 6, _ color: UIColor = wood) {
            Paint.stroke(ctx, from: a, to: b, bend: 0, width: (w + 2.5) * s, color: ink)
            Paint.stroke(ctx, from: a, to: b, bend: 0, width: w * s, color: color)
        }
        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: UIColor, radius: CGFloat = 3) {
            let rect = CGRect(x: f.x + x * s, y: f.y - (y + h) * s, width: w * s, height: h * s)
            let path = Paint.roundedRect(rect, radius * s)
            Paint.outline(ctx, path, ink, width: 2.5 * s)
            Paint.fill(ctx, path, top: color.shaded(0.08), bottom: color.shaded(-0.14))
        }
        switch kind {
        case "sawhorse":
            beam(P(-34, 0), P(-22, 34)); beam(P(-10, 0), P(-22, 34))
            beam(P(22, 0), P(34, 34)); beam(P(46, 0), P(34, 34))
            let log = Paint.roundedRect(CGRect(x: f.x - 42 * s, y: f.y - 50 * s, width: 90 * s, height: 20 * s), 10 * s)
            Paint.outline(ctx, log, ink, width: 2.5 * s)
            Paint.fill(ctx, log, top: UIColor(hex: 0x8A6440), bottom: woodDark)
            Paint.dab(ctx, P(44, 40), 9 * s, 10 * s, UIColor(hex: 0xE2C08A))
            // A saw resting in the cut.
            let blade = Paint.polygon([P(-4, 70), P(24, 46), P(30, 52), P(4, 76)])
            Paint.fill(ctx, blade, top: UIColor(hex: 0xC9CED3), bottom: UIColor(hex: 0x9AA2AA))
            Paint.outline(ctx, blade, ink, width: 1.5 * s)
            beam(P(-10, 80), P(0, 72), 7, UIColor(hex: 0xB8432F))
        case "mill":
            // A little post windmill.
            let body = Paint.polygon([P(-24, 0), P(24, 0), P(18, 70), P(-18, 70)])
            Paint.outline(ctx, body, ink, width: 2.5 * s)
            Paint.fill(ctx, body, top: UIColor(hex: 0xEDE2C4), bottom: UIColor(hex: 0xC9B98E))
            let roof = Paint.polygon([P(-24, 68), P(24, 68), P(0, 94)])
            Paint.outline(ctx, roof, ink, width: 2.5 * s)
            Paint.fill(ctx, roof, top: UIColor(hex: 0xB84A3A), bottom: UIColor(hex: 0x8C3428))
            box(-7, 0, 14, 22, UIColor(hex: 0x6E4A30), radius: 2)
            let hub = P(0, 60)
            for k in 0..<4 {
                let a = CGFloat(k) * .pi / 2 + 0.4
                let tip = CGPoint(x: hub.x + cos(a) * 46 * s, y: hub.y + sin(a) * 46 * s)
                beam(hub, tip, 3.5, woodDark)
                let sail = Paint.polygon([CGPoint(x: hub.x + cos(a) * 14 * s, y: hub.y + sin(a) * 14 * s), tip,
                                          CGPoint(x: tip.x + cos(a + .pi / 2) * 10 * s, y: tip.y + sin(a + .pi / 2) * 10 * s),
                                          CGPoint(x: hub.x + cos(a) * 14 * s + cos(a + .pi / 2) * 10 * s,
                                                  y: hub.y + sin(a) * 14 * s + sin(a + .pi / 2) * 10 * s)])
                Paint.fill(ctx, sail, UIColor(hex: 0xF4ECD8).withAlpha(0.95))
                Paint.outline(ctx, sail, ink, width: 1.5 * s)
            }
            Paint.dab(ctx, hub, 5 * s, 5 * s, woodDark)
        case "beehive":
            beam(P(-26, 0), P(-26, 14), 5); beam(P(26, 0), P(26, 14), 5)
            box(-32, 14, 64, 26, UIColor(hex: 0xF2EEE4))
            box(-32, 40, 64, 26, UIColor(hex: 0xF2D48A))
            box(-36, 66, 72, 10, UIColor(hex: 0x8C6A3A), radius: 2)
            Paint.dab(ctx, P(0, 20), 8 * s, 2.5 * s, UIColor(hex: 0x3A2A1C))
            for _ in 0..<5 {
                let p = P(rng.cg(-40...40), rng.cg(40...96))
                Paint.dab(ctx, p, 3 * s, 2.4 * s, UIColor(hex: 0xE8B030))
                Paint.dab(ctx, CGPoint(x: p.x, y: p.y - 2 * s), 2.4 * s, 1.4 * s, UIColor.white.withAlpha(0.8))
            }
        case "jam_kitchen":
            box(-38, 0, 76, 40, UIColor(hex: 0x8A857C), radius: 4)
            box(-30, 8, 20, 18, UIColor(hex: 0x3A2E26), radius: 2)
            Paint.dab(ctx, P(-20, 14), 6 * s, 4 * s, UIColor(hex: 0xF08A3A))
            let pot = CGPath(ellipseIn: CGRect(x: f.x - 6 * s, y: f.y - 62 * s, width: 40 * s, height: 26 * s), transform: nil)
            Paint.outline(ctx, pot, ink, width: 2.5 * s)
            Paint.fill(ctx, pot, top: UIColor(hex: 0xD9905A), bottom: UIColor(hex: 0xA8603A))
            Paint.dab(ctx, P(14, 60), 16 * s, 4 * s, UIColor(hex: 0xC8283A))
            for dx in [-34.0, -24] as [CGFloat] {
                box(dx, 40, 9, 14, UIColor(hex: 0xC8283A), radius: 3)
            }
        case "pickling_crock":
            let crock = CGMutablePath()
            crock.addPath(CGPath(ellipseIn: CGRect(x: f.x - 30 * s, y: f.y - 66 * s, width: 60 * s, height: 66 * s), transform: nil))
            Paint.outline(ctx, crock, ink, width: 2.5 * s)
            Paint.fill(ctx, crock, top: UIColor(hex: 0xC99A6A), bottom: UIColor(hex: 0x8A5A3A))
            box(-24, 58, 48, 10, UIColor(hex: 0x8C6A3A), radius: 3)
            Paint.dab(ctx, P(0, 72), 6 * s, 4 * s, woodDark)
            ctx.setStrokeColor(UIColor(hex: 0x6E3E22).withAlpha(0.6).cgColor)
            ctx.setLineWidth(3 * s)
            ctx.move(to: P(-28, 34)); ctx.addQuadCurve(to: P(28, 34), control: P(0, 28))
            ctx.strokePath()
            box(34, 0, 12, 18, UIColor(hex: 0xE6DDA0), radius: 3)
        case "cheese_press":
            beam(P(-30, 0), P(-30, 76)); beam(P(30, 0), P(30, 76)); beam(P(-36, 76), P(36, 76), 8)
            box(-26, 0, 52, 12, UIColor(hex: 0x8C6A3A), radius: 2)
            let wheel = CGPath(ellipseIn: CGRect(x: f.x - 20 * s, y: f.y - 34 * s, width: 40 * s, height: 22 * s), transform: nil)
            Paint.outline(ctx, wheel, ink, width: 2 * s)
            Paint.fill(ctx, wheel, top: UIColor(hex: 0xF2C85A), bottom: UIColor(hex: 0xD9A23A))
            beam(P(0, 34), P(0, 76), 5, UIColor(hex: 0x9AA2AA))
            box(-18, 36, 36, 8, wood, radius: 2)
            beam(P(-22, 84), P(22, 84), 4, UIColor(hex: 0x6E757C))
        case "juice_press":
            box(-28, 0, 56, 44, UIColor(hex: 0x9A6A3E), radius: 8)
            ctx.setStrokeColor(UIColor(hex: 0x5A5048).cgColor)
            ctx.setLineWidth(3 * s)
            for y in [10.0, 32] as [CGFloat] {
                ctx.move(to: P(-28, y)); ctx.addLine(to: P(28, y))
            }
            ctx.strokePath()
            beam(P(-22, 44), P(-22, 72)); beam(P(22, 44), P(22, 72)); beam(P(-28, 72), P(28, 72), 7)
            beam(P(0, 50), P(0, 86), 5, UIColor(hex: 0x9AA2AA))
            beam(P(-16, 86), P(16, 86), 4, UIColor(hex: 0x6E757C))
            Paint.dab(ctx, P(32, 16), 6 * s, 3 * s, UIColor(hex: 0xE3B03A))
        case "oil_press":
            box(-34, 0, 68, 30, UIColor(hex: 0xB9B4AA), radius: 6)
            let stone = CGPath(ellipseIn: CGRect(x: f.x - 22 * s, y: f.y - 62 * s, width: 44 * s, height: 34 * s), transform: nil)
            Paint.outline(ctx, stone, ink, width: 2.5 * s)
            Paint.fill(ctx, stone, top: UIColor(hex: 0xA8A298), bottom: UIColor(hex: 0x7A746A))
            beam(P(0, 44), P(48, 70), 5)
            box(26, 0, 14, 24, UIColor(hex: 0xF2C93E), radius: 4)
        case "loom":
            beam(P(-34, 0), P(-34, 80)); beam(P(34, 0), P(34, 80)); beam(P(-40, 80), P(40, 80), 7); beam(P(-38, 20), P(38, 20), 6)
            ctx.setStrokeColor(UIColor(hex: 0xE8DCC0).cgColor)
            ctx.setLineWidth(1.4 * s)
            for k in 0..<12 {
                let x = -30 + CGFloat(k) * 5.4
                ctx.move(to: P(x, 22)); ctx.addLine(to: P(x, 78))
            }
            ctx.strokePath()
            box(-30, 22, 60, 26, UIColor(hex: 0x5A7AB8), radius: 1)
            beam(P(-36, 50), P(36, 50), 3, woodDark)
        default:
            box(-30, 0, 60, 50, wood)
        }
    }
}
