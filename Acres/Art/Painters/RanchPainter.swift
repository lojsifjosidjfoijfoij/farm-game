import UIKit
import AcresCore

/// Phase 4 placeholder art: animal houses, the livestock market, troughs,
/// goods icons (eggs, milk, logs, fruit …) and small effects.
enum RanchPainter {

    static let ink = UIColor(hex: 0x2E2218).withAlpha(0.55)

    static func paint(_ spec: AssetSpec, rng: inout SeededRandom) -> UIImage? {
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        let ground = size.height * (1 - CGFloat(spec.anchorY))
        switch spec.name {
        case "building_coop": return coop(size, ground: ground, rng: &rng)
        case "building_pigsty": return pigsty(size, ground: ground, rng: &rng)
        case "building_sheep_shelter": return sheepShelter(size, ground: ground, rng: &rng)
        case "building_livestock_market": return livestockMarket(size, ground: ground, rng: &rng)
        case "prop_water_trough": return trough(size, ground: ground, water: true)
        case "prop_water_trough_empty": return trough(size, ground: ground, water: false)
        case "prop_feeder": return feeder(size, ground: ground, rng: &rng)
        case "prop_sign_repair": return repairSign(size, ground: ground)
        case "fx_bubble": return bubble(size)
        case "fx_job_marker": return Canvas.image(size) { ctx in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            Paint.softSpot(ctx, c, size.width * 0.5, UIColor(hex: 0xFFE9A8).withAlpha(0.7))
            let ring = CGPath(ellipseIn: CGRect(x: c.x - size.width * 0.3, y: c.y - size.height * 0.3,
                                                width: size.width * 0.6, height: size.height * 0.6), transform: nil)
            Paint.outline(ctx, ring, UIColor(hex: 0xF6C548), width: size.width * 0.09)
            Paint.dab(ctx, c, size.width * 0.1, size.height * 0.1, UIColor(hex: 0xF6C548))
        }
        case "fx_heart": return heart(size)
        case "fx_wood_chip": return Canvas.image(size) { ctx in
            Paint.fill(ctx, Paint.polygon([CGPoint(x: size.width * 0.1, y: size.height * 0.4), CGPoint(x: size.width * 0.9, y: size.height * 0.2),
                                           CGPoint(x: size.width * 0.8, y: size.height * 0.7), CGPoint(x: size.width * 0.2, y: size.height * 0.85)]),
                       UIColor(hex: 0xC9A06A))
        }
        case "fx_feather": return Canvas.image(size) { ctx in
            Paint.dab(ctx, CGPoint(x: size.width / 2, y: size.height / 2), size.width * 0.18, size.height * 0.42, UIColor(hex: 0xF4EEE2), rotation: 0.5)
        }
        case "fx_zzz": return Canvas.image(size) { _ in
            VillagePainter.label("z", in: CGRect(origin: .zero, size: size), color: UIColor(hex: 0xEDEFF7))
        }
        default:
            if spec.name.hasPrefix("item_") { return goods(spec, size: size, rng: &rng) }
            return nil
        }
    }

    // MARK: Buildings

    /// A little gabled wooden house seen from the front (3/4), shared by the coop and shelters.
    private static func shed(_ ctx: CGContext, _ size: CGSize, ground: CGFloat, wall: UIColor, roof: UIColor,
                             wallTop: CGFloat, peak: CGFloat, open: Bool, rng: inout SeededRandom) {
        let w = size.width
        let left = w * 0.1, right = w * 0.9
        let depth = (ground - wallTop) * 0.35
        // Roof (a simple gable receding upward).
        let roofPath = Paint.polygon([
            CGPoint(x: left - w * 0.05, y: wallTop + 4), CGPoint(x: w / 2, y: peak), CGPoint(x: right + w * 0.05, y: wallTop + 4),
            CGPoint(x: right + w * 0.05, y: wallTop + 4 - depth), CGPoint(x: w / 2, y: peak - depth), CGPoint(x: left - w * 0.05, y: wallTop + 4 - depth),
        ])
        Paint.outline(ctx, roofPath, ink, width: 3)
        Paint.fill(ctx, roofPath, top: roof.shaded(0.06), bottom: roof.shaded(-0.08))
        Paint.clipped(ctx, to: roofPath) {
            ctx.setStrokeColor(UIColor.black.withAlpha(0.15).cgColor)
            ctx.setLineWidth(1.5)
            var y = peak - depth
            while y < wallTop + 4 {
                ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: w, y: y))
                y += 9
            }
            ctx.strokePath()
        }
        // Front wall with boards.
        let wallPath = Paint.polygon([CGPoint(x: left, y: ground), CGPoint(x: left, y: wallTop), CGPoint(x: w / 2, y: peak + 6),
                                      CGPoint(x: right, y: wallTop), CGPoint(x: right, y: ground)])
        Paint.outline(ctx, wallPath, ink, width: 3)
        Paint.fill(ctx, wallPath, top: wall.shaded(0.05), bottom: wall.shaded(-0.1))
        Paint.clipped(ctx, to: wallPath) {
            ctx.setStrokeColor(wall.shaded(-0.3).withAlpha(0.5).cgColor)
            ctx.setLineWidth(1.5)
            var x = left + 8
            while x < right {
                ctx.move(to: CGPoint(x: x, y: peak)); ctx.addLine(to: CGPoint(x: x, y: ground))
                x += 12
            }
            ctx.strokePath()
            for _ in 0..<20 {
                Paint.dab(ctx, rng.point(in: CGRect(x: left, y: peak, width: right - left, height: ground - peak)),
                          rng.cg(2...6), rng.cg(1.5...3), UIColor.white.withAlpha(0.1))
            }
            if open {
                // Open front: a dark inside with straw on the floor.
                let inside = CGRect(x: left + w * 0.08, y: wallTop + (ground - wallTop) * 0.12, width: (right - left) - w * 0.16,
                                    height: (ground - wallTop) * 0.88)
                ctx.setFillColor(UIColor(hex: 0x3A2A1E).cgColor)
                ctx.fill(inside)
                for _ in 0..<40 {
                    let p = CGPoint(x: rng.cg(inside.minX...inside.maxX), y: rng.cg((inside.maxY - 12)...inside.maxY))
                    Paint.stroke(ctx, from: p, to: CGPoint(x: p.x + rng.cg(-8...8), y: p.y - rng.cg(1...4)), bend: 1, width: 1.4,
                                 color: UIColor(hex: 0xD9B964))
                }
            }
            ctx.drawLinearGradient(Paint.gradient([UIColor.black.withAlpha(0), UIColor.black.withAlpha(0.25)]),
                                   start: CGPoint(x: 0, y: ground - 30), end: CGPoint(x: 0, y: ground), options: [])
        }
    }

    static func coop(_ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            // Stilts under a raised house.
            let floor = ground - h * 0.16
            for x in [w * 0.18, w * 0.82] {
                ctx.setFillColor(UIColor(hex: 0x6E5039).cgColor)
                ctx.fill(CGRect(x: x - 4, y: floor, width: 8, height: ground - floor))
            }
            shed(ctx, CGSize(width: w, height: h), ground: floor, wall: UIColor(hex: 0xB9573F), roof: UIColor(hex: 0x6B5A4E),
                 wallTop: h * 0.42, peak: h * 0.2, open: false, rng: &rng)
            // Little arched door, a round window and the ramp.
            let door = Paint.roundedRect(CGRect(x: w * 0.42, y: floor - h * 0.22, width: w * 0.16, height: h * 0.22), w * 0.07)
            Paint.fill(ctx, door, UIColor(hex: 0x2E1F16))
            Paint.fill(ctx, CGPath(ellipseIn: CGRect(x: w * 0.2, y: h * 0.48, width: w * 0.12, height: w * 0.12), transform: nil), UIColor(hex: 0xF1E3B8))
            let ramp = Paint.polygon([CGPoint(x: w * 0.44, y: floor), CGPoint(x: w * 0.56, y: floor),
                                      CGPoint(x: w * 0.66, y: ground), CGPoint(x: w * 0.5, y: ground)])
            Paint.outline(ctx, ramp, ink, width: 2)
            Paint.fill(ctx, ramp, UIColor(hex: 0xA88A64))
            // Nest-box straw peeking out.
            for _ in 0..<12 {
                let p = CGPoint(x: rng.cg((w * 0.43)...(w * 0.57)), y: floor - rng.cg(0...4))
                Paint.stroke(ctx, from: p, to: CGPoint(x: p.x + rng.cg(-6...6), y: p.y - 5), bend: 1, width: 1.3, color: UIColor(hex: 0xE1C26A))
            }
        }
    }

    static func pigsty(_ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        let h = size.height
        return Canvas.image(size) { ctx in
            shed(ctx, size, ground: ground, wall: UIColor(hex: 0x9C8B78), roof: UIColor(hex: 0x8E9296),
                 wallTop: h * 0.45, peak: h * 0.24, open: true, rng: &rng)
            // A mud puddle out front.
            Paint.dab(ctx, CGPoint(x: size.width * 0.3, y: ground - 4), size.width * 0.18, 6, UIColor(hex: 0x6B4E36).withAlpha(0.8))
        }
    }

    static func sheepShelter(_ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        let h = size.height
        return Canvas.image(size) { ctx in
            shed(ctx, size, ground: ground, wall: UIColor(hex: 0xC2A27A), roof: UIColor(hex: 0x5E6B4E),
                 wallTop: h * 0.4, peak: h * 0.2, open: true, rng: &rng)
        }
    }

    static func livestockMarket(_ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            // A big red barn, open at the front, with a sign.
            shed(ctx, size, ground: ground, wall: UIColor(hex: 0xA84A36), roof: UIColor(hex: 0x5C4E46),
                 wallTop: h * 0.42, peak: h * 0.14, open: true, rng: &rng)
            let sign = CGRect(x: w * 0.3, y: h * 0.3, width: w * 0.4, height: h * 0.1)
            let signPath = Paint.roundedRect(sign, 6)
            Paint.outline(ctx, signPath, ink, width: 3)
            Paint.fill(ctx, signPath, top: UIColor(hex: 0xF3E9D2), bottom: UIColor(hex: 0xE2D4B4))
            VillagePainter.label("LIVESTOCK", in: sign.insetBy(dx: 6, dy: sign.height * 0.14), color: UIColor(hex: 0x7A2E22))
            // Rails in front of the opening.
            ctx.setStrokeColor(UIColor(hex: 0xE8DDC6).cgColor)
            ctx.setLineWidth(5)
            for y in [ground - h * 0.12, ground - h * 0.22] {
                ctx.move(to: CGPoint(x: w * 0.18, y: y)); ctx.addLine(to: CGPoint(x: w * 0.36, y: y))
                ctx.move(to: CGPoint(x: w * 0.64, y: y)); ctx.addLine(to: CGPoint(x: w * 0.82, y: y))
            }
            ctx.strokePath()
            // White X on the big door leaves.
            for x in [w * 0.1, w * 0.82] {
                let leaf = CGRect(x: x, y: h * 0.5, width: w * 0.08, height: ground - h * 0.5)
                ctx.setStrokeColor(UIColor(hex: 0xE8DDC6).cgColor)
                ctx.setLineWidth(3)
                ctx.stroke(leaf)
                ctx.move(to: CGPoint(x: leaf.minX, y: leaf.minY)); ctx.addLine(to: CGPoint(x: leaf.maxX, y: leaf.maxY))
                ctx.move(to: CGPoint(x: leaf.maxX, y: leaf.minY)); ctx.addLine(to: CGPoint(x: leaf.minX, y: leaf.maxY))
                ctx.strokePath()
            }
        }
    }

    // MARK: Props

    static func trough(_ size: CGSize, ground: CGFloat, water: Bool) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            let front = CGRect(x: w * 0.08, y: ground - h * 0.45, width: w * 0.84, height: h * 0.45)
            let rim = Paint.polygon([CGPoint(x: front.minX, y: front.minY), CGPoint(x: front.maxX, y: front.minY),
                                     CGPoint(x: front.maxX - 8, y: front.minY - h * 0.32), CGPoint(x: front.minX + 8, y: front.minY - h * 0.32)])
            Paint.outline(ctx, rim, ink, width: 2.5)
            Paint.fill(ctx, rim, UIColor(hex: 0x7A5C40))
            let basin = Paint.polygon([CGPoint(x: front.minX + 7, y: front.minY - 3), CGPoint(x: front.maxX - 7, y: front.minY - 3),
                                       CGPoint(x: front.maxX - 12, y: front.minY - h * 0.28), CGPoint(x: front.minX + 12, y: front.minY - h * 0.28)])
            if water {
                Paint.fill(ctx, basin, top: UIColor(hex: 0x8CC4DA), bottom: UIColor(hex: 0x4F8FB0))
                Paint.dab(ctx, CGPoint(x: w * 0.35, y: front.minY - h * 0.17), w * 0.08, 2.5, UIColor.white.withAlpha(0.6))
            } else {
                Paint.fill(ctx, basin, UIColor(hex: 0x5A4330))
                for k in 0..<3 {
                    let x = w * (0.3 + CGFloat(k) * 0.2)
                    Paint.stroke(ctx, from: CGPoint(x: x, y: front.minY - h * 0.2), to: CGPoint(x: x + 8, y: front.minY - h * 0.1),
                                 bend: 2, width: 1.2, color: UIColor(hex: 0x3A2A1C))
                }
            }
            let frontPath = Paint.roundedRect(front, 3)
            Paint.outline(ctx, frontPath, ink, width: 2.5)
            Paint.fill(ctx, frontPath, top: UIColor(hex: 0x9C7A56), bottom: UIColor(hex: 0x6E5238))
            ctx.setStrokeColor(UIColor(hex: 0x4E3A28).withAlpha(0.6).cgColor)
            ctx.setLineWidth(2)
            ctx.move(to: CGPoint(x: front.minX, y: front.midY)); ctx.addLine(to: CGPoint(x: front.maxX, y: front.midY))
            ctx.strokePath()
        }
    }

    static func feeder(_ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            let front = CGRect(x: w * 0.1, y: ground - h * 0.5, width: w * 0.8, height: h * 0.5)
            for _ in 0..<50 {
                let p = CGPoint(x: rng.cg((front.minX + 4)...(front.maxX - 4)), y: front.minY - rng.cg(0...(h * 0.3)))
                Paint.stroke(ctx, from: p, to: CGPoint(x: p.x + rng.cg(-10...10), y: p.y + rng.cg(2...8)), bend: 2, width: 1.5,
                             color: rng.chance(0.5) ? UIColor(hex: 0xD9BC66) : UIColor(hex: 0xB89A4E))
            }
            let path = Paint.roundedRect(front, 3)
            Paint.outline(ctx, path, ink, width: 2.5)
            Paint.fill(ctx, path, top: UIColor(hex: 0xA3825A), bottom: UIColor(hex: 0x7A5E40))
        }
    }

    static func repairSign(_ size: CGSize, ground: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            ctx.setFillColor(UIColor(hex: 0x6E5039).cgColor)
            ctx.fill(CGRect(x: w * 0.46, y: h * 0.35, width: w * 0.08, height: ground - h * 0.35))
            let board = Paint.roundedRect(CGRect(x: w * 0.1, y: h * 0.08, width: w * 0.8, height: h * 0.42), 6)
            Paint.outline(ctx, board, ink, width: 3)
            Paint.fill(ctx, board, top: UIColor(hex: 0xE9D9B2), bottom: UIColor(hex: 0xD2BD8E))
            // A hammer.
            ctx.saveGState()
            ctx.translateBy(x: w * 0.5, y: h * 0.29)
            ctx.rotate(by: -0.6)
            ctx.setFillColor(UIColor(hex: 0x8C5E3A).cgColor)
            ctx.fill(CGRect(x: -w * 0.04, y: -h * 0.02, width: w * 0.08, height: h * 0.2))
            ctx.setFillColor(UIColor(hex: 0x6A6E74).cgColor)
            ctx.fill(CGRect(x: -w * 0.16, y: -h * 0.1, width: w * 0.32, height: h * 0.09))
            ctx.restoreGState()
        }
    }

    // MARK: Effects

    static func bubble(_ size: CGSize) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            let circle = CGPath(ellipseIn: CGRect(x: w * 0.06, y: h * 0.04, width: w * 0.88, height: h * 0.8), transform: nil)
            let tail = Paint.polygon([CGPoint(x: w * 0.4, y: h * 0.74), CGPoint(x: w * 0.5, y: h * 0.97), CGPoint(x: w * 0.6, y: h * 0.74)])
            for path in [circle, tail] { Paint.outline(ctx, path, UIColor(hex: 0x6E5A44).withAlpha(0.6), width: 4) }
            for path in [circle, tail] { Paint.fill(ctx, path, UIColor(hex: 0xFFFDF6)) }
        }
    }

    static func heart(_ size: CGSize) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            let path = CGMutablePath()
            path.move(to: CGPoint(x: w / 2, y: h * 0.9))
            path.addQuadCurve(to: CGPoint(x: w * 0.05, y: h * 0.35), control: CGPoint(x: w * 0.05, y: h * 0.65))
            path.addQuadCurve(to: CGPoint(x: w / 2, y: h * 0.25), control: CGPoint(x: w * 0.25, y: h * 0.0))
            path.addQuadCurve(to: CGPoint(x: w * 0.95, y: h * 0.35), control: CGPoint(x: w * 0.75, y: h * 0.0))
            path.addQuadCurve(to: CGPoint(x: w / 2, y: h * 0.9), control: CGPoint(x: w * 0.95, y: h * 0.65))
            path.closeSubpath()
            Paint.fill(ctx, path, top: UIColor(hex: 0xF27A7A), bottom: UIColor(hex: 0xD6454F))
            Paint.dab(ctx, CGPoint(x: w * 0.3, y: h * 0.35), w * 0.08, h * 0.06, UIColor.white.withAlpha(0.6))
        }
    }

    // MARK: Goods (inventory icons, designed on a 100-unit box)

    static func goods(_ spec: AssetSpec, size: CGSize, rng: inout SeededRandom) -> UIImage? {
        let name = String(spec.name.dropFirst("item_".count))
        if name.hasPrefix("sapling_") {
            return Canvas.image(size) { ctx in sapling(ctx, size, species: String(name.dropFirst("sapling_".count)), rng: &rng) }
        }
        let draw: ((CGContext, CGPoint, CGFloat) -> Void)?
        switch name {
        case "egg": draw = { ctx, c, s in egg(ctx, c, s) }
        case "milk": draw = { ctx, c, s in milk(ctx, c, s) }
        case "wool": draw = { ctx, c, s in yarn(ctx, c, s) }
        case "truffle": draw = { ctx, c, s in truffle(ctx, c, s) }
        case "log": draw = { ctx, c, s in log(ctx, c, s) }
        case "apple": draw = { ctx, c, s in apple(ctx, c, s) }
        case "cherry": draw = { ctx, c, s in cherries(ctx, c, s) }
        case "animal_feed": draw = { ctx, c, s in feedSack(ctx, c, s) }
        default: draw = nil
        }
        guard let draw else { return nil }
        return Canvas.image(size) { ctx in
            draw(ctx, CGPoint(x: size.width / 2, y: size.height / 2), size.width / 100)
        }
    }

    private static func egg(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat) {
        for (dx, dy, color) in [(-14, 6, UIColor(hex: 0xE9D3B0)), (12, 2, UIColor(hex: 0xC99466))] as [(CGFloat, CGFloat, UIColor)] {
            let rect = CGRect(x: c.x + (dx - 17) * s, y: c.y + (dy - 24) * s, width: 34 * s, height: 44 * s)
            let path = CGPath(ellipseIn: rect, transform: nil)
            Paint.outline(ctx, path, ink, width: 2 * s)
            Paint.fill(ctx, path, top: color.shaded(0.08), bottom: color.shaded(-0.12))
            Paint.dab(ctx, CGPoint(x: rect.minX + 11 * s, y: rect.minY + 13 * s), 4 * s, 7 * s, UIColor.white.withAlpha(0.6), rotation: 0.3)
        }
    }

    private static func milk(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat) {
        let bottle = CGMutablePath()
        bottle.addPath(Paint.roundedRect(CGRect(x: c.x - 20 * s, y: c.y - 14 * s, width: 40 * s, height: 52 * s), 9 * s))
        bottle.addPath(Paint.roundedRect(CGRect(x: c.x - 10 * s, y: c.y - 36 * s, width: 20 * s, height: 26 * s), 4 * s))
        Paint.outline(ctx, bottle, ink, width: 2.5 * s)
        Paint.fill(ctx, bottle, top: UIColor(hex: 0xFFFFFF), bottom: UIColor(hex: 0xE6EAEE))
        ctx.setFillColor(UIColor(hex: 0x4F86C6).cgColor)
        ctx.fill(CGRect(x: c.x - 11 * s, y: c.y - 42 * s, width: 22 * s, height: 8 * s))
        ctx.setFillColor(UIColor(hex: 0x4F86C6).withAlpha(0.85).cgColor)
        ctx.fill(CGRect(x: c.x - 20 * s, y: c.y + 4 * s, width: 40 * s, height: 12 * s))
        Paint.dab(ctx, CGPoint(x: c.x - 11 * s, y: c.y - 2 * s), 3 * s, 9 * s, UIColor(hex: 0xDDE7F0))
    }

    private static func yarn(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat) {
        let rect = CGRect(x: c.x - 32 * s, y: c.y - 30 * s, width: 64 * s, height: 62 * s)
        let path = CGPath(ellipseIn: rect, transform: nil)
        Paint.outline(ctx, path, ink, width: 2.5 * s)
        let wool = UIColor(hex: 0xF0E6D0)
        Paint.fill(ctx, path, top: wool.shaded(0.05), bottom: wool.shaded(-0.14))
        Paint.clipped(ctx, to: path) {
            for k in 0..<7 {
                let y = rect.minY + CGFloat(k) * 10 * s
                Paint.stroke(ctx, from: CGPoint(x: rect.minX, y: y + 18 * s), to: CGPoint(x: rect.maxX, y: y - 6 * s), bend: 10 * s,
                             width: 2 * s, color: wool.shaded(-0.18))
            }
        }
        Paint.stroke(ctx, from: CGPoint(x: rect.maxX - 6 * s, y: rect.maxY - 12 * s), to: CGPoint(x: rect.maxX + 8 * s, y: rect.maxY + 2 * s),
                     bend: 6 * s, width: 2.5 * s, color: wool.shaded(-0.1))
    }

    private static func truffle(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat) {
        var rng = SeededRandom(seed: 7)
        let path = Paint.blobPath(c, rx: 30 * s, ry: 26 * s, lumps: 11, lumpiness: 0.12, rng: &rng)
        Paint.outline(ctx, path, ink, width: 2.5 * s)
        Paint.fill(ctx, path, top: UIColor(hex: 0x4A3A30), bottom: UIColor(hex: 0x241A14))
        Paint.clipped(ctx, to: path) {
            for _ in 0..<40 {
                Paint.dab(ctx, rng.point(in: path.boundingBoxOfPath), 2.5 * s, 2 * s, UIColor(hex: 0x6E5A4C).withAlpha(0.6))
            }
        }
        Paint.dab(ctx, CGPoint(x: c.x - 12 * s, y: c.y - 10 * s), 6 * s, 4 * s, UIColor.white.withAlpha(0.2))
    }

    private static func log(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat) {
        let body = Paint.roundedRect(CGRect(x: c.x - 38 * s, y: c.y - 16 * s, width: 64 * s, height: 34 * s), 6 * s)
        Paint.outline(ctx, body, ink, width: 2.5 * s)
        Paint.fill(ctx, body, top: UIColor(hex: 0x8C6446), bottom: UIColor(hex: 0x5E4030))
        ctx.setStrokeColor(UIColor(hex: 0x3E2A1E).withAlpha(0.5).cgColor)
        ctx.setLineWidth(1.5 * s)
        for k in 0..<3 {
            let y = c.y + (-8 + CGFloat(k) * 9) * s
            ctx.move(to: CGPoint(x: c.x - 34 * s, y: y)); ctx.addLine(to: CGPoint(x: c.x + 20 * s, y: y + 2 * s))
        }
        ctx.strokePath()
        let end = CGPath(ellipseIn: CGRect(x: c.x + 16 * s, y: c.y - 17 * s, width: 24 * s, height: 36 * s), transform: nil)
        Paint.outline(ctx, end, ink, width: 2.5 * s)
        Paint.fill(ctx, end, UIColor(hex: 0xE3C28E))
        ctx.setStrokeColor(UIColor(hex: 0xB08A58).cgColor)
        ctx.setLineWidth(1.5 * s)
        for r in [5, 10] as [CGFloat] {
            ctx.addPath(CGPath(ellipseIn: CGRect(x: c.x + 28 * s - r * s * 0.66, y: c.y + 1 * s - r * s, width: r * s * 1.33, height: r * s * 2), transform: nil))
        }
        ctx.strokePath()
    }

    private static func apple(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat) {
        let body = CGPath(ellipseIn: CGRect(x: c.x - 30 * s, y: c.y - 24 * s, width: 60 * s, height: 56 * s), transform: nil)
        Paint.outline(ctx, body, ink, width: 2.5 * s)
        Paint.fill(ctx, body, top: UIColor(hex: 0xE2463A), bottom: UIColor(hex: 0xA82A26))
        Paint.dab(ctx, CGPoint(x: c.x - 13 * s, y: c.y - 8 * s), 7 * s, 11 * s, UIColor.white.withAlpha(0.35), rotation: 0.4)
        Paint.stroke(ctx, from: CGPoint(x: c.x, y: c.y - 20 * s), to: CGPoint(x: c.x + 4 * s, y: c.y - 36 * s), bend: 2 * s, width: 3 * s,
                     color: UIColor(hex: 0x5A3E26))
        Paint.dab(ctx, CGPoint(x: c.x + 14 * s, y: c.y - 32 * s), 11 * s, 5 * s, UIColor(hex: 0x5E9A3E), rotation: -0.4)
    }

    private static func cherries(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat) {
        let top = CGPoint(x: c.x + 6 * s, y: c.y - 34 * s)
        for dx in [-16, 14] as [CGFloat] {
            let center = CGPoint(x: c.x + dx * s, y: c.y + 14 * s)
            Paint.stroke(ctx, from: top, to: CGPoint(x: center.x, y: center.y - 14 * s), bend: dx * 0.3 * s, width: 2.5 * s,
                         color: UIColor(hex: 0x4E6A2E))
            let cherry = CGPath(ellipseIn: CGRect(x: center.x - 17 * s, y: center.y - 16 * s, width: 34 * s, height: 32 * s), transform: nil)
            Paint.outline(ctx, cherry, ink, width: 2 * s)
            Paint.fill(ctx, cherry, top: UIColor(hex: 0xC8283A), bottom: UIColor(hex: 0x7E1422))
            Paint.dab(ctx, CGPoint(x: center.x - 6 * s, y: center.y - 6 * s), 4 * s, 6 * s, UIColor.white.withAlpha(0.4), rotation: 0.4)
        }
        Paint.dab(ctx, CGPoint(x: top.x + 12 * s, y: top.y + 2 * s), 12 * s, 5 * s, UIColor(hex: 0x5E9A3E), rotation: 0.3)
    }

    private static func feedSack(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat) {
        let sack = CGMutablePath()
        sack.move(to: CGPoint(x: c.x - 22 * s, y: c.y - 26 * s))
        sack.addQuadCurve(to: CGPoint(x: c.x - 30 * s, y: c.y + 36 * s), control: CGPoint(x: c.x - 38 * s, y: c.y + 4 * s))
        sack.addLine(to: CGPoint(x: c.x + 30 * s, y: c.y + 36 * s))
        sack.addQuadCurve(to: CGPoint(x: c.x + 22 * s, y: c.y - 26 * s), control: CGPoint(x: c.x + 38 * s, y: c.y + 4 * s))
        sack.closeSubpath()
        Paint.outline(ctx, sack, ink, width: 2.5 * s)
        Paint.fill(ctx, sack, top: UIColor(hex: 0xD8C096), bottom: UIColor(hex: 0xB49A6C))
        // Grain spilling from the open top.
        for k in 0..<9 {
            let x = c.x + (CGFloat(k) - 4) * 5 * s
            Paint.dab(ctx, CGPoint(x: x, y: c.y - 28 * s - CGFloat(k % 3) * 3 * s), 4 * s, 3 * s, UIColor(hex: 0xE3B84E))
        }
        let label = Paint.roundedRect(CGRect(x: c.x - 16 * s, y: c.y + 2 * s, width: 32 * s, height: 20 * s), 3 * s)
        Paint.fill(ctx, label, UIColor(hex: 0x6E8F48))
    }

    private static func sapling(_ ctx: CGContext, _ size: CGSize, species: String, rng: inout SeededRandom) {
        let s = size.width / 100
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        // Clay pot.
        let pot = Paint.polygon([CGPoint(x: c.x - 24 * s, y: c.y + 8 * s), CGPoint(x: c.x + 24 * s, y: c.y + 8 * s),
                                 CGPoint(x: c.x + 17 * s, y: c.y + 42 * s), CGPoint(x: c.x - 17 * s, y: c.y + 42 * s)])
        Paint.outline(ctx, pot, ink, width: 2.5 * s)
        Paint.fill(ctx, pot, top: UIColor(hex: 0xC9714A), bottom: UIColor(hex: 0x9C4E30))
        ctx.setFillColor(UIColor(hex: 0xD98560).cgColor)
        ctx.fill(CGRect(x: c.x - 27 * s, y: c.y + 4 * s, width: 54 * s, height: 8 * s))
        // Little tree.
        let bark = species == "birch" ? UIColor(hex: 0xE6E0D2) : UIColor(hex: 0x6E5039)
        Paint.stroke(ctx, from: CGPoint(x: c.x, y: c.y + 6 * s), to: CGPoint(x: c.x, y: c.y - 16 * s), bend: 0, width: 5 * s, color: bark)
        if species == "pine" {
            for k in 0..<3 {
                let y = c.y - 40 * s + CGFloat(k) * 11 * s
                let half = (10 + CGFloat(k) * 6) * s
                Paint.fill(ctx, Paint.polygon([CGPoint(x: c.x, y: y - 8 * s), CGPoint(x: c.x + half, y: y + 10 * s), CGPoint(x: c.x - half, y: y + 10 * s)]),
                           UIColor(hex: 0x3F6E3E).shaded(CGFloat(k) * -0.04))
            }
        } else {
            let leaves = species == "birch" ? UIColor(hex: 0x86AE52) : UIColor(hex: 0x5E8A3F)
            let crown = Paint.blobPath(CGPoint(x: c.x, y: c.y - 26 * s), rx: 24 * s, ry: 20 * s, lumps: 9, lumpiness: 0.15, rng: &rng)
            Paint.outline(ctx, crown, ink, width: 2 * s)
            Paint.fill(ctx, crown, top: leaves.shaded(0.08), bottom: leaves.shaded(-0.1))
            let fruit: UIColor? = species == "apple" ? UIColor(hex: 0xD9403A) : (species == "cherry" ? UIColor(hex: 0xB0223A) : nil)
            if let fruit {
                for (dx, dy) in [(-10, -24), (8, -30), (4, -18)] as [(CGFloat, CGFloat)] {
                    Paint.dab(ctx, CGPoint(x: c.x + dx * s, y: c.y + dy * s), 4 * s, 4 * s, fruit)
                }
            }
        }
    }
}
