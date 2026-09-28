import UIKit
import AcresCore

/// Phase 11: Willow Lake and its shore, the fishing bobber, fish and the
/// wild finds of the woods (as inventory icons), and smoked fish.
enum OutdoorsPainter {

    static func paint(_ spec: AssetSpec, rng: inout SeededRandom) -> UIImage? {
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        switch spec.name {
        case "nature_lake": return lake(size, rng: &rng)
        case "nature_reeds": return reeds(size, ground: size.height * (1 - CGFloat(spec.anchorY)), rng: &rng)
        case "nature_lily_pads": return lilyPads(size, rng: &rng)
        case "fx_bobber": return Canvas.image(size) { ctx in bobber(ctx, CGPoint(x: size.width / 2, y: size.height / 2), size.width / 100) }
        case "fx_exclaim": return exclaim(size)
        case "fx_water_ripple": return Canvas.image(size) { ctx in
            let ring = CGPath(ellipseIn: CGRect(x: size.width * 0.08, y: size.height * 0.12, width: size.width * 0.84,
                                                height: size.height * 0.76), transform: nil)
            Paint.outline(ctx, ring, UIColor.white.withAlpha(0.75), width: max(2, size.height * 0.08))
        }
        default: break
        }
        guard spec.name.hasPrefix("item_") else { return nil }
        let name = String(spec.name.dropFirst("item_".count))
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let s = size.width / 100
        if let look = fishLooks[name] {
            return Canvas.image(size) { ctx in fish(ctx, c, s, look) }
        }
        if name.hasPrefix("smoked_"), let look = fishLooks[String(name.dropFirst("smoked_".count))] {
            return Canvas.image(size) { ctx in smoked(ctx, c, s, look) }
        }
        guard let draw = finds[name] else { return nil }
        return Canvas.image(size) { ctx in draw(ctx, c, s, &rng) }
    }

    private static let ink = UIColor(hex: 0x2E2419).withAlpha(0.55)

    // MARK: Water

    static func lake(_ size: CGSize, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            let center = CGPoint(x: w / 2, y: h / 2)
            let grass = Paint.blobPath(center, rx: w * 0.5, ry: h * 0.49, lumps: 14, lumpiness: 0.04, rng: &rng)
            Paint.fill(ctx, grass, top: UIColor(hex: 0x7E9A56).withAlpha(0.7), bottom: UIColor(hex: 0x8AA65E).withAlpha(0.7))
            let sand = Paint.blobPath(center, rx: w * 0.47, ry: h * 0.45, lumps: 14, lumpiness: 0.05, rng: &rng)
            Paint.fill(ctx, sand, top: UIColor(hex: 0xB89E72), bottom: UIColor(hex: 0xCDB58A))
            let water = Paint.blobPath(center, rx: w * 0.43, ry: h * 0.39, lumps: 14, lumpiness: 0.05, rng: &rng)
            Paint.fill(ctx, water, top: UIColor(hex: 0x346572), bottom: UIColor(hex: 0x5A909A))
            Paint.clipped(ctx, to: water) {
                // Deep water in the middle, shallows at the edges, sky glints.
                Paint.softSpot(ctx, CGPoint(x: center.x + w * 0.04, y: center.y - h * 0.04), w * 0.3,
                               UIColor(hex: 0x1E4450).withAlpha(0.55), scaleY: 0.5)
                ctx.drawLinearGradient(Paint.gradient([UIColor(hex: 0x1A333A).withAlpha(0.4), UIColor.clear]),
                                       start: CGPoint(x: 0, y: center.y - h * 0.4), end: CGPoint(x: 0, y: center.y - h * 0.15), options: [])
                for _ in 0..<16 {
                    let p = CGPoint(x: rng.cg(w * 0.14...w * 0.86), y: rng.cg(h * 0.3...h * 0.78))
                    Paint.dab(ctx, p, rng.cg(14...40), rng.cg(1.5...3.2), UIColor.white.withAlpha(0.3))
                }
            }
            Paint.outline(ctx, water, UIColor(hex: 0x2A4A44).withAlpha(0.45), width: 3)
            // A few pebbles and tufts on the bank.
            for _ in 0..<18 {
                let angle = rng.cg(0...(2 * .pi))
                let p = CGPoint(x: center.x + cos(angle) * w * 0.45, y: center.y + sin(angle) * h * 0.42)
                if rng.nextUnit() < 0.5 {
                    Paint.dab(ctx, p, rng.cg(4...7), rng.cg(3...5), UIColor(hex: 0x9C9488))
                } else {
                    for _ in 0..<4 {
                        Paint.stroke(ctx, from: p, to: CGPoint(x: p.x + rng.cg(-6...6), y: p.y - rng.cg(8...16)),
                                     bend: rng.cg(-2...2), width: 2, color: UIColor(hex: 0x6F8D45))
                    }
                }
            }
        }
    }

    static func reeds(_ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        Canvas.image(size) { ctx in
            let w = size.width, h = size.height
            Paint.dab(ctx, CGPoint(x: w / 2, y: ground - 2), w * 0.3, h * 0.04, UIColor.black.withAlpha(0.14))
            for _ in 0..<14 {
                let base = CGPoint(x: w / 2 + rng.cg(-w * 0.2...w * 0.2), y: ground)
                let top = CGPoint(x: base.x + rng.cg(-w * 0.18...w * 0.18), y: ground - rng.cg(h * 0.5...h * 0.85))
                Paint.stroke(ctx, from: base, to: top, bend: rng.cg(-4...4), width: rng.cg(2.5...4),
                             color: rng.nextUnit() < 0.5 ? UIColor(hex: 0x6F8D45) : UIColor(hex: 0x5A7A3A))
            }
            for _ in 0..<3 {
                let p = CGPoint(x: w / 2 + rng.cg(-w * 0.16...w * 0.16), y: ground - rng.cg(h * 0.62...h * 0.8))
                Paint.dab(ctx, p, 3.5, 10, UIColor(hex: 0x6E4A2E))
            }
        }
    }

    static func lilyPads(_ size: CGSize, rng: inout SeededRandom) -> UIImage {
        Canvas.image(size) { ctx in
            let w = size.width, h = size.height
            for k in 0..<3 {
                let c = CGPoint(x: w * (0.25 + 0.25 * CGFloat(k)) + rng.cg(-6...6), y: h * 0.5 + rng.cg(-h * 0.15...h * 0.15))
                let r = rng.cg(w * 0.1...w * 0.15)
                let pad = CGMutablePath()
                pad.move(to: c)
                pad.addArc(center: c, radius: r, startAngle: 0.35, endAngle: 2 * .pi - 0.05, clockwise: false)
                pad.closeSubpath()
                ctx.saveGState()
                ctx.translateBy(x: c.x, y: c.y)
                ctx.scaleBy(x: 1, y: 0.6)
                ctx.translateBy(x: -c.x, y: -c.y)
                Paint.fill(ctx, pad, top: UIColor(hex: 0x6D9A4A), bottom: UIColor(hex: 0x4E7536))
                ctx.restoreGState()
            }
            let flower = CGPoint(x: w * 0.52, y: h * 0.42)
            for k in 0..<6 {
                let a = CGFloat(k) * .pi / 3
                Paint.dab(ctx, CGPoint(x: flower.x + cos(a) * 5, y: flower.y + sin(a) * 3), 4.5, 3, UIColor(hex: 0xF6D6E2))
            }
            Paint.dab(ctx, flower, 2.5, 2, UIColor(hex: 0xF2C84A))
        }
    }

    static func bobber(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat) {
        let ball = CGPath(ellipseIn: CGRect(x: c.x - 30 * s, y: c.y - 30 * s, width: 60 * s, height: 60 * s), transform: nil)
        Paint.outline(ctx, ball, ink, width: 5 * s)
        Paint.fill(ctx, ball, top: UIColor.white, bottom: UIColor(hex: 0xE4E0D8))
        Paint.clipped(ctx, to: ball) {
            ctx.setFillColor(UIColor(hex: 0xD8403A).cgColor)
            ctx.fill(CGRect(x: c.x - 32 * s, y: c.y - 32 * s, width: 64 * s, height: 30 * s))
        }
        Paint.stroke(ctx, from: CGPoint(x: c.x, y: c.y - 30 * s), to: CGPoint(x: c.x, y: c.y - 46 * s), bend: 0, width: 6 * s,
                     color: UIColor(hex: 0x3A2E26))
        Paint.dab(ctx, CGPoint(x: c.x - 10 * s, y: c.y - 14 * s), 7 * s, 5 * s, UIColor.white.withAlpha(0.5))
    }

    static func exclaim(_ size: CGSize) -> UIImage {
        Canvas.image(size) { ctx in
            let w = size.width, h = size.height
            let bubble = Paint.roundedRect(CGRect(x: w * 0.12, y: h * 0.06, width: w * 0.76, height: h * 0.72), w * 0.3)
            Paint.outline(ctx, bubble, ink, width: w * 0.04)
            Paint.fill(ctx, bubble, UIColor.white)
            Paint.fill(ctx, Paint.polygon([CGPoint(x: w * 0.4, y: h * 0.74), CGPoint(x: w * 0.6, y: h * 0.74),
                                           CGPoint(x: w * 0.5, y: h * 0.94)]), UIColor.white)
            Paint.fill(ctx, Paint.roundedRect(CGRect(x: w * 0.44, y: h * 0.16, width: w * 0.12, height: h * 0.34), w * 0.06),
                       UIColor(hex: 0xD8403A))
            Paint.dab(ctx, CGPoint(x: w * 0.5, y: h * 0.62), w * 0.07, w * 0.07, UIColor(hex: 0xD8403A))
        }
    }

    // MARK: Fish

    struct FishLook {
        var back: UIColor
        var belly: UIColor
        var fin: UIColor
        /// Length and height of the body (design units, a 100-wide icon).
        var length: CGFloat = 70
        var height: CGFloat = 26
        var spots: UIColor? = nil
        var stripes: UIColor? = nil
        var lateral: UIColor? = nil
        var whiskers = false
        var glow = false
        /// Long and wavy (eels).
        var snake = false
    }

    static let fishLooks: [String: FishLook] = [
        "sunfish": FishLook(back: UIColor(hex: 0x4E8A6A), belly: UIColor(hex: 0xE8963A), fin: UIColor(hex: 0x3E6A56),
                            length: 58, height: 36, spots: UIColor(hex: 0x6AB0C8)),
        "carp": FishLook(back: UIColor(hex: 0x9A7A36), belly: UIColor(hex: 0xE2C47A), fin: UIColor(hex: 0xB0703A),
                         length: 70, height: 30, whiskers: true),
        "perch": FishLook(back: UIColor(hex: 0x7E9A3A), belly: UIColor(hex: 0xE6E0A8), fin: UIColor(hex: 0xE0703A),
                          length: 64, height: 28, stripes: UIColor(hex: 0x3E5A2A)),
        "catfish": FishLook(back: UIColor(hex: 0x5E5A52), belly: UIColor(hex: 0xC8C0AE), fin: UIColor(hex: 0x4A4640),
                            length: 76, height: 24, whiskers: true),
        "golden_koi": FishLook(back: UIColor(hex: 0xF2A628), belly: UIColor(hex: 0xFBE6A8), fin: UIColor(hex: 0xF6D07A),
                               length: 70, height: 28, spots: UIColor(hex: 0xFFF6E0), glow: true),
        "trout": FishLook(back: UIColor(hex: 0x6E8A7A), belly: UIColor(hex: 0xEDE6DA), fin: UIColor(hex: 0x8A9A8A),
                          length: 72, height: 24, spots: UIColor(hex: 0x2E2A26), lateral: UIColor(hex: 0xE0849A)),
        "bass": FishLook(back: UIColor(hex: 0x4E7A36), belly: UIColor(hex: 0xDAD8A8), fin: UIColor(hex: 0x3E6A2E),
                         length: 70, height: 30, lateral: UIColor(hex: 0x2E4A22)),
        "whitefish": FishLook(back: UIColor(hex: 0x8A9AA6), belly: UIColor(hex: 0xEEF2F4), fin: UIColor(hex: 0xA8B6C0),
                              length: 68, height: 24),
        "pike": FishLook(back: UIColor(hex: 0x5E7A3E), belly: UIColor(hex: 0xE2E4B8), fin: UIColor(hex: 0x8A7A3A),
                         length: 84, height: 18, spots: UIColor(hex: 0xD8E0A0)),
        "salmon": FishLook(back: UIColor(hex: 0x7A8A96), belly: UIColor(hex: 0xF0C4B4), fin: UIColor(hex: 0x6A7884),
                           length: 76, height: 26, spots: UIColor(hex: 0x3A3E44), lateral: UIColor(hex: 0xE88A7A)),
        "eel": FishLook(back: UIColor(hex: 0x4A5236), belly: UIColor(hex: 0xC8C49A), fin: UIColor(hex: 0x3A4228),
                        length: 84, height: 12, snake: true),
        "sturgeon": FishLook(back: UIColor(hex: 0x6E767E), belly: UIColor(hex: 0xD6D8D6), fin: UIColor(hex: 0x5A6068),
                             length: 86, height: 20, spots: UIColor(hex: 0xE8EAE6), whiskers: true, glow: true),
    ]

    /// A fish in profile, facing left.
    static func fish(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat, _ look: FishLook) {
        if look.glow { Paint.softSpot(ctx, c, 46 * s, UIColor(hex: 0xFFE9A8).withAlpha(0.55)) }
        if look.snake {
            eel(ctx, c, s, look)
            return
        }
        let half = look.length / 2, hh = look.height / 2
        let nose = CGPoint(x: c.x - half * s, y: c.y)
        let tailBase = CGPoint(x: c.x + half * s, y: c.y)
        // Tail and fins behind the body.
        let tail = Paint.polygon([CGPoint(x: tailBase.x - 4 * s, y: c.y), CGPoint(x: tailBase.x + 16 * s, y: c.y - (hh + 4) * s),
                                  CGPoint(x: tailBase.x + 10 * s, y: c.y), CGPoint(x: tailBase.x + 16 * s, y: c.y + (hh + 4) * s)])
        Paint.outline(ctx, tail, ink, width: 2 * s)
        Paint.fill(ctx, tail, look.fin)
        let dorsal = Paint.polygon([CGPoint(x: c.x - 12 * s, y: c.y - (hh - 2) * s), CGPoint(x: c.x + 2 * s, y: c.y - (hh + 10) * s),
                                    CGPoint(x: c.x + 16 * s, y: c.y - (hh - 3) * s)])
        Paint.outline(ctx, dorsal, ink, width: 1.6 * s)
        Paint.fill(ctx, dorsal, look.fin)
        // The body: a leaf-like shape, round at the head.
        let body = CGMutablePath()
        body.move(to: nose)
        body.addQuadCurve(to: tailBase, control: CGPoint(x: c.x - 6 * s, y: c.y - look.height * 1.1 * s))
        body.addQuadCurve(to: nose, control: CGPoint(x: c.x - 6 * s, y: c.y + look.height * 1.1 * s))
        body.closeSubpath()
        Paint.outline(ctx, body, ink, width: 2.4 * s)
        Paint.fill(ctx, body, top: look.back, bottom: look.belly)
        Paint.clipped(ctx, to: body) {
            if let stripes = look.stripes {
                for k in 0..<5 {
                    let x = c.x - 14 * s + CGFloat(k) * 9 * s
                    Paint.dab(ctx, CGPoint(x: x, y: c.y - hh * 0.5 * s), 2.6 * s, hh * 0.8 * s, stripes.withAlpha(0.75))
                }
            }
            if let lateral = look.lateral {
                Paint.stroke(ctx, from: CGPoint(x: c.x - half * 0.6 * s, y: c.y + 1 * s), to: CGPoint(x: c.x + half * s, y: c.y),
                             bend: -2 * s, width: 4 * s, color: lateral.withAlpha(0.75))
            }
            if let spots = look.spots {
                for (dx, dy) in [(-6, -6), (4, -8), (14, -4), (-2, 2), (10, 4), (22, -2), (-14, -2)] as [(CGFloat, CGFloat)] {
                    Paint.dab(ctx, CGPoint(x: c.x + dx * s, y: c.y + dy * s * hh / 14), 2.4 * s, 2.4 * s, spots.withAlpha(0.85))
                }
            }
            Paint.dab(ctx, CGPoint(x: c.x - 4 * s, y: c.y - hh * 0.55 * s), half * 0.6 * s, 2.5 * s, UIColor.white.withAlpha(0.3))
        }
        // Gill, eye, mouth, belly fin.
        Paint.stroke(ctx, from: CGPoint(x: nose.x + 16 * s, y: c.y - hh * 0.6 * s), to: CGPoint(x: nose.x + 16 * s, y: c.y + hh * 0.6 * s),
                     bend: 3 * s, width: 1.6 * s, color: ink)
        Paint.dab(ctx, CGPoint(x: nose.x + 9 * s, y: c.y - 3 * s), 3.6 * s, 3.6 * s, UIColor.white)
        Paint.dab(ctx, CGPoint(x: nose.x + 8.5 * s, y: c.y - 3 * s), 2 * s, 2 * s, UIColor(hex: 0x1E1A16))
        Paint.fill(ctx, Paint.polygon([CGPoint(x: c.x - 4 * s, y: c.y + (hh - 2) * s), CGPoint(x: c.x + 6 * s, y: c.y + (hh + 6) * s),
                                       CGPoint(x: c.x + 10 * s, y: c.y + (hh - 3) * s)]), look.fin)
        if look.whiskers {
            for dy in [2.0, 5] as [CGFloat] {
                Paint.stroke(ctx, from: CGPoint(x: nose.x + 2 * s, y: c.y + dy * s), to: CGPoint(x: nose.x - 8 * s, y: c.y + (dy + 8) * s),
                             bend: 2 * s, width: 1.4 * s, color: ink)
            }
        }
    }

    private static func eel(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat, _ look: FishLook) {
        let points = (0...8).map { k -> CGPoint in
            let t = CGFloat(k) / 8
            return CGPoint(x: c.x + (t - 0.5) * look.length * s, y: c.y + sin(t * .pi * 2) * 10 * s)
        }
        for (width, color) in [(look.height + 3, ink), (look.height, look.back)] as [(CGFloat, UIColor)] {
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(width * s)
            ctx.setLineCap(.round)
            ctx.move(to: points[0])
            for k in stride(from: 1, to: points.count - 1, by: 2) {
                ctx.addQuadCurve(to: points[k + 1], control: points[k])
            }
            ctx.strokePath()
        }
        ctx.setStrokeColor(look.belly.withAlpha(0.6).cgColor)
        ctx.setLineWidth(3 * s)
        ctx.move(to: CGPoint(x: points[0].x, y: points[0].y + 3 * s))
        for k in stride(from: 1, to: points.count - 1, by: 2) {
            ctx.addQuadCurve(to: CGPoint(x: points[k + 1].x, y: points[k + 1].y + 3 * s), control: CGPoint(x: points[k].x, y: points[k].y + 3 * s))
        }
        ctx.strokePath()
        Paint.dab(ctx, CGPoint(x: points[0].x + 3 * s, y: points[0].y - 2 * s), 2.6 * s, 2.6 * s, UIColor.white)
        Paint.dab(ctx, CGPoint(x: points[0].x + 2.6 * s, y: points[0].y - 2 * s), 1.4 * s, 1.4 * s, UIColor(hex: 0x1E1A16))
    }

    /// Smoked fish: golden-brown, on a wooden board.
    static func smoked(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat, _ look: FishLook) {
        let board = Paint.roundedRect(CGRect(x: c.x - 44 * s, y: c.y + 8 * s, width: 88 * s, height: 20 * s), 6 * s)
        Paint.outline(ctx, board, ink, width: 2 * s)
        Paint.fill(ctx, board, top: UIColor(hex: 0xC99A62), bottom: UIColor(hex: 0x9A6E40))
        var golden = look
        golden.back = UIColor(hex: 0x9A5A22)
        golden.belly = UIColor(hex: 0xE0A04A)
        golden.fin = UIColor(hex: 0x7A4418)
        golden.spots = nil
        golden.stripes = nil
        golden.lateral = UIColor(hex: 0x6E3A14)
        golden.glow = false
        golden.length = min(look.length, 72)
        golden.height = max(look.height, 18)
        fish(ctx, CGPoint(x: c.x, y: c.y - 4 * s), s, golden)
        Paint.dab(ctx, CGPoint(x: c.x + 10 * s, y: c.y - 8 * s), 12 * s, 2 * s, UIColor.white.withAlpha(0.35))
    }

    // MARK: Wild finds

    typealias Draw = (CGContext, CGPoint, CGFloat, inout SeededRandom) -> Void

    static let finds: [String: Draw] = [
        "wild_garlic": { ctx, c, s, _ in
            for (a, len) in [(-0.5, 44.0), (0.05, 50), (0.55, 42)] as [(CGFloat, CGFloat)] {
                leaf(ctx, from: CGPoint(x: c.x, y: c.y + 38 * s), angle: -.pi / 2 + a, length: len * s, width: 12 * s,
                     color: UIColor(hex: 0x5E9A3E))
            }
            for (dx, dy) in [(-10, -24), (4, -30), (14, -20), (-2, -16)] as [(CGFloat, CGFloat)] {
                star(ctx, CGPoint(x: c.x + dx * s, y: c.y + dy * s), 7 * s, UIColor.white, center: UIColor(hex: 0xE8E4B0))
            }
        },
        "daffodil": { ctx, c, s, _ in
            Paint.stroke(ctx, from: CGPoint(x: c.x + 4 * s, y: c.y + 42 * s), to: CGPoint(x: c.x, y: c.y - 6 * s), bend: 3 * s,
                         width: 4 * s, color: UIColor(hex: 0x5E9A3E))
            leaf(ctx, from: CGPoint(x: c.x + 4 * s, y: c.y + 42 * s), angle: -.pi / 2 + 0.35, length: 40 * s, width: 7 * s,
                 color: UIColor(hex: 0x6AA84A))
            for k in 0..<6 {
                let a = CGFloat(k) * .pi / 3
                Paint.dab(ctx, CGPoint(x: c.x + cos(a) * 13 * s, y: c.y - 14 * s + sin(a) * 13 * s), 9 * s, 6 * s,
                          UIColor(hex: 0xF6E27A), rotation: a)
            }
            Paint.dab(ctx, CGPoint(x: c.x, y: c.y - 14 * s), 9 * s, 9 * s, UIColor(hex: 0xF0A628))
            Paint.dab(ctx, CGPoint(x: c.x, y: c.y - 14 * s), 5 * s, 5 * s, UIColor(hex: 0xD88A1E))
        },
        "morel": { ctx, c, s, _ in
            Paint.fill(ctx, Paint.roundedRect(CGRect(x: c.x - 9 * s, y: c.y + 6 * s, width: 18 * s, height: 30 * s), 6 * s),
                       UIColor(hex: 0xEDE2C8))
            let cap = Paint.polygon([CGPoint(x: c.x - 20 * s, y: c.y + 10 * s), CGPoint(x: c.x + 20 * s, y: c.y + 10 * s),
                                     CGPoint(x: c.x + 8 * s, y: c.y - 36 * s), CGPoint(x: c.x - 8 * s, y: c.y - 36 * s)])
            Paint.outline(ctx, cap, ink, width: 2.4 * s)
            Paint.fill(ctx, cap, top: UIColor(hex: 0x8A6A44), bottom: UIColor(hex: 0x6A4A2E))
            Paint.clipped(ctx, to: cap) {
                for row in 0..<5 {
                    for col in 0..<4 {
                        let x = c.x - 15 * s + CGFloat(col) * 10 * s + CGFloat(row % 2) * 5 * s
                        let y = c.y - 30 * s + CGFloat(row) * 9 * s
                        Paint.dab(ctx, CGPoint(x: x, y: y), 3.4 * s, 3 * s, UIColor(hex: 0x3E2A1A).withAlpha(0.7))
                    }
                }
            }
        },
        "blackberry": { ctx, c, s, _ in
            leaf(ctx, from: CGPoint(x: c.x + 4 * s, y: c.y - 8 * s), angle: -0.6, length: 36 * s, width: 16 * s, color: UIColor(hex: 0x4E8A3A))
            for (dx, dy) in [(-14, 10), (8, 14), (-2, -6)] as [(CGFloat, CGFloat)] {
                berry(ctx, CGPoint(x: c.x + dx * s, y: c.y + dy * s), 13 * s, UIColor(hex: 0x2E1E36))
            }
        },
        "chamomile": { ctx, c, s, _ in
            for (dx, dy, r) in [(-14, -10, 11), (12, -16, 10), (2, 8, 12)] as [(CGFloat, CGFloat, CGFloat)] {
                Paint.stroke(ctx, from: CGPoint(x: c.x + dx * s, y: c.y + dy * s), to: CGPoint(x: c.x, y: c.y + 42 * s),
                             bend: 2 * s, width: 2.4 * s, color: UIColor(hex: 0x6AA84A))
                daisy(ctx, CGPoint(x: c.x + dx * s, y: c.y + dy * s), r * s)
            }
        },
        "elderflower": { ctx, c, s, rng in
            for k in 0..<5 {
                let a = -.pi / 2 + (CGFloat(k) - 2) * 0.35
                let tip = CGPoint(x: c.x + cos(a) * 30 * s, y: c.y + 30 * s + sin(a) * 50 * s)
                Paint.stroke(ctx, from: CGPoint(x: c.x, y: c.y + 40 * s), to: tip, bend: 0, width: 2 * s, color: UIColor(hex: 0x7A9A4A))
            }
            for _ in 0..<60 {
                let p = CGPoint(x: c.x + rng.cg(-30...30) * s, y: c.y - 16 * s + rng.cg(-12...12) * s)
                Paint.dab(ctx, p, 3 * s, 3 * s, UIColor(hex: 0xF6F0D2))
                Paint.dab(ctx, p, 1 * s, 1 * s, UIColor(hex: 0xE8D27A))
            }
        },
        "chanterelle": { ctx, c, s, _ in
            for (dx, scale) in [(-12.0, 0.8), (10, 1.0)] as [(CGFloat, CGFloat)] {
                let x = c.x + dx * s, k = s * scale
                Paint.fill(ctx, Paint.polygon([CGPoint(x: x - 6 * k, y: c.y + 34 * s), CGPoint(x: x + 6 * k, y: c.y + 34 * s),
                                               CGPoint(x: x + 16 * k, y: c.y - 4 * s), CGPoint(x: x - 16 * k, y: c.y - 4 * s)]),
                           UIColor(hex: 0xE8A63A))
                let cap = CGPath(ellipseIn: CGRect(x: x - 22 * k, y: c.y - 14 * s, width: 44 * k, height: 16 * k), transform: nil)
                Paint.outline(ctx, cap, ink, width: 2 * s)
                Paint.fill(ctx, cap, top: UIColor(hex: 0xF4B84A), bottom: UIColor(hex: 0xD8902A))
                for g in 0..<4 {
                    let gx = x - 9 * k + CGFloat(g) * 6 * k
                    Paint.stroke(ctx, from: CGPoint(x: gx, y: c.y + 2 * s), to: CGPoint(x: x, y: c.y + 26 * s), bend: 0,
                                 width: 1.2 * s, color: UIColor(hex: 0xB8742A))
                }
            }
        },
        "hazelnut": { ctx, c, s, _ in
            leaf(ctx, from: CGPoint(x: c.x, y: c.y - 10 * s), angle: -2.2, length: 34 * s, width: 18 * s, color: UIColor(hex: 0x7AA84E))
            for (dx, dy) in [(-12, 8), (12, 10), (0, -4)] as [(CGFloat, CGFloat)] {
                let p = CGPoint(x: c.x + dx * s, y: c.y + dy * s)
                let nut = CGPath(ellipseIn: CGRect(x: p.x - 13 * s, y: p.y - 12 * s, width: 26 * s, height: 26 * s), transform: nil)
                Paint.outline(ctx, nut, ink, width: 2 * s)
                Paint.fill(ctx, nut, top: UIColor(hex: 0xB07A42), bottom: UIColor(hex: 0x7E5028))
                Paint.dab(ctx, CGPoint(x: p.x, y: p.y - 9 * s), 9 * s, 4 * s, UIColor(hex: 0xD8C09A))
                Paint.dab(ctx, CGPoint(x: p.x - 5 * s, y: p.y), 3 * s, 5 * s, UIColor.white.withAlpha(0.3))
            }
        },
        "holly": { ctx, c, s, _ in
            for a in [-2.4, -0.7] as [CGFloat] {
                ctx.saveGState()
                ctx.translateBy(x: c.x, y: c.y + 6 * s)
                ctx.rotate(by: a)
                var points: [CGPoint] = []
                for k in 0...6 {
                    points.append(CGPoint(x: CGFloat(k) * 7 * s, y: (k % 2 == 0 ? -13 : -7) * s))
                }
                for k in (0...6).reversed() {
                    points.append(CGPoint(x: CGFloat(k) * 7 * s, y: (k % 2 == 0 ? 13 : 7) * s))
                }
                let leafPath = Paint.polygon(points)
                Paint.outline(ctx, leafPath, ink, width: 2 * s)
                Paint.fill(ctx, leafPath, top: UIColor(hex: 0x2E6A3A), bottom: UIColor(hex: 0x1E4A28))
                ctx.restoreGState()
            }
            for (dx, dy) in [(-6, 0), (5, -4), (2, 7)] as [(CGFloat, CGFloat)] {
                berry(ctx, CGPoint(x: c.x + dx * s, y: c.y + dy * s), 7 * s, UIColor(hex: 0xD02A2A), smooth: true)
            }
        },
        "pinecone": { ctx, c, s, _ in
            for row in 0..<7 {
                let y = c.y - 32 * s + CGFloat(row) * 10 * s
                let width = (1 - abs(CGFloat(row) - 3.2) / 4.2) * 30 * s + 8 * s
                for col in -1...1 {
                    let p = CGPoint(x: c.x + CGFloat(col) * width * 0.45 + CGFloat(row % 2) * 4 * s, y: y)
                    Paint.dab(ctx, p, 8 * s, 6 * s, UIColor(hex: 0x6E4A2A))
                    Paint.dab(ctx, CGPoint(x: p.x, y: p.y + 2 * s), 6 * s, 3 * s, UIColor(hex: 0x9A6E42))
                }
            }
            Paint.stroke(ctx, from: CGPoint(x: c.x, y: c.y - 38 * s), to: CGPoint(x: c.x + 4 * s, y: c.y - 46 * s), bend: 0,
                         width: 3 * s, color: UIColor(hex: 0x5A3A22))
        },
        "snowdrop": { ctx, c, s, _ in
            for (dx, lean) in [(-12.0, -1.0), (10, 1)] as [(CGFloat, CGFloat)] {
                let top = CGPoint(x: c.x + dx * s, y: c.y - 24 * s)
                Paint.stroke(ctx, from: CGPoint(x: c.x, y: c.y + 42 * s), to: top, bend: 4 * s * lean, width: 3 * s, color: UIColor(hex: 0x5E9A4E))
                let bell = CGPoint(x: top.x + 6 * s * lean, y: top.y + 12 * s)
                for k in -1...1 {
                    Paint.dab(ctx, CGPoint(x: bell.x + CGFloat(k) * 5 * s, y: bell.y), 5 * s, 11 * s, UIColor.white, rotation: CGFloat(k) * 0.3)
                }
                Paint.dab(ctx, CGPoint(x: bell.x, y: bell.y - 9 * s), 3 * s, 3 * s, UIColor(hex: 0x6AA84A))
            }
            leaf(ctx, from: CGPoint(x: c.x, y: c.y + 42 * s), angle: -.pi / 2 - 0.2, length: 36 * s, width: 6 * s, color: UIColor(hex: 0x6E9A7A))
        },
    ]

    private static func leaf(_ ctx: CGContext, from base: CGPoint, angle: CGFloat, length: CGFloat, width: CGFloat, color: UIColor) {
        let tip = CGPoint(x: base.x + cos(angle) * length, y: base.y + sin(angle) * length)
        let mid = CGPoint(x: (base.x + tip.x) / 2, y: (base.y + tip.y) / 2)
        let nx = -sin(angle) * width, ny = cos(angle) * width
        let path = CGMutablePath()
        path.move(to: base)
        path.addQuadCurve(to: tip, control: CGPoint(x: mid.x + nx, y: mid.y + ny))
        path.addQuadCurve(to: base, control: CGPoint(x: mid.x - nx, y: mid.y - ny))
        Paint.outline(ctx, path, ink, width: 1.6)
        Paint.fill(ctx, path, top: color.shaded(0.1), bottom: color.shaded(-0.12))
        Paint.stroke(ctx, from: base, to: tip, bend: 0, width: 1.2, color: color.shaded(-0.25))
    }

    private static func star(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat, _ color: UIColor, center: UIColor) {
        for k in 0..<6 {
            let a = CGFloat(k) * .pi / 3
            Paint.dab(ctx, CGPoint(x: c.x + cos(a) * r * 0.6, y: c.y + sin(a) * r * 0.6), r * 0.45, r * 0.3, color, rotation: a)
        }
        Paint.dab(ctx, c, r * 0.25, r * 0.25, center)
    }

    private static func daisy(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat) {
        for k in 0..<10 {
            let a = CGFloat(k) * .pi / 5
            Paint.dab(ctx, CGPoint(x: c.x + cos(a) * r * 0.62, y: c.y + sin(a) * r * 0.62), r * 0.4, r * 0.16, UIColor.white, rotation: a)
        }
        Paint.dab(ctx, c, r * 0.36, r * 0.36, UIColor(hex: 0xF2C83A))
    }

    private static func berry(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat, _ color: UIColor, smooth: Bool = false) {
        if smooth {
            let ball = CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r), transform: nil)
            Paint.outline(ctx, ball, ink, width: 1.5)
            Paint.fill(ctx, ball, top: color.shaded(0.15), bottom: color.shaded(-0.15))
            Paint.dab(ctx, CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.35), r * 0.3, r * 0.3, UIColor.white.withAlpha(0.6))
            return
        }
        for (dx, dy) in [(-0.45, -0.4), (0.45, -0.4), (0, 0), (-0.45, 0.4), (0.45, 0.4), (0, -0.75), (0, 0.75)] as [(CGFloat, CGFloat)] {
            let p = CGPoint(x: c.x + dx * r, y: c.y + dy * r)
            Paint.dab(ctx, p, r * 0.42, r * 0.42, color)
            Paint.dab(ctx, CGPoint(x: p.x - r * 0.12, y: p.y - r * 0.12), r * 0.12, r * 0.12, UIColor.white.withAlpha(0.45))
        }
    }
}
