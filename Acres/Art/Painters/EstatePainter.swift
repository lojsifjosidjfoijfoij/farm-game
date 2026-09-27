import UIKit
import AcresCore

/// The farm's own additions (Phase 8): the storage shed, silos and
/// sprinklers, plus the sprinkler icons.
enum EstatePainter {

    static func paint(_ spec: AssetSpec, rng: inout SeededRandom) -> UIImage? {
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        let ground = size.height * (1 - CGFloat(spec.anchorY))
        switch spec.name {
        case "building_storage_shed": return shed(size, ground: ground, rng: &rng)
        case "building_silo": return silo(size, ground: ground)
        case "prop_sprinkler": return Canvas.image(size) { sprinkler($0, size: size, ground: ground, pro: false) }
        case "prop_sprinkler_pro": return Canvas.image(size) { sprinkler($0, size: size, ground: ground, pro: true) }
        case "item_sprinkler":
            return Canvas.image(size) { sprinkler($0, size: size, ground: size.height * 0.86, pro: false, icon: true) }
        case "item_sprinkler_pro":
            return Canvas.image(size) { sprinkler($0, size: size, ground: size.height * 0.88, pro: true, icon: true) }
        default: return nil
        }
    }

    private static let ink = UIColor(hex: 0x2E2419).withAlpha(0.55)

    // MARK: Storage shed

    static func shed(_ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        let wood = UIColor(hex: 0xA8744A), roof = UIColor(hex: 0x5B6B5A), trim = UIColor(hex: 0xEDE4D0)
        return Canvas.image(size) { ctx in
            let wall = CGRect(x: w * 0.12, y: h * 0.5, width: w * 0.76, height: ground - h * 0.5)
            // Roof: back slope, then the front slope over the wall.
            let ridge = h * 0.2
            let back = Paint.polygon([CGPoint(x: wall.minX + 10, y: ridge), CGPoint(x: wall.maxX - 10, y: ridge),
                                      CGPoint(x: wall.maxX - 18, y: ridge - h * 0.07), CGPoint(x: wall.minX + 18, y: ridge - h * 0.07)])
            let front = Paint.polygon([CGPoint(x: wall.minX - 14, y: wall.minY + 4), CGPoint(x: wall.maxX + 14, y: wall.minY + 4),
                                       CGPoint(x: wall.maxX - 10, y: ridge), CGPoint(x: wall.minX + 10, y: ridge)])
            Paint.outline(ctx, back, ink, width: 3)
            Paint.fill(ctx, back, top: roof.shaded(-0.18), bottom: roof.shaded(-0.1))
            Paint.outline(ctx, front, ink, width: 3)
            Paint.fill(ctx, front, top: roof.shaded(0.06), bottom: roof.shaded(-0.1))
            Paint.clipped(ctx, to: front) {
                ctx.setStrokeColor(roof.shaded(-0.25).withAlpha(0.5).cgColor)
                ctx.setLineWidth(3)
                var x = wall.minX - 20
                while x < wall.maxX + 20 {
                    ctx.move(to: CGPoint(x: x, y: ridge)); ctx.addLine(to: CGPoint(x: x - 8, y: wall.minY + 6))
                    x += 22
                }
                ctx.strokePath()
            }
            // Plank walls.
            let wallPath = Paint.roundedRect(wall, 3)
            Paint.outline(ctx, wallPath, ink, width: 3)
            Paint.fill(ctx, wallPath, top: wood.shaded(0.04), bottom: wood.shaded(-0.1))
            Paint.clipped(ctx, to: wallPath) {
                ctx.setStrokeColor(wood.shaded(-0.28).withAlpha(0.55).cgColor)
                ctx.setLineWidth(2.5)
                var x = wall.minX + 16
                while x < wall.maxX {
                    ctx.move(to: CGPoint(x: x, y: wall.minY)); ctx.addLine(to: CGPoint(x: x, y: wall.maxY))
                    x += 19 + rng.cg(-2...2)
                }
                ctx.strokePath()
                ctx.drawLinearGradient(Paint.gradient([UIColor.black.withAlpha(0.3), UIColor.black.withAlpha(0)]),
                                       start: CGPoint(x: 0, y: wall.minY), end: CGPoint(x: 0, y: wall.minY + 26), options: [])
            }
            // Big double doors with cross braces.
            let door = CGRect(x: wall.midX - wall.width * 0.26, y: wall.minY + wall.height * 0.22,
                              width: wall.width * 0.52, height: wall.maxY - wall.minY - wall.height * 0.22)
            Paint.fill(ctx, Paint.roundedRect(door, 3), top: UIColor(hex: 0x7A4F30), bottom: UIColor(hex: 0x5E3C24))
            ctx.setStrokeColor(trim.cgColor)
            ctx.setLineWidth(6)
            ctx.stroke(door.insetBy(dx: 3, dy: 3))
            for half in [CGRect(x: door.minX, y: door.minY, width: door.width / 2, height: door.height),
                         CGRect(x: door.midX, y: door.minY, width: door.width / 2, height: door.height)] {
                ctx.move(to: CGPoint(x: half.minX + 6, y: half.minY + 6)); ctx.addLine(to: CGPoint(x: half.maxX - 6, y: half.maxY - 6))
                ctx.move(to: CGPoint(x: half.maxX - 6, y: half.minY + 6)); ctx.addLine(to: CGPoint(x: half.minX + 6, y: half.maxY - 6))
            }
            ctx.strokePath()
            ctx.move(to: CGPoint(x: door.midX, y: door.minY)); ctx.addLine(to: CGPoint(x: door.midX, y: door.maxY))
            ctx.setLineWidth(3)
            ctx.strokePath()
            // A crate and a sack by the door.
            let crate = CGRect(x: wall.maxX - wall.width * 0.16, y: ground - 40, width: 40, height: 36)
            Paint.fill(ctx, Paint.roundedRect(crate, 3), top: UIColor(hex: 0xC9A06A), bottom: UIColor(hex: 0x9C7446))
            Paint.outline(ctx, Paint.roundedRect(crate, 3), ink, width: 2)
            Paint.dab(ctx, CGPoint(x: wall.minX + 26, y: ground - 20), 20, 22, UIColor(hex: 0xD8C9A0))
            Paint.dab(ctx, CGPoint(x: wall.minX + 26, y: ground - 40), 12, 6, UIColor(hex: 0xBFAE82))
        }
    }

    // MARK: Silo

    static func silo(_ size: CGSize, ground: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        let metal = UIColor(hex: 0xC8CDD2), band = UIColor(hex: 0x9AA2AA)
        return Canvas.image(size) { ctx in
            let body = CGRect(x: w * 0.16, y: h * 0.24, width: w * 0.68, height: ground - h * 0.24 - 10)
            let bodyPath = Paint.roundedRect(body, 6)
            Paint.outline(ctx, bodyPath, ink, width: 3)
            Paint.fillHorizontal(ctx, bodyPath, left: metal.shaded(0.12), right: metal.shaded(-0.22))
            Paint.clipped(ctx, to: bodyPath) {
                ctx.setStrokeColor(band.withAlpha(0.8).cgColor)
                ctx.setLineWidth(4)
                var y = body.minY + 36
                while y < body.maxY {
                    ctx.move(to: CGPoint(x: body.minX, y: y)); ctx.addQuadCurve(to: CGPoint(x: body.maxX, y: y), control: CGPoint(x: body.midX, y: y + 10))
                    y += 46
                }
                ctx.strokePath()
                ctx.setFillColor(UIColor.white.withAlpha(0.25).cgColor)
                ctx.fill(CGRect(x: body.minX + body.width * 0.18, y: body.minY, width: body.width * 0.08, height: body.height))
            }
            // Conical roof.
            let roof = Paint.polygon([CGPoint(x: body.minX - 8, y: body.minY + 6), CGPoint(x: body.maxX + 8, y: body.minY + 6),
                                      CGPoint(x: body.midX + 10, y: h * 0.08), CGPoint(x: body.midX - 10, y: h * 0.08)])
            Paint.outline(ctx, roof, ink, width: 3)
            Paint.fillHorizontal(ctx, roof, left: UIColor(hex: 0xB84A3A).shaded(0.08), right: UIColor(hex: 0x8C3428))
            Paint.dab(ctx, CGPoint(x: body.midX, y: h * 0.075), 12, 8, UIColor(hex: 0x8C3428))
            // Ladder up the right side.
            let rail = UIColor(hex: 0x6E757C)
            for x in [body.maxX - 30, body.maxX - 14] {
                ctx.setStrokeColor(rail.cgColor)
                ctx.setLineWidth(3)
                ctx.move(to: CGPoint(x: x, y: body.minY + 20)); ctx.addLine(to: CGPoint(x: x, y: body.maxY))
                ctx.strokePath()
            }
            var y = body.minY + 30
            while y < body.maxY {
                ctx.move(to: CGPoint(x: body.maxX - 30, y: y)); ctx.addLine(to: CGPoint(x: body.maxX - 14, y: y))
                y += 16
            }
            ctx.strokePath()
            // Concrete foot.
            let foot = CGRect(x: body.minX - 10, y: ground - 16, width: body.width + 20, height: 16)
            Paint.fill(ctx, Paint.roundedRect(foot, 4), top: UIColor(hex: 0xB9B4AA), bottom: UIColor(hex: 0x908A80))
        }
    }

    // MARK: Sprinklers

    /// A brass sprinkler head on a stake (or a big one on a green stand).
    static func sprinkler(_ ctx: CGContext, size: CGSize, ground: CGFloat, pro: Bool, icon: Bool = false) {
        let w = size.width, h = size.height
        let s = w / 100  // design units
        let brass = UIColor(hex: 0xC99A3E), green = UIColor(hex: 0x4E8A4A)
        if icon {
            Paint.dab(ctx, CGPoint(x: w / 2, y: ground), 30 * s, 8 * s, UIColor.black.withAlpha(0.15))
        }
        if pro {
            // Tripod.
            for dx in [-26.0, 0, 26] as [CGFloat] {
                Paint.stroke(ctx, from: CGPoint(x: w / 2, y: h * 0.42), to: CGPoint(x: w / 2 + dx * s, y: ground), bend: 0,
                             width: 6 * s, color: green.shaded(dx == 0 ? -0.15 : 0))
            }
            let hub = CGRect(x: w / 2 - 12 * s, y: h * 0.3, width: 24 * s, height: 18 * s)
            Paint.fill(ctx, Paint.roundedRect(hub, 5 * s), top: brass.shaded(0.12), bottom: brass.shaded(-0.15))
            Paint.outline(ctx, Paint.roundedRect(hub, 5 * s), ink, width: 2 * s)
            // Rotating arm with nozzles.
            Paint.stroke(ctx, from: CGPoint(x: w * 0.14, y: h * 0.3), to: CGPoint(x: w * 0.86, y: h * 0.24), bend: -6 * s,
                         width: 6 * s, color: brass.shaded(-0.05))
            for x in [w * 0.14, w * 0.86] {
                Paint.dab(ctx, CGPoint(x: x, y: x < w / 2 ? h * 0.3 : h * 0.24), 6 * s, 6 * s, brass.shaded(0.1))
            }
        } else {
            Paint.stroke(ctx, from: CGPoint(x: w / 2, y: ground), to: CGPoint(x: w / 2, y: h * 0.45), bend: 0,
                         width: 8 * s, color: UIColor(hex: 0x6E5238))
            let body = CGRect(x: w / 2 - 16 * s, y: h * 0.3, width: 32 * s, height: 22 * s)
            Paint.outline(ctx, Paint.roundedRect(body, 6 * s), ink, width: 3 * s)
            Paint.fill(ctx, Paint.roundedRect(body, 6 * s), top: brass.shaded(0.15), bottom: brass.shaded(-0.18))
            Paint.dab(ctx, CGPoint(x: w / 2, y: h * 0.28), 9 * s, 7 * s, brass.shaded(0.25))
        }
        // A little spray fan.
        let spray = UIColor(hex: 0x8CC8E6).withAlpha(0.75)
        for k in 0..<5 {
            let angle = -CGFloat.pi * (0.15 + 0.175 * CGFloat(k))
            let from = CGPoint(x: w / 2, y: h * 0.22)
            let to = CGPoint(x: from.x + cos(angle) * 34 * s, y: from.y + sin(angle) * 18 * s)
            Paint.dab(ctx, to, 3.5 * s, 3.5 * s, spray)
        }
    }
}
