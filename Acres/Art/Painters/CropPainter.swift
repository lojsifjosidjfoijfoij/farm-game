import UIKit
import AcresCore

/// Crops (5 growth stages each), plowed soil, and the harvest/seed item icons.
enum CropPainter {

    // MARK: Palette

    static let leafGreen = UIColor(hex: 0x5E8F3E)
    static let leafLight = UIColor(hex: 0x8AB85C)
    static let leafDark = UIColor(hex: 0x416B2B)
    static let gold = UIColor(hex: 0xD9B04F)
    static let goldLight = UIColor(hex: 0xEDCD7C)
    static let carrotOrange = UIColor(hex: 0xE0782C)
    static let potatoBrown = UIColor(hex: 0xB38B5C)
    static let berryRed = UIColor(hex: 0xD2383A)
    static let pumpkinOrange = UIColor(hex: 0xE2862B)
    static let cornYellow = UIColor(hex: 0xF0CC55)
    static let soil = UIColor(hex: 0x5C3F2A)
    static let ink = UIColor(hex: 0x24301A).withAlpha(0.45)

    /// Signature color of each crop (seed packets, sown seeds).
    static func color(of crop: String) -> UIColor {
        switch crop {
        case "wheat": gold
        case "carrot": carrotOrange
        case "potato": potatoBrown
        case "strawberry": berryRed
        case "corn": cornYellow
        case "pumpkin": pumpkinOrange
        default: ExtraCropPainter.color(of: crop) ?? leafGreen
        }
    }

    // MARK: Entry points

    static func paintCrop(_ spec: AssetSpec, rng: inout SeededRandom) -> UIImage? {
        // crop_<id>_stage<n>
        let parts = spec.name.split(separator: "_")
        guard parts.count == 3, let stage = Int(parts[2].dropFirst("stage".count)) else { return nil }
        let crop = String(parts[1])
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        let ground = size.height * (1 - CGFloat(spec.anchorY))
        return Canvas.image(size) { ctx in
            let foot = CGPoint(x: size.width / 2, y: ground)
            if stage == 0 {
                sown(ctx, foot, seedColor: color(of: crop), rng: &rng)
                return
            }
            switch crop {
            case "wheat": wheat(ctx, foot, stage, rng: &rng)
            case "carrot": carrot(ctx, foot, stage, rng: &rng)
            case "potato": potato(ctx, foot, stage, rng: &rng)
            case "strawberry": strawberry(ctx, foot, stage, rng: &rng)
            case "corn": corn(ctx, foot, stage, rng: &rng)
            case "pumpkin": pumpkin(ctx, foot, stage, rng: &rng)
            default: _ = ExtraCropPainter.stage(crop, ctx, foot, stage, rng: &rng)
            }
        }
    }

    /// Items: `item_<crop>` (harvest) and `item_seeds_<crop>` (seed packet).
    static func paintItem(_ spec: AssetSpec, rng: inout SeededRandom) -> UIImage? {
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        let name = spec.name
        if name.hasPrefix("item_seeds_") {
            let crop = String(name.dropFirst("item_seeds_".count))
            guard CropCatalog.crop(crop) != nil else { return nil }
            return Canvas.image(size) { ctx in seedPacket(ctx, size, crop: crop, rng: &rng) }
        }
        let crop = String(name.dropFirst("item_".count))
        guard CropCatalog.crop(crop) != nil else { return nil }
        return Canvas.image(size) { ctx in
            produce(ctx, crop, in: CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.08, dy: size.height * 0.08), rng: &rng)
        }
    }

    /// Plowed soil tiles (seamless so fields join up).
    static func paintSoil(_ spec: AssetSpec, rng: inout SeededRandom) -> UIImage? {
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        let wet = spec.name == "field_soil_watered"
        guard wet || spec.name == "field_soil_plowed" else { return nil }
        let base = wet ? UIColor(hex: 0x4A3223) : UIColor(hex: 0x6B4A31)
        let ridge = wet ? UIColor(hex: 0x5D402B) : UIColor(hex: 0x85603F)
        let furrow = wet ? UIColor(hex: 0x301F16) : UIColor(hex: 0x4B3121)
        return Canvas.image(size, opaque: true) { ctx in
            ctx.setFillColor(base.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
            let rows = 4
            let rowHeight = size.height / CGFloat(rows)
            for row in 0..<rows {
                let top = CGFloat(row) * rowHeight
                // Ridge (lit from above) and the furrow shadow below it.
                ctx.drawLinearGradient(Paint.gradient([ridge, base]), start: CGPoint(x: 0, y: top + rowHeight * 0.15),
                                       end: CGPoint(x: 0, y: top + rowHeight * 0.6), options: [])
                ctx.setFillColor(furrow.withAlpha(0.8).cgColor)
                ctx.fill(CGRect(x: 0, y: top + rowHeight * 0.72, width: size.width, height: rowHeight * 0.16))
                ctx.setFillColor(ridge.shaded(0.05).withAlpha(0.7).cgColor)
                ctx.fill(CGRect(x: 0, y: top + rowHeight * 0.1, width: size.width, height: rowHeight * 0.08))
            }
            // Clods and pebbles, wrapped so neighbouring tiles line up.
            for _ in 0..<70 {
                let p = rng.point(in: CGRect(origin: .zero, size: size))
                let r = rng.cg(1.5...3.5)
                let color = rng.chance(0.5) ? ridge.shaded(0.08) : furrow
                Tiling.wrapped(size, p, margin: 4) { q in Paint.dab(ctx, q, r, r * 0.7, color.withAlpha(0.8)) }
            }
            if wet {
                for _ in 0..<26 {
                    let p = rng.point(in: CGRect(origin: .zero, size: size))
                    Tiling.wrapped(size, p, margin: 6) { q in
                        Paint.dab(ctx, q, 4, 1.2, UIColor(hex: 0xBFD3E0).withAlpha(0.28))
                    }
                }
            }
        }
    }

    // MARK: Building blocks

    /// A pointed leaf from `base` in direction `angle` (radians, 0 = right, −π/2 = up).
    static func leaf(_ ctx: CGContext, _ base: CGPoint, angle: CGFloat, length: CGFloat, width: CGFloat, color: UIColor) {
        let tip = CGPoint(x: base.x + cos(angle) * length, y: base.y + sin(angle) * length)
        let normal = CGPoint(x: -sin(angle), y: cos(angle))
        let mid = CGPoint(x: (base.x + tip.x) / 2, y: (base.y + tip.y) / 2)
        let path = CGMutablePath()
        path.move(to: base)
        path.addQuadCurve(to: tip, control: CGPoint(x: mid.x + normal.x * width, y: mid.y + normal.y * width))
        path.addQuadCurve(to: base, control: CGPoint(x: mid.x - normal.x * width, y: mid.y - normal.y * width))
        path.closeSubpath()
        Paint.outline(ctx, path, ink, width: 1.2)
        Paint.fill(ctx, path, top: color.shaded(0.08), bottom: color.shaded(-0.1))
        ctx.setStrokeColor(color.shaded(-0.2).withAlpha(0.6).cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: base)
        ctx.addLine(to: CGPoint(x: base.x + (tip.x - base.x) * 0.85, y: base.y + (tip.y - base.y) * 0.85))
        ctx.strokePath()
    }

    /// Freshly sown soil: little mounds with a few seeds.
    static func sown(_ ctx: CGContext, _ foot: CGPoint, seedColor: UIColor, rng: inout SeededRandom) {
        for dx in [-30, 0, 30] as [CGFloat] {
            let c = CGPoint(x: foot.x + dx, y: foot.y - 4)
            Paint.dab(ctx, CGPoint(x: c.x, y: c.y + 2), 15, 6, UIColor.black.withAlpha(0.15))
            Paint.dab(ctx, c, 14, 6, soil.shaded(0.08))
            Paint.dab(ctx, CGPoint(x: c.x - 3, y: c.y - 2), 8, 2.5, soil.shaded(0.18))
            for _ in 0..<2 {
                Paint.dab(ctx, CGPoint(x: c.x + rng.cg(-7...7), y: c.y + rng.cg(-3...1)), 2.2, 1.6, seedColor)
            }
        }
    }

    static func sprout(_ ctx: CGContext, _ base: CGPoint, height: CGFloat, rng: inout SeededRandom) {
        Paint.stroke(ctx, from: base, to: CGPoint(x: base.x, y: base.y - height), bend: rng.cg(-2...2), width: 2, color: leafGreen)
        leaf(ctx, CGPoint(x: base.x, y: base.y - height), angle: -.pi * 0.85, length: height * 0.7, width: height * 0.25, color: leafLight)
        leaf(ctx, CGPoint(x: base.x, y: base.y - height), angle: -.pi * 0.15, length: height * 0.7, width: height * 0.25, color: leafLight)
    }

    /// A little dark soil ring where a plant meets the ground.
    static func groundRing(_ ctx: CGContext, _ base: CGPoint, width: CGFloat) {
        Paint.dab(ctx, CGPoint(x: base.x, y: base.y + 1), width / 2, width * 0.14, UIColor.black.withAlpha(0.18))
    }

    static func flower(_ ctx: CGContext, _ center: CGPoint, radius r: CGFloat, petal: UIColor, middle: UIColor) {
        for k in 0..<5 {
            let a = CGFloat(k) / 5 * .pi * 2
            Paint.dab(ctx, CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r * 0.8), r * 0.75, r * 0.55, petal, rotation: a)
        }
        Paint.dab(ctx, center, r * 0.45, r * 0.45, middle)
    }

    // MARK: Crops

    static func wheat(_ ctx: CGContext, _ foot: CGPoint, _ stage: Int, rng: inout SeededRandom) {
        groundRing(ctx, foot, width: 90)
        switch stage {
        case 1:
            for _ in 0..<7 {
                let base = CGPoint(x: foot.x + rng.cg(-38...38), y: foot.y + rng.cg(-6...2))
                let angle = -CGFloat.pi / 2 + rng.cg(-0.4...0.4)
                let len = rng.cg(10...16)
                Paint.stroke(ctx, from: base, to: CGPoint(x: base.x + cos(angle) * len, y: base.y + sin(angle) * len),
                             bend: rng.cg(-2...2), width: 2.4, color: leafLight)
            }
        case 2:
            for _ in 0..<16 {
                let base = CGPoint(x: foot.x + rng.cg(-36...36), y: foot.y + rng.cg(-6...2))
                let angle = -CGFloat.pi / 2 + rng.cg(-0.5...0.5)
                let len = rng.cg(22...40)
                Paint.stroke(ctx, from: base, to: CGPoint(x: base.x + cos(angle) * len, y: base.y + sin(angle) * len),
                             bend: rng.cg(-5...5), width: rng.cg(2.2...3.2), color: leafGreen.mixed(with: leafLight, rng.cg(0...1)))
            }
        default:
            let ripe = stage == 4
            let stalkColor = ripe ? gold : leafGreen
            let headColor = ripe ? gold.shaded(0.05) : UIColor(hex: 0xA9C26A)
            // Back stalks first (smaller, darker) for depth.
            for i in 0..<18 {
                let back = i < 7
                let base = CGPoint(x: foot.x + rng.cg(-40...40), y: foot.y + (back ? rng.cg(-10 ... -4) : rng.cg(-4...3)))
                let angle = -CGFloat.pi / 2 + rng.cg(-0.22...0.22)
                let len = rng.cg(ripe ? 70...92 : 60...82) * (back ? 0.92 : 1)
                let droop: CGFloat = ripe ? rng.cg(4...9) * (angle < -CGFloat.pi / 2 ? -1 : 1) : 0
                let tip = CGPoint(x: base.x + cos(angle) * len + droop, y: base.y + sin(angle) * len)
                let shade: CGFloat = back ? -0.1 : 0.03
                Paint.stroke(ctx, from: base, to: tip, bend: droop * 0.4, width: 2.2, color: stalkColor.shaded(shade))
                let headAngle = atan2(tip.y - base.y, tip.x - base.x)
                Paint.dab(ctx, tip, 3.6, 11, headColor.shaded(shade), rotation: headAngle + .pi / 2)
                if ripe {
                    for k in 0..<4 {
                        let t = CGFloat(k) / 4
                        let p = CGPoint(x: tip.x - cos(headAngle) * 9 * t, y: tip.y - sin(headAngle) * 9 * t)
                        Paint.dab(ctx, CGPoint(x: p.x + 3, y: p.y), 1.6, 3, goldLight, rotation: 0.6)
                        Paint.dab(ctx, CGPoint(x: p.x - 3, y: p.y), 1.6, 3, goldLight, rotation: -0.6)
                    }
                }
            }
        }
    }

    static func carrot(_ ctx: CGContext, _ foot: CGPoint, _ stage: Int, rng: inout SeededRandom) {
        let heights: [CGFloat] = [0, 14, 28, 40, 46]
        for dx in [-30, 0, 30] as [CGFloat] {
            let base = CGPoint(x: foot.x + dx, y: foot.y - (dx == 0 ? 6 : 0))
            groundRing(ctx, base, width: 26)
            if stage >= 3 {
                let shoulder = stage == 4 ? CGFloat(8) : 4.5
                Paint.dab(ctx, CGPoint(x: base.x, y: base.y - 1), shoulder, shoulder * 0.7, carrotOrange)
                Paint.dab(ctx, CGPoint(x: base.x - shoulder * 0.3, y: base.y - shoulder * 0.3), shoulder * 0.4, shoulder * 0.25,
                          UIColor.white.withAlpha(0.35))
            }
            // Feathery fronds.
            let fronds = stage == 1 ? 3 : 5
            for f in 0..<fronds {
                let angle = -CGFloat.pi / 2 + (CGFloat(f) - CGFloat(fronds - 1) / 2) * 0.32 + rng.cg(-0.08...0.08)
                let len = heights[stage] * rng.cg(0.85...1.1)
                let tip = CGPoint(x: base.x + cos(angle) * len, y: base.y - 2 + sin(angle) * len)
                Paint.stroke(ctx, from: CGPoint(x: base.x, y: base.y - 2), to: tip, bend: rng.cg(-3...3), width: 1.6, color: leafGreen)
                let leaflets = stage == 1 ? 2 : 4
                for k in 1...leaflets {
                    let t = CGFloat(k) / CGFloat(leaflets + 1) + 0.1
                    let p = CGPoint(x: base.x + (tip.x - base.x) * t, y: base.y - 2 + (tip.y - base.y + 2) * t)
                    let side: CGFloat = k % 2 == 0 ? 1 : -1
                    Paint.dab(ctx, CGPoint(x: p.x + side * 3.5, y: p.y), 4, 2.2, rng.vary(leafLight, 0.08), rotation: side * 0.7)
                }
            }
        }
    }

    static func potato(_ ctx: CGContext, _ foot: CGPoint, _ stage: Int, rng: inout SeededRandom) {
        groundRing(ctx, foot, width: 80)
        if stage == 1 {
            for dx in [-14, 0, 14] as [CGFloat] {
                Paint.dab(ctx, CGPoint(x: foot.x + dx, y: foot.y - 7), 7, 5.5, rng.vary(leafLight, 0.06))
            }
            return
        }
        let sizes: [CGFloat] = [0, 0, 26, 38, 40]
        let rx = sizes[stage], ry = sizes[stage] * 0.8
        let color = stage == 4 ? leafGreen.mixed(with: UIColor(hex: 0xBDAA4E), 0.5) : leafGreen
        if stage == 4 {
            for dx in [-22, 6, 24] as [CGFloat] {
                let p = CGPoint(x: foot.x + dx, y: foot.y - 2)
                Paint.dab(ctx, p, 10, 7, potatoBrown)
                Paint.dab(ctx, CGPoint(x: p.x - 3, y: p.y - 2), 4, 2, UIColor.white.withAlpha(0.3))
            }
        }
        let bush = CGMutablePath()
        for i in 0..<4 {
            let c = CGPoint(x: foot.x + (CGFloat(i) - 1.5) * rx * 0.4, y: foot.y - ry * 0.75 - CGFloat(i % 2) * ry * 0.25)
            bush.addPath(Paint.blobPath(c, rx: rx * 0.55, ry: ry * 0.55, lumps: 9, lumpiness: 0.15, rng: &rng))
        }
        ctx.saveGState()
        ctx.addPath(bush)
        ctx.setStrokeColor(ink.cgColor)
        ctx.setLineWidth(3)
        ctx.strokePath()
        ctx.restoreGState()
        Paint.fill(ctx, bush, top: color.shaded(0.08), bottom: color.shaded(-0.12))
        Paint.leafDabs(ctx, in: bush, base: color, count: Int(rx * 3), size: 3...6, rng: &rng)
        if stage == 3 {
            for _ in 0..<6 {
                let p = CGPoint(x: foot.x + rng.cg(-rx * 0.8...rx * 0.8), y: foot.y - ry * rng.cg(0.9...1.5))
                flower(ctx, p, radius: 3.2, petal: rng.chance(0.5) ? UIColor(hex: 0xF3EFF5) : UIColor(hex: 0xC9B6DE), middle: UIColor(hex: 0xE8C54A))
            }
        }
    }

    static func strawberry(_ ctx: CGContext, _ foot: CGPoint, _ stage: Int, rng: inout SeededRandom) {
        groundRing(ctx, foot, width: 80)
        let lengths: [CGFloat] = [0, 10, 20, 26, 28]
        let count = stage == 1 ? 3 : 9
        for i in 0..<count {
            let angle = -CGFloat.pi + CGFloat(i) / CGFloat(max(1, count - 1)) * .pi + rng.cg(-0.12...0.12)
            let len = lengths[stage] * rng.cg(0.85...1.1)
            let stem = CGPoint(x: foot.x + cos(angle) * len * 0.5, y: foot.y - 6 + sin(angle) * len * 0.5)
            Paint.stroke(ctx, from: CGPoint(x: foot.x, y: foot.y - 4), to: stem, bend: 0, width: 1.5, color: leafDark)
            // Three-part leaf.
            for k in -1...1 {
                leaf(ctx, stem, angle: angle + CGFloat(k) * 0.45, length: len * 0.6, width: len * 0.22, color: rng.vary(leafGreen, 0.06))
            }
        }
        if stage == 3 {
            for _ in 0..<4 {
                let p = CGPoint(x: foot.x + rng.cg(-30...30), y: foot.y - rng.cg(10...26))
                flower(ctx, p, radius: 4, petal: UIColor(hex: 0xF7F4EC), middle: UIColor(hex: 0xE8C54A))
            }
        }
        if stage == 4 {
            for _ in 0..<6 {
                let p = CGPoint(x: foot.x + rng.cg(-34...34), y: foot.y - rng.cg(2...20))
                berry(ctx, p, size: rng.cg(6...8), rng: &rng)
            }
        }
    }

    static func berry(_ ctx: CGContext, _ p: CGPoint, size s: CGFloat, rng: inout SeededRandom) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: p.x - s, y: p.y - s * 0.4))
        path.addQuadCurve(to: CGPoint(x: p.x, y: p.y + s * 1.2), control: CGPoint(x: p.x - s * 1.1, y: p.y + s * 0.6))
        path.addQuadCurve(to: CGPoint(x: p.x + s, y: p.y - s * 0.4), control: CGPoint(x: p.x + s * 1.1, y: p.y + s * 0.6))
        path.addQuadCurve(to: CGPoint(x: p.x - s, y: p.y - s * 0.4), control: CGPoint(x: p.x, y: p.y - s * 0.9))
        path.closeSubpath()
        Paint.outline(ctx, path, UIColor(hex: 0x5A1414).withAlpha(0.5), width: 1.2)
        Paint.fill(ctx, path, top: berryRed.shaded(0.08), bottom: berryRed.shaded(-0.12))
        for _ in 0..<5 {
            Paint.dab(ctx, CGPoint(x: p.x + rng.cg(-s * 0.6...s * 0.6), y: p.y + rng.cg(-s * 0.2...s * 0.8)), 0.8, 1.1, UIColor(hex: 0xF3D46A))
        }
        Paint.dab(ctx, CGPoint(x: p.x - s * 0.35, y: p.y - s * 0.1), s * 0.25, s * 0.15, UIColor.white.withAlpha(0.45))
        for k in -1...1 {
            leaf(ctx, CGPoint(x: p.x, y: p.y - s * 0.45), angle: -.pi / 2 + CGFloat(k) * 0.9, length: s * 0.7, width: s * 0.2, color: leafGreen)
        }
    }

    static func corn(_ ctx: CGContext, _ foot: CGPoint, _ stage: Int, rng: inout SeededRandom) {
        let heights: [CGFloat] = [0, 16, 64, 150, 168]
        for dx in [-18, 18] as [CGFloat] {
            let base = CGPoint(x: foot.x + dx, y: foot.y - (dx < 0 ? 6 : 0))
            groundRing(ctx, base, width: 30)
            let height = heights[stage] * rng.cg(0.92...1.05)
            if stage == 1 {
                sprout(ctx, base, height: height, rng: &rng)
                continue
            }
            let top = CGPoint(x: base.x + rng.cg(-3...3), y: base.y - height)
            Paint.stroke(ctx, from: base, to: top, bend: rng.cg(-3...3), width: stage == 2 ? 3.5 : 5, color: leafGreen.shaded(-0.04))
            let leaves = stage == 2 ? 4 : 8
            for k in 0..<leaves {
                let t = 0.15 + 0.8 * CGFloat(k) / CGFloat(leaves)
                let p = CGPoint(x: base.x + (top.x - base.x) * t, y: base.y + (top.y - base.y) * t)
                let side: CGFloat = k % 2 == 0 ? -1 : 1
                let angle = -CGFloat.pi / 2 + side * rng.cg(0.7...1.1)
                leaf(ctx, p, angle: angle, length: rng.cg(28...42) * (stage == 2 ? 0.8 : 1), width: 4.5, color: rng.vary(leafGreen, 0.06))
            }
            if stage == 4 {
                // Tassel.
                for k in 0..<5 {
                    let angle = -CGFloat.pi / 2 + (CGFloat(k) - 2) * 0.3
                    Paint.stroke(ctx, from: top, to: CGPoint(x: top.x + cos(angle) * 18, y: top.y + sin(angle) * 18),
                                 bend: 2, width: 1.6, color: UIColor(hex: 0xC9A864))
                }
                // A ripe cob half out of its husk.
                let cob = CGPoint(x: base.x + 7, y: base.y - height * 0.5)
                Paint.dab(ctx, cob, 6, 16, cornYellow, rotation: 0.35)
                Paint.dab(ctx, CGPoint(x: cob.x - 1.5, y: cob.y - 4), 2.2, 7, UIColor.white.withAlpha(0.3), rotation: 0.35)
                leaf(ctx, CGPoint(x: cob.x - 4, y: cob.y + 14), angle: -.pi / 2 + 0.2, length: 26, width: 5, color: UIColor(hex: 0x86A850))
            }
        }
    }

    static func pumpkin(_ ctx: CGContext, _ foot: CGPoint, _ stage: Int, rng: inout SeededRandom) {
        groundRing(ctx, foot, width: 90)
        if stage == 1 {
            Paint.stroke(ctx, from: foot, to: CGPoint(x: foot.x, y: foot.y - 10), bend: 0, width: 2.5, color: leafGreen)
            Paint.dab(ctx, CGPoint(x: foot.x - 8, y: foot.y - 13), 8, 5, leafLight, rotation: -0.3)
            Paint.dab(ctx, CGPoint(x: foot.x + 8, y: foot.y - 13), 8, 5, leafLight, rotation: 0.3)
            return
        }
        // Vine along the ground.
        Paint.stroke(ctx, from: CGPoint(x: foot.x - 46, y: foot.y - 4), to: CGPoint(x: foot.x + 46, y: foot.y - 10),
                     bend: -10, width: 2.5, color: leafDark)
        if stage == 4 {
            pumpkinBody(ctx, center: CGPoint(x: foot.x + 4, y: foot.y - 22), rx: 34, ry: 25)
        }
        let leafCount = stage == 2 ? 3 : 5
        for i in 0..<leafCount {
            let x = foot.x - 40 + CGFloat(i) * 80 / CGFloat(max(1, leafCount - 1))
            let y = foot.y - rng.cg(16...30) - (stage == 4 ? 18 : 0) * (i % 2 == 0 ? 1 : 0.3)
            lobedLeaf(ctx, CGPoint(x: x, y: y), radius: stage == 2 ? 11 : 14, rng: &rng)
        }
        if stage == 3 {
            pumpkinBody(ctx, center: CGPoint(x: foot.x + 6, y: foot.y - 10), rx: 13, ry: 10, color: UIColor(hex: 0x7FA348))
        }
    }

    static func lobedLeaf(_ ctx: CGContext, _ center: CGPoint, radius r: CGFloat, rng: inout SeededRandom) {
        let path = CGMutablePath()
        for k in 0..<3 {
            let a = -CGFloat.pi / 2 + (CGFloat(k) - 1) * 0.8
            path.addEllipse(in: CGRect(x: center.x + cos(a) * r * 0.45 - r * 0.6, y: center.y + sin(a) * r * 0.45 - r * 0.55,
                                       width: r * 1.2, height: r * 1.1))
        }
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setStrokeColor(ink.cgColor)
        ctx.setLineWidth(2.5)
        ctx.strokePath()
        ctx.restoreGState()
        Paint.fill(ctx, path, top: leafGreen.shaded(0.08), bottom: leafGreen.shaded(-0.1))
        Paint.leafDabs(ctx, in: path, base: leafGreen, count: 12, size: 2...4, rng: &rng)
    }

    static func pumpkinBody(_ ctx: CGContext, center c: CGPoint, rx: CGFloat, ry: CGFloat, color: UIColor = pumpkinOrange) {
        let body = CGPath(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2), transform: nil)
        Paint.outline(ctx, body, UIColor(hex: 0x5A2E0E).withAlpha(0.55), width: 2)
        Paint.fill(ctx, body, top: color.shaded(0.08), bottom: color.shaded(-0.14))
        Paint.clipped(ctx, to: body) {
            ctx.setStrokeColor(color.shaded(-0.22).withAlpha(0.7).cgColor)
            ctx.setLineWidth(max(1.5, rx * 0.06))
            for k in -2...2 {
                let x = c.x + CGFloat(k) * rx * 0.36
                ctx.move(to: CGPoint(x: x, y: c.y - ry))
                ctx.addQuadCurve(to: CGPoint(x: x, y: c.y + ry), control: CGPoint(x: x + CGFloat(k) * rx * 0.25, y: c.y))
            }
            ctx.strokePath()
            Paint.softSpot(ctx, CGPoint(x: c.x - rx * 0.35, y: c.y - ry * 0.4), rx * 0.6, UIColor.white.withAlpha(0.25))
        }
        Paint.stroke(ctx, from: CGPoint(x: c.x, y: c.y - ry + 2), to: CGPoint(x: c.x + rx * 0.15, y: c.y - ry - ry * 0.35),
                     bend: 3, width: max(3, rx * 0.12), color: UIColor(hex: 0x6E7A36))
    }

    // MARK: Items

    /// Draws a crop's harvested produce inside `rect` (item icons, packets).
    static func produce(_ ctx: CGContext, _ crop: String, in rect: CGRect, rng: inout SeededRandom) {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let s = rect.width / 100  // designed on a 100-unit box
        switch crop {
        case "wheat":
            let tie = CGPoint(x: c.x, y: c.y + 26 * s)
            for k in 0..<7 {
                let angle = -CGFloat.pi / 2 + (CGFloat(k) - 3) * 0.14
                let tip = CGPoint(x: tie.x + cos(angle) * 62 * s, y: tie.y + sin(angle) * 62 * s)
                Paint.stroke(ctx, from: CGPoint(x: tie.x - (tip.x - tie.x) * 0.3, y: tie.y + 22 * s), to: tip,
                             bend: 0, width: 2.4 * s, color: gold.shaded(-0.05))
                Paint.dab(ctx, tip, 4.5 * s, 13 * s, gold, rotation: angle + .pi / 2)
                Paint.dab(ctx, CGPoint(x: tip.x - 1.5 * s, y: tip.y - 3 * s), 1.6 * s, 6 * s, goldLight, rotation: angle + .pi / 2)
            }
            ctx.setFillColor(UIColor(hex: 0x8C6A3A).cgColor)
            ctx.fill(CGRect(x: tie.x - 9 * s, y: tie.y - 3 * s, width: 18 * s, height: 6 * s))
        case "carrot":
            for (dx, angle) in [(-12, 0.25), (12, -0.2)] as [(CGFloat, CGFloat)] {
                ctx.saveGState()
                ctx.translateBy(x: c.x + dx * s, y: c.y + 8 * s)
                ctx.rotate(by: angle)
                let body = Paint.polygon([CGPoint(x: -10 * s, y: -26 * s), CGPoint(x: 10 * s, y: -26 * s), CGPoint(x: 1.5 * s, y: 38 * s), CGPoint(x: -1.5 * s, y: 38 * s)])
                Paint.outline(ctx, body, UIColor(hex: 0x6A2E0A).withAlpha(0.5), width: 1.5 * s)
                Paint.fillHorizontal(ctx, body, left: carrotOrange.shaded(0.1), right: carrotOrange.shaded(-0.12))
                for k in 0..<4 {
                    let y = (-14 + CGFloat(k) * 12) * s
                    Paint.stroke(ctx, from: CGPoint(x: -6 * s, y: y), to: CGPoint(x: -1 * s, y: y + 2 * s), bend: 0, width: 1.2 * s,
                                 color: carrotOrange.shaded(-0.25))
                }
                for k in -1...1 {
                    leaf(ctx, CGPoint(x: 0, y: -26 * s), angle: -.pi / 2 + CGFloat(k) * 0.4, length: 26 * s, width: 5 * s, color: leafGreen)
                }
                ctx.restoreGState()
            }
        case "potato":
            for (dx, dy, r) in [(-18, 10, 20), (16, 12, 18), (0, -12, 19)] as [(CGFloat, CGFloat, CGFloat)] {
                let p = CGPoint(x: c.x + dx * s, y: c.y + dy * s)
                let path = Paint.blobPath(p, rx: r * s * 1.15, ry: r * s * 0.85, lumps: 7, lumpiness: 0.08, rng: &rng)
                Paint.outline(ctx, path, UIColor(hex: 0x4A3420).withAlpha(0.5), width: 1.5 * s)
                Paint.fill(ctx, path, top: potatoBrown.shaded(0.1), bottom: potatoBrown.shaded(-0.12))
                for _ in 0..<3 {
                    Paint.dab(ctx, CGPoint(x: p.x + rng.cg(-r * s * 0.6...r * s * 0.6), y: p.y + rng.cg(-r * s * 0.4...r * s * 0.4)),
                              1.8 * s, 1.2 * s, UIColor(hex: 0x6E5238))
                }
            }
        case "strawberry":
            berry(ctx, CGPoint(x: c.x - 14 * s, y: c.y + 2 * s), size: 20 * s, rng: &rng)
            berry(ctx, CGPoint(x: c.x + 16 * s, y: c.y + 8 * s), size: 17 * s, rng: &rng)
        case "corn":
            ctx.saveGState()
            ctx.translateBy(x: c.x, y: c.y)
            ctx.rotate(by: 0.5)
            let cob = CGPath(roundedRect: CGRect(x: -13 * s, y: -38 * s, width: 26 * s, height: 70 * s), cornerWidth: 13 * s, cornerHeight: 16 * s, transform: nil)
            Paint.outline(ctx, cob, UIColor(hex: 0x7A5A10).withAlpha(0.5), width: 1.5 * s)
            Paint.fillHorizontal(ctx, cob, left: cornYellow.shaded(0.1), right: cornYellow.shaded(-0.12))
            Paint.clipped(ctx, to: cob) {
                for row in 0..<12 {
                    for col in 0..<4 {
                        Paint.dab(ctx, CGPoint(x: (-9 + CGFloat(col) * 6) * s, y: (-34 + CGFloat(row) * 6) * s), 2.4 * s, 2.2 * s,
                                  UIColor(hex: 0xF7DC7A))
                    }
                }
            }
            leaf(ctx, CGPoint(x: 0, y: 34 * s), angle: -.pi / 2 - 0.35, length: 52 * s, width: 10 * s, color: UIColor(hex: 0x8AAE56))
            leaf(ctx, CGPoint(x: 0, y: 34 * s), angle: -.pi / 2 + 0.35, length: 50 * s, width: 10 * s, color: UIColor(hex: 0x7A9E48))
            ctx.restoreGState()
        case "pumpkin":
            pumpkinBody(ctx, center: CGPoint(x: c.x, y: c.y + 6 * s), rx: 40 * s, ry: 31 * s)
            leaf(ctx, CGPoint(x: c.x + 4 * s, y: c.y - 26 * s), angle: -0.3, length: 22 * s, width: 7 * s, color: leafGreen)
        default:
            _ = ExtraCropPainter.produce(ctx, crop, in: rect, rng: &rng)
        }
    }

    static func seedPacket(_ ctx: CGContext, _ size: CGSize, crop: String, rng: inout SeededRandom) {
        let w = size.width, h = size.height
        let packet = CGRect(x: w * 0.16, y: h * 0.08, width: w * 0.68, height: h * 0.84)
        let path = Paint.roundedRect(packet, w * 0.05)
        Paint.dab(ctx, CGPoint(x: packet.midX + 3, y: packet.maxY), packet.width * 0.45, h * 0.04, UIColor.black.withAlpha(0.15))
        Paint.outline(ctx, path, UIColor(hex: 0x6E5A3A).withAlpha(0.6), width: 2)
        Paint.fill(ctx, path, top: UIColor(hex: 0xF4ECD6), bottom: UIColor(hex: 0xE3D6B6))
        Paint.clipped(ctx, to: path) {
            // Colored band and the folded top.
            ctx.setFillColor(color(of: crop).withAlpha(0.85).cgColor)
            ctx.fill(CGRect(x: packet.minX, y: packet.maxY - packet.height * 0.2, width: packet.width, height: packet.height * 0.2))
            ctx.setFillColor(UIColor(hex: 0xD9CBA8).cgColor)
            ctx.fill(CGRect(x: packet.minX, y: packet.minY, width: packet.width, height: packet.height * 0.1))
        }
        produce(ctx, crop, in: CGRect(x: packet.minX + packet.width * 0.14, y: packet.minY + packet.height * 0.16,
                                      width: packet.width * 0.72, height: packet.width * 0.72), rng: &rng)
        for k in 0..<3 {
            Paint.dab(ctx, CGPoint(x: packet.midX + CGFloat(k - 1) * 8, y: packet.maxY - packet.height * 0.1), 2.4, 1.8,
                      UIColor(hex: 0xF4ECD6))
        }
    }
}
