import UIKit
import AcresCore

/// The crops added after Phase 9: leafy greens, bulbs, a staked tomato, a
/// sunflower, a blueberry bush and a melon vine, with their harvest icons.
/// Built from `CropPainter`'s leaves, flowers and ground rings so they match.
enum ExtraCropPainter {
    typealias C = CropPainter

    static func color(of crop: String) -> UIColor? {
        switch crop {
        case "lettuce": UIColor(hex: 0x9CCB5A)
        case "onion": UIColor(hex: 0xC98A3E)
        case "kale": UIColor(hex: 0x3E6E5E)
        case "tomato": UIColor(hex: 0xD8412F)
        case "garlic": UIColor(hex: 0xEDE6D6)
        case "sunflower": UIColor(hex: 0xF2C230)
        case "blueberry": UIColor(hex: 0x4A5FA8)
        case "cabbage": UIColor(hex: 0xA7C98A)
        case "melon": UIColor(hex: 0x6FA048)
        default: nil
        }
    }

    // MARK: Growth stages 1…4

    static func stage(_ crop: String, _ ctx: CGContext, _ foot: CGPoint, _ stage: Int, rng: inout SeededRandom) -> Bool {
        switch crop {
        case "lettuce": rosette(ctx, foot, stage, leaf: UIColor(hex: 0x9CCB5A), frilly: false, head: stage == 4 ? UIColor(hex: 0xC4E07A) : nil, rng: &rng)
        case "kale": rosette(ctx, foot, stage, leaf: UIColor(hex: 0x3E6E5E), frilly: true, head: nil, tall: true, rng: &rng)
        case "cabbage": rosette(ctx, foot, stage, leaf: UIColor(hex: 0x8DB876), frilly: false,
                                head: stage >= 3 ? UIColor(hex: 0xC6DDA4) : nil, headSize: stage == 4 ? 1 : 0.6, rng: &rng)
        case "onion": bulbs(ctx, foot, stage, bulb: UIColor(hex: 0xC98A3E), rng: &rng)
        case "garlic": bulbs(ctx, foot, stage, bulb: UIColor(hex: 0xEDE6D6), rng: &rng)
        case "tomato": tomato(ctx, foot, stage, rng: &rng)
        case "sunflower": sunflower(ctx, foot, stage, rng: &rng)
        case "blueberry": blueberry(ctx, foot, stage, rng: &rng)
        case "melon": melon(ctx, foot, stage, rng: &rng)
        default: return false
        }
        return true
    }

    /// A rosette of rounded (or frilly) leaves, with an optional head in the middle.
    static func rosette(_ ctx: CGContext, _ foot: CGPoint, _ stage: Int, leaf color: UIColor, frilly: Bool, head: UIColor?,
                        headSize: CGFloat = 1, tall: Bool = false, rng: inout SeededRandom) {
        let spots: [CGFloat] = stage == 1 ? [-24, 24] : [-28, 0, 28]
        for dx in spots {
            let base = CGPoint(x: foot.x + dx, y: foot.y - (dx == 0 ? 6 : 0))
            C.groundRing(ctx, base, width: 30)
            let size: CGFloat = [0, 8, 16, 22, 26][stage] * (tall ? 1.2 : 1)
            let count = stage == 1 ? 3 : 7
            for k in 0..<count {
                let angle = -CGFloat.pi + CGFloat(k) / CGFloat(count - 1) * .pi + rng.cg(-0.1...0.1)
                let length = size * rng.cg(0.9...1.1) * (tall ? 1.3 : 1)
                if frilly {
                    let tip = CGPoint(x: base.x + cos(angle) * length, y: base.y - 2 + sin(angle) * length)
                    Paint.stroke(ctx, from: base, to: tip, bend: rng.cg(-2...2), width: 1.8, color: color.shaded(-0.15))
                    for t in stride(from: 0.35, through: 1.0, by: 0.2) {
                        let p = CGPoint(x: base.x + (tip.x - base.x) * t, y: base.y - 2 + (tip.y - base.y + 2) * t)
                        Paint.dab(ctx, p, length * 0.18, length * 0.13, rng.vary(color, 0.08))
                    }
                } else {
                    C.leaf(ctx, CGPoint(x: base.x, y: base.y - 2), angle: angle, length: length, width: length * 0.45,
                           color: rng.vary(color, 0.06))
                }
            }
            if let head {
                let r = size * 0.55 * headSize
                let c = CGPoint(x: base.x, y: base.y - r * 0.9)
                let ball = CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.85, width: r * 2, height: r * 1.7), transform: nil)
                Paint.outline(ctx, ball, C.ink, width: 1.2)
                Paint.fill(ctx, ball, top: head.shaded(0.1), bottom: head.shaded(-0.1))
                Paint.stroke(ctx, from: CGPoint(x: c.x - r * 0.6, y: c.y), to: CGPoint(x: c.x + r * 0.3, y: c.y - r * 0.6), bend: 2,
                             width: 1, color: head.shaded(-0.2))
            }
        }
    }

    /// Onions and garlic: tube leaves, swelling bulbs at the ripe stage.
    static func bulbs(_ ctx: CGContext, _ foot: CGPoint, _ stage: Int, bulb: UIColor, rng: inout SeededRandom) {
        let height: CGFloat = [0, 16, 32, 46, 30][stage]
        for dx in [-30, -10, 10, 30] as [CGFloat] {
            let base = CGPoint(x: foot.x + dx, y: foot.y - (Int(dx) % 20 == 0 ? 4 : 0))
            C.groundRing(ctx, base, width: 18)
            if stage >= 3 {
                let r: CGFloat = stage == 4 ? 8 : 5
                Paint.dab(ctx, CGPoint(x: base.x, y: base.y - r * 0.6), r, r * 0.85, bulb)
                Paint.dab(ctx, CGPoint(x: base.x - r * 0.3, y: base.y - r), r * 0.35, r * 0.25, UIColor.white.withAlpha(0.4))
            }
            let leaves = stage == 1 ? 2 : 3
            for k in 0..<leaves {
                let lean = (CGFloat(k) - CGFloat(leaves - 1) / 2) * (stage == 4 ? 0.9 : 0.25)
                let angle = -CGFloat.pi / 2 + lean + rng.cg(-0.08...0.08)
                let color = stage == 4 ? C.leafGreen.mixed(with: UIColor(hex: 0xC2B060), 0.55) : C.leafGreen
                let tip = CGPoint(x: base.x + cos(angle) * height, y: base.y - 4 + sin(angle) * height)
                Paint.stroke(ctx, from: CGPoint(x: base.x, y: base.y - 4), to: tip, bend: stage == 4 ? 6 : rng.cg(-2...2),
                             width: 2.6, color: color)
            }
        }
    }

    static func tomato(_ ctx: CGContext, _ foot: CGPoint, _ stage: Int, rng: inout SeededRandom) {
        C.groundRing(ctx, foot, width: 60)
        if stage == 1 {
            C.sprout(ctx, foot, height: 14, rng: &rng)
            return
        }
        let height: CGFloat = [0, 0, 60, 96, 104][stage]
        // The cane.
        Paint.stroke(ctx, from: CGPoint(x: foot.x + 6, y: foot.y), to: CGPoint(x: foot.x + 6, y: foot.y - height - 8), bend: 0,
                     width: 3, color: UIColor(hex: 0xA88A5A))
        let top = CGPoint(x: foot.x, y: foot.y - height)
        Paint.stroke(ctx, from: foot, to: top, bend: rng.cg(-4...4), width: 3, color: C.leafGreen.shaded(-0.05))
        for k in 0..<(stage == 2 ? 4 : 8) {
            let t = 0.2 + CGFloat(k) * 0.1
            let p = CGPoint(x: foot.x + (top.x - foot.x) * t, y: foot.y + (top.y - foot.y) * t)
            let side: CGFloat = k % 2 == 0 ? -1 : 1
            C.leaf(ctx, p, angle: -.pi / 2 + side * rng.cg(0.9...1.3), length: rng.cg(18...26), width: 7, color: rng.vary(C.leafGreen, 0.07))
        }
        if stage == 3 {
            for _ in 0..<4 {
                C.flower(ctx, CGPoint(x: foot.x + rng.cg(-20...20), y: foot.y - rng.cg(30...height)), radius: 3.5,
                         petal: UIColor(hex: 0xF2D44A), middle: UIColor(hex: 0xC9A12A))
            }
        }
        if stage == 4 {
            for _ in 0..<6 {
                fruit(ctx, CGPoint(x: foot.x + rng.cg(-22...22), y: foot.y - rng.cg(18...height - 8)), r: rng.cg(6...8),
                      color: UIColor(hex: 0xD8412F))
            }
        }
    }

    static func sunflower(_ ctx: CGContext, _ foot: CGPoint, _ stage: Int, rng: inout SeededRandom) {
        C.groundRing(ctx, foot, width: 50)
        if stage == 1 {
            C.sprout(ctx, foot, height: 16, rng: &rng)
            return
        }
        let height: CGFloat = [0, 0, 60, 150, 190][stage]
        let top = CGPoint(x: foot.x + rng.cg(-4...4), y: foot.y - height)
        Paint.stroke(ctx, from: foot, to: top, bend: rng.cg(-5...5), width: stage == 2 ? 3.5 : 5, color: C.leafGreen.shaded(-0.08))
        for k in 0..<(stage == 2 ? 3 : 6) {
            let t = 0.2 + CGFloat(k) * 0.13
            let p = CGPoint(x: foot.x + (top.x - foot.x) * t, y: foot.y + (top.y - foot.y) * t)
            let side: CGFloat = k % 2 == 0 ? -1 : 1
            C.leaf(ctx, p, angle: -.pi / 2 + side * rng.cg(1.0...1.3), length: rng.cg(24...34), width: 12, color: rng.vary(C.leafGreen, 0.06))
        }
        if stage == 3 {
            Paint.dab(ctx, top, 11, 10, UIColor(hex: 0x6E9A48))
        }
        if stage == 4 {
            flowerHead(ctx, top, radius: 30)
        }
    }

    /// A big sunflower head: petals around a seedy disc.
    static func flowerHead(_ ctx: CGContext, _ c: CGPoint, radius r: CGFloat) {
        let petal = UIColor(hex: 0xF2C230)
        for k in 0..<14 {
            let a = CGFloat(k) / 14 * .pi * 2
            Paint.dab(ctx, CGPoint(x: c.x + cos(a) * r * 0.78, y: c.y + sin(a) * r * 0.7), r * 0.34, r * 0.16,
                      k % 2 == 0 ? petal : petal.shaded(-0.08), rotation: a)
        }
        let disc = CGPath(ellipseIn: CGRect(x: c.x - r * 0.52, y: c.y - r * 0.48, width: r * 1.04, height: r * 0.96), transform: nil)
        Paint.outline(ctx, disc, C.ink, width: 1.2)
        Paint.fill(ctx, disc, top: UIColor(hex: 0x6E4A26), bottom: UIColor(hex: 0x4A2E16))
        for k in 0..<10 {
            let a = CGFloat(k) * 2.4
            let d = r * 0.4 * sqrt(CGFloat(k) / 10)
            Paint.dab(ctx, CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d), 1.6, 1.6, UIColor(hex: 0x9A7440))
        }
    }

    static func blueberry(_ ctx: CGContext, _ foot: CGPoint, _ stage: Int, rng: inout SeededRandom) {
        C.groundRing(ctx, foot, width: 80)
        if stage == 1 {
            Paint.stroke(ctx, from: foot, to: CGPoint(x: foot.x, y: foot.y - 18), bend: 3, width: 2.5, color: UIColor(hex: 0x7A5A3A))
            C.leaf(ctx, CGPoint(x: foot.x, y: foot.y - 14), angle: -.pi * 0.8, length: 10, width: 4, color: C.leafGreen)
            C.leaf(ctx, CGPoint(x: foot.x, y: foot.y - 18), angle: -.pi * 0.2, length: 10, width: 4, color: C.leafGreen)
            return
        }
        let rx: CGFloat = [0, 0, 26, 36, 38][stage], ry = rx * 0.85
        let bush = CGMutablePath()
        for i in 0..<4 {
            let c = CGPoint(x: foot.x + (CGFloat(i) - 1.5) * rx * 0.42, y: foot.y - ry * 0.8 - CGFloat(i % 2) * ry * 0.3)
            bush.addPath(Paint.blobPath(c, rx: rx * 0.55, ry: ry * 0.55, lumps: 9, lumpiness: 0.14, rng: &rng))
        }
        let green = UIColor(hex: 0x4F8048)
        ctx.saveGState()
        ctx.addPath(bush)
        ctx.setStrokeColor(C.ink.cgColor)
        ctx.setLineWidth(3)
        ctx.strokePath()
        ctx.restoreGState()
        Paint.fill(ctx, bush, top: green.shaded(0.08), bottom: green.shaded(-0.12))
        Paint.leafDabs(ctx, in: bush, base: green, count: Int(rx * 3), size: 3...5, rng: &rng)
        if stage == 3 {
            for _ in 0..<8 {
                Paint.dab(ctx, CGPoint(x: foot.x + rng.cg(-rx...rx), y: foot.y - ry * rng.cg(0.5...1.5)), 2.5, 3,
                          UIColor(hex: 0xF4F0E4))
            }
        }
        if stage == 4 {
            for _ in 0..<16 {
                let p = CGPoint(x: foot.x + rng.cg(-rx * 0.9...rx * 0.9), y: foot.y - ry * rng.cg(0.4...1.5))
                Paint.dab(ctx, p, 3.6, 3.6, UIColor(hex: 0x4A5FA8))
                Paint.dab(ctx, CGPoint(x: p.x - 1, y: p.y - 1), 1.2, 1.2, UIColor(hex: 0xB9C6E8).withAlpha(0.7))
            }
        }
    }

    static func melon(_ ctx: CGContext, _ foot: CGPoint, _ stage: Int, rng: inout SeededRandom) {
        C.groundRing(ctx, foot, width: 90)
        if stage == 1 {
            Paint.stroke(ctx, from: foot, to: CGPoint(x: foot.x, y: foot.y - 10), bend: 0, width: 2.5, color: C.leafGreen)
            Paint.dab(ctx, CGPoint(x: foot.x - 8, y: foot.y - 13), 8, 5, C.leafLight, rotation: -0.3)
            Paint.dab(ctx, CGPoint(x: foot.x + 8, y: foot.y - 13), 8, 5, C.leafLight, rotation: 0.3)
            return
        }
        Paint.stroke(ctx, from: CGPoint(x: foot.x - 46, y: foot.y - 6), to: CGPoint(x: foot.x + 46, y: foot.y - 4),
                     bend: 8, width: 2.5, color: C.leafDark)
        if stage >= 3 {
            let big = stage == 4
            melonBody(ctx, CGPoint(x: foot.x + 2, y: foot.y - (big ? 20 : 12)), rx: big ? 30 : 14, ry: big ? 22 : 10)
        }
        for i in 0..<(stage == 2 ? 3 : 5) {
            let x = foot.x - 40 + CGFloat(i) * 20
            C.lobedLeaf(ctx, CGPoint(x: x, y: foot.y - rng.cg(12...24) - (stage == 4 && i % 2 == 0 ? 20 : 0)),
                        radius: stage == 2 ? 10 : 12, rng: &rng)
        }
    }

    static func melonBody(_ ctx: CGContext, _ c: CGPoint, rx: CGFloat, ry: CGFloat) {
        let body = CGPath(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2), transform: nil)
        let green = UIColor(hex: 0x6FA048)
        Paint.outline(ctx, body, UIColor(hex: 0x2E4A1A).withAlpha(0.55), width: 2)
        Paint.fill(ctx, body, top: green.shaded(0.1), bottom: green.shaded(-0.14))
        Paint.clipped(ctx, to: body) {
            ctx.setStrokeColor(UIColor(hex: 0x3E6E2A).withAlpha(0.8).cgColor)
            ctx.setLineWidth(max(2, rx * 0.12))
            for k in -2...2 {
                let x = c.x + CGFloat(k) * rx * 0.4
                ctx.move(to: CGPoint(x: x, y: c.y - ry))
                ctx.addQuadCurve(to: CGPoint(x: x, y: c.y + ry), control: CGPoint(x: x + CGFloat(k) * rx * 0.2, y: c.y))
            }
            ctx.strokePath()
            Paint.softSpot(ctx, CGPoint(x: c.x - rx * 0.35, y: c.y - ry * 0.4), rx * 0.6, UIColor.white.withAlpha(0.25))
        }
    }

    /// A round shiny fruit with a little green star on top.
    static func fruit(_ ctx: CGContext, _ p: CGPoint, r: CGFloat, color: UIColor) {
        let ball = CGPath(ellipseIn: CGRect(x: p.x - r, y: p.y - r * 0.9, width: r * 2, height: r * 1.8), transform: nil)
        Paint.outline(ctx, ball, color.shaded(-0.45).withAlpha(0.6), width: 1.2)
        Paint.fill(ctx, ball, top: color.shaded(0.1), bottom: color.shaded(-0.12))
        Paint.dab(ctx, CGPoint(x: p.x - r * 0.35, y: p.y - r * 0.35), r * 0.3, r * 0.2, UIColor.white.withAlpha(0.45))
        for k in 0..<5 {
            let a = -CGFloat.pi / 2 + CGFloat(k) / 5 * .pi * 2
            Paint.dab(ctx, CGPoint(x: p.x + cos(a) * r * 0.25, y: p.y - r * 0.8 + sin(a) * r * 0.2), r * 0.22, r * 0.1,
                      C.leafGreen, rotation: a)
        }
    }

    // MARK: Harvest icons

    static func produce(_ ctx: CGContext, _ crop: String, in rect: CGRect, rng: inout SeededRandom) -> Bool {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let s = rect.width / 100
        switch crop {
        case "lettuce", "cabbage":
            let color = crop == "lettuce" ? UIColor(hex: 0x9CCB5A) : UIColor(hex: 0xA7C98A)
            for k in 0..<7 {
                let a = CGFloat(k) / 7 * .pi * 2
                C.leaf(ctx, CGPoint(x: c.x, y: c.y + 6 * s), angle: a, length: 38 * s, width: 18 * s, color: color.shaded(-0.08))
            }
            let r = (crop == "lettuce" ? 22 : 28) * s
            let head = CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.9, width: r * 2, height: r * 1.8), transform: nil)
            Paint.outline(ctx, head, C.ink, width: 1.5 * s)
            Paint.fill(ctx, head, top: color.shaded(0.18), bottom: color.shaded(0.02))
            Paint.stroke(ctx, from: CGPoint(x: c.x - r * 0.5, y: c.y + r * 0.2), to: CGPoint(x: c.x + r * 0.2, y: c.y - r * 0.6),
                         bend: 4 * s, width: 1.5 * s, color: color.shaded(-0.15))
        case "kale":
            for k in -2...2 {
                let base = CGPoint(x: c.x + CGFloat(k) * 4 * s, y: c.y + 36 * s)
                let angle = -CGFloat.pi / 2 + CGFloat(k) * 0.3
                let tip = CGPoint(x: base.x + cos(angle) * 64 * s, y: base.y + sin(angle) * 64 * s)
                Paint.stroke(ctx, from: base, to: tip, bend: 0, width: 3 * s, color: UIColor(hex: 0x6E8E6A))
                for t in stride(from: 0.3, through: 1.0, by: 0.14) {
                    let p = CGPoint(x: base.x + (tip.x - base.x) * t, y: base.y + (tip.y - base.y) * t)
                    Paint.dab(ctx, p, 10 * s, 7 * s, UIColor(hex: 0x3E6E5E).shaded(CGFloat(t) * 0.1))
                }
            }
        case "onion", "garlic":
            let color = crop == "onion" ? UIColor(hex: 0xC98A3E) : UIColor(hex: 0xEDE6D6)
            for (dx, r) in (crop == "onion" ? [(-16, 22), (18, 20)] : [(0, 28)]) as [(CGFloat, CGFloat)] {
                let p = CGPoint(x: c.x + dx * s, y: c.y + 10 * s)
                let body = Paint.polygon([
                    CGPoint(x: p.x, y: p.y - r * s * 1.5), CGPoint(x: p.x + r * s, y: p.y - r * s * 0.2),
                    CGPoint(x: p.x + r * s * 0.8, y: p.y + r * s * 0.8), CGPoint(x: p.x - r * s * 0.8, y: p.y + r * s * 0.8),
                    CGPoint(x: p.x - r * s, y: p.y - r * s * 0.2),
                ])
                Paint.outline(ctx, body, color.shaded(-0.45).withAlpha(0.6), width: 1.5 * s)
                Paint.fill(ctx, body, top: color.shaded(0.1), bottom: color.shaded(-0.1))
                if crop == "garlic" {
                    for k in -1...1 {
                        Paint.stroke(ctx, from: CGPoint(x: p.x + CGFloat(k) * r * s * 0.35, y: p.y - r * s * 1.1),
                                     to: CGPoint(x: p.x + CGFloat(k) * r * s * 0.45, y: p.y + r * s * 0.7), bend: CGFloat(k) * 3 * s,
                                     width: 1.2 * s, color: UIColor(hex: 0xC9BFA8))
                    }
                }
                Paint.stroke(ctx, from: CGPoint(x: p.x, y: p.y - r * s * 1.5), to: CGPoint(x: p.x + 4 * s, y: p.y - r * s * 2.1),
                             bend: 2 * s, width: 2.5 * s, color: UIColor(hex: 0xA89060))
            }
        case "tomato":
            fruit(ctx, CGPoint(x: c.x - 15 * s, y: c.y + 8 * s), r: 22 * s, color: UIColor(hex: 0xD8412F))
            fruit(ctx, CGPoint(x: c.x + 17 * s, y: c.y + 12 * s), r: 18 * s, color: UIColor(hex: 0xE0533A))
        case "sunflower":
            flowerHead(ctx, c, radius: 44 * s)
        case "blueberry":
            for (dx, dy) in [(-14, 8), (4, 14), (18, 0), (-4, -8), (10, -16), (-18, -10), (22, 20)] as [(CGFloat, CGFloat)] {
                let p = CGPoint(x: c.x + dx * s, y: c.y + dy * s)
                Paint.dab(ctx, p, 11 * s, 11 * s, UIColor(hex: 0x4A5FA8))
                Paint.dab(ctx, CGPoint(x: p.x - 3 * s, y: p.y - 3 * s), 3.5 * s, 3 * s, UIColor(hex: 0xB9C6E8).withAlpha(0.7))
                Paint.dab(ctx, CGPoint(x: p.x + 2 * s, y: p.y - 7 * s), 2.5 * s, 2 * s, UIColor(hex: 0x2E3A6A))
            }
            C.leaf(ctx, CGPoint(x: c.x + 6 * s, y: c.y - 20 * s), angle: -0.5, length: 30 * s, width: 10 * s, color: C.leafGreen)
        case "melon":
            melonBody(ctx, CGPoint(x: c.x - 8 * s, y: c.y + 2 * s), rx: 36 * s, ry: 28 * s)
            let slice = Paint.polygon([CGPoint(x: c.x + 14 * s, y: c.y + 34 * s), CGPoint(x: c.x + 46 * s, y: c.y + 34 * s),
                                       CGPoint(x: c.x + 30 * s, y: c.y + 8 * s)])
            Paint.fill(ctx, slice, UIColor(hex: 0xF4B06A))
            Paint.outline(ctx, slice, UIColor(hex: 0x6FA048), width: 3 * s)
        default:
            return false
        }
        return true
    }
}
