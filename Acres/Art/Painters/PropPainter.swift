import UIKit
import AcresCore

/// Nature props (bushes, rocks, flowers, pond) and farm props (fences, well, …).
enum PropPainter {

    static func paint(_ spec: AssetSpec, rng: inout SeededRandom) -> UIImage? {
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        let ground = size.height * (1 - CGFloat(spec.anchorY))
        switch spec.name {
        case "nature_bush_a": return bush(size, ground: ground, color: UIColor(hex: 0x5F8C43), rng: &rng)
        case "nature_bush_b": return bush(size, ground: ground, color: UIColor(hex: 0x507C3E), rng: &rng)
        case "nature_rock_small": return rock(size, ground: ground, mossy: false, rng: &rng)
        case "nature_rock_large": return rock(size, ground: ground, mossy: true, rng: &rng)
        case "nature_grass_tuft_a": return tuft(size, ground: ground, seedHeads: false, rng: &rng)
        case "nature_grass_tuft_b": return tuft(size, ground: ground, seedHeads: true, rng: &rng)
        case "nature_flowers_yellow": return flowers(size, ground: ground, petal: UIColor(hex: 0xF2C94C), center: UIColor(hex: 0xB9782F), rng: &rng)
        case "nature_flowers_white": return flowers(size, ground: ground, petal: UIColor(hex: 0xF6F3EA), center: UIColor(hex: 0xE8B83A), rng: &rng)
        case "nature_flowers_purple": return flowers(size, ground: ground, petal: UIColor(hex: 0x9E7BC4), center: UIColor(hex: 0xF0D98A), rng: &rng)
        case "nature_pond_small": return pond(size, rng: &rng)
        case "prop_fence_wood_h": return fenceHorizontal(size, ground: ground, broken: false, rng: &rng)
        case "prop_fence_wood_h_broken": return fenceHorizontal(size, ground: ground, broken: true, rng: &rng)
        case "prop_fence_wood_v": return fenceVertical(size, ground: ground, rng: &rng)
        case "prop_fence_wood_post": return fencePost(size, ground: ground, rng: &rng)
        case "prop_well": return well(size, ground: ground, rng: &rng)
        case "prop_mailbox": return mailbox(size, ground: ground)
        case "prop_log_pile": return logPile(size, ground: ground, rng: &rng)
        case "prop_crate": return crate(size, ground: ground, rng: &rng)
        case "prop_hay_bale": return hayBale(size, ground: ground, rng: &rng)
        case "prop_sign_for_sale": return forSaleSign(size, ground: ground)
        default: return nil
        }
    }

    static let wood = UIColor(hex: 0x9A8062)
    static let woodDark = UIColor(hex: 0x5E4A36)
    static let ink = UIColor(hex: 0x2E2419).withAlpha(0.5)

    // MARK: Nature

    static func bush(_ size: CGSize, ground: CGFloat, color: UIColor, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            let path = CGMutablePath()
            for i in 0..<5 {
                let c = CGPoint(x: w * (0.3 + 0.1 * CGFloat(i)) + rng.cg(-6...6), y: ground - h * rng.cg(0.35...0.55))
                path.addPath(Paint.blobPath(c, rx: w * 0.26, ry: h * 0.36, lumps: 9, lumpiness: 0.14, rng: &rng))
            }
            ctx.saveGState()
            ctx.addPath(path)
            ctx.setStrokeColor(UIColor(hex: 0x24361A).withAlpha(0.45).cgColor)
            ctx.setLineWidth(4)
            ctx.strokePath()
            ctx.restoreGState()
            Paint.fill(ctx, path, top: color.shaded(0.08), bottom: color.shaded(-0.18))
            Paint.leafDabs(ctx, in: path, base: color, count: 140, size: 2.5...6, rng: &rng)
        }
    }

    static func rock(_ size: CGSize, ground: CGFloat, mossy: Bool, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            let path = Paint.blobPath(CGPoint(x: w / 2, y: ground - h * 0.38), rx: w * 0.44, ry: h * 0.42, lumps: 7, lumpiness: 0.16, rng: &rng)
            Paint.outline(ctx, path, UIColor(hex: 0x2F2F2C).withAlpha(0.5), width: 3)
            Paint.fill(ctx, path, top: UIColor(hex: 0xA9A69C), bottom: UIColor(hex: 0x6E6B64))
            Paint.clipped(ctx, to: path) {
                Paint.softSpot(ctx, CGPoint(x: w * 0.35, y: ground - h * 0.7), w * 0.4, UIColor.white.withAlpha(0.3))
                for _ in 0..<Int(w * 0.3) {
                    Paint.dab(ctx, rng.point(in: CGRect(origin: .zero, size: size)), rng.cg(1...3), rng.cg(1...2),
                              UIColor(hex: 0x55534D).withAlpha(0.35))
                }
                if mossy {
                    for _ in 0..<40 {
                        let p = CGPoint(x: rng.cg(w * 0.2...w * 0.7), y: rng.cg(ground - h * 0.85...ground - h * 0.55))
                        Paint.dab(ctx, p, rng.cg(4...9), rng.cg(3...6), UIColor(hex: 0x6E8B3D).withAlpha(0.6))
                    }
                }
            }
        }
    }

    static func tuft(_ size: CGSize, ground: CGFloat, seedHeads: Bool, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            for _ in 0..<16 {
                let base = CGPoint(x: w / 2 + rng.cg(-w * 0.18...w * 0.18), y: ground)
                let angle = -CGFloat.pi / 2 + rng.cg(-0.7...0.7)
                let length = h * rng.cg(0.5...0.9)
                let tip = CGPoint(x: base.x + cos(angle) * length, y: base.y + sin(angle) * length)
                let color = UIColor(hex: 0x5E8540).mixed(with: UIColor(hex: 0xA9C679), rng.cg(0...1))
                Paint.stroke(ctx, from: base, to: tip, bend: rng.cg(-6...6), width: rng.cg(2...3.5), color: color)
                if seedHeads && rng.chance(0.3) {
                    Paint.dab(ctx, tip, 3, 5, UIColor(hex: 0xC9B27A), rotation: angle + .pi / 2)
                }
            }
        }
    }

    static func flowers(_ size: CGSize, ground: CGFloat, petal: UIColor, center: UIColor, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            for _ in 0..<5 {
                let base = CGPoint(x: w / 2 + rng.cg(-w * 0.25...w * 0.25), y: ground)
                let top = CGPoint(x: base.x + rng.cg(-8...8), y: ground - h * rng.cg(0.4...0.8))
                Paint.stroke(ctx, from: base, to: top, bend: rng.cg(-4...4), width: 2, color: UIColor(hex: 0x5C8440))
                Paint.dab(ctx, CGPoint(x: (base.x + top.x) / 2 + 4, y: (base.y + top.y) / 2), 5, 2.5, UIColor(hex: 0x6E9A4C), rotation: 0.5)
                let r = rng.cg(4...6)
                for k in 0..<5 {
                    let a = CGFloat(k) / 5 * .pi * 2
                    Paint.dab(ctx, CGPoint(x: top.x + cos(a) * r, y: top.y + sin(a) * r * 0.8), r * 0.8, r * 0.55, petal, rotation: a)
                }
                Paint.dab(ctx, top, r * 0.45, r * 0.45, center)
            }
        }
    }

    static func pond(_ size: CGSize, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            let center = CGPoint(x: w / 2, y: h / 2)
            let bank = Paint.blobPath(center, rx: w * 0.48, ry: h * 0.46, lumps: 10, lumpiness: 0.06, rng: &rng)
            Paint.fill(ctx, bank, top: UIColor(hex: 0x7E6446), bottom: UIColor(hex: 0x8F7654))
            let water = Paint.blobPath(center, rx: w * 0.42, ry: h * 0.38, lumps: 10, lumpiness: 0.07, rng: &rng)
            Paint.fill(ctx, water, top: UIColor(hex: 0x3F6E7A), bottom: UIColor(hex: 0x5D8E93))
            Paint.clipped(ctx, to: water) {
                // Darker near the top bank (shade), sky highlights.
                ctx.drawLinearGradient(Paint.gradient([UIColor(hex: 0x1F3A40).withAlpha(0.45), UIColor.clear]),
                                       start: CGPoint(x: 0, y: center.y - h * 0.4), end: CGPoint(x: 0, y: center.y - h * 0.1), options: [])
                for _ in 0..<7 {
                    let p = CGPoint(x: rng.cg(w * 0.25...w * 0.75), y: rng.cg(h * 0.4...h * 0.75))
                    Paint.dab(ctx, p, rng.cg(12...30), rng.cg(1.5...3), UIColor.white.withAlpha(0.35))
                }
                for _ in 0..<5 {
                    let p = CGPoint(x: rng.cg(w * 0.2...w * 0.8), y: rng.cg(h * 0.3...h * 0.7))
                    Paint.dab(ctx, p, 10, 7, UIColor(hex: 0x6D9A4A))
                    Paint.dab(ctx, CGPoint(x: p.x + 3, y: p.y - 1), 3, 2, UIColor(hex: 0x4E7536))
                }
            }
            Paint.outline(ctx, water, UIColor(hex: 0x2E4A40).withAlpha(0.5), width: 3)
            // Reeds at the edges.
            for _ in 0..<5 {
                let angle = rng.cg(0...(2 * .pi))
                let base = CGPoint(x: center.x + cos(angle) * w * 0.43, y: center.y + sin(angle) * h * 0.4)
                for _ in 0..<6 {
                    Paint.stroke(ctx, from: base, to: CGPoint(x: base.x + rng.cg(-8...8), y: base.y - rng.cg(14...30)),
                                 bend: rng.cg(-3...3), width: 2.2, color: UIColor(hex: 0x6F8D45))
                }
            }
        }
    }

    // MARK: Fences

    private static func plank(_ ctx: CGContext, _ rect: CGRect, rng: inout SeededRandom) {
        let path = Paint.roundedRect(rect, 2)
        Paint.outline(ctx, path, ink, width: 2)
        Paint.fill(ctx, path, top: rng.vary(wood, 0.06).shaded(0.06), bottom: wood.shaded(-0.14))
        ctx.setStrokeColor(woodDark.withAlpha(0.35).cgColor)
        ctx.setLineWidth(1)
        let horizontal = rect.width > rect.height
        ctx.move(to: horizontal ? CGPoint(x: rect.minX + 4, y: rect.midY) : CGPoint(x: rect.midX, y: rect.minY + 4))
        ctx.addLine(to: horizontal ? CGPoint(x: rect.maxX - 4, y: rect.midY + 1) : CGPoint(x: rect.midX + 1, y: rect.maxY - 4))
        ctx.strokePath()
    }

    private static func post(_ ctx: CGContext, x: CGFloat, top: CGFloat, bottom: CGFloat, width: CGFloat, rng: inout SeededRandom) {
        let rect = CGRect(x: x - width / 2, y: top, width: width, height: bottom - top)
        let path = Paint.roundedRect(rect, 2)
        Paint.outline(ctx, path, ink, width: 2)
        Paint.fillHorizontal(ctx, path, left: wood.shaded(0.05), right: woodDark)
        ctx.setFillColor(wood.shaded(0.15).cgColor)
        ctx.fillEllipse(in: CGRect(x: rect.minX, y: rect.minY - 3, width: width, height: 6))
    }

    static func fenceHorizontal(_ size: CGSize, ground: CGFloat, broken: Bool, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            let postWidth = w * 0.1
            let postX = postWidth / 2 + 2
            let top = ground - h * 0.78
            post(ctx, x: postX, top: top, bottom: ground, width: postWidth, rng: &rng)
            let rail1 = CGRect(x: postX, y: top + h * 0.12, width: w - postX, height: h * 0.1)
            plank(ctx, rail1, rng: &rng)
            if broken {
                // The lower rail has come loose and hangs to the ground.
                ctx.saveGState()
                ctx.translateBy(x: postX + 4, y: top + h * 0.45)
                ctx.rotate(by: 0.32)
                plank(ctx, CGRect(x: 0, y: 0, width: w * 0.8, height: h * 0.1), rng: &rng)
                ctx.restoreGState()
            } else {
                plank(ctx, CGRect(x: postX, y: top + h * 0.42, width: w - postX, height: h * 0.1), rng: &rng)
            }
        }
    }

    static func fenceVertical(_ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        let w = size.width
        // One tile of depth (64 world points) is 128 px of canvas at 2 px per point.
        let tileDepth = CGFloat(AssetSpec.pixelsPerTile)
        let postHeight = tileDepth * 0.7
        return Canvas.image(size) { ctx in
            let farGround = ground - tileDepth
            // Far post (behind), rails running toward the camera, near post (in front).
            post(ctx, x: w / 2, top: farGround - postHeight, bottom: farGround, width: w * 0.36, rng: &rng)
            for height in [postHeight * 0.3, postHeight * 0.66] {
                let rail = CGRect(x: w / 2 - w * 0.12, y: farGround - height, width: w * 0.24, height: tileDepth + 6)
                plank(ctx, rail, rng: &rng)
            }
            post(ctx, x: w / 2, top: ground - postHeight, bottom: ground, width: w * 0.36, rng: &rng)
        }
    }

    static func fencePost(_ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            post(ctx, x: w / 2, top: ground - h * 0.8, bottom: ground, width: w * 0.8, rng: &rng)
        }
    }

    // MARK: Farm props

    static func well(_ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            let rimY = ground - h * 0.3
            let rx = w * 0.36, ry = h * 0.1
            // Stone cylinder.
            let body = CGMutablePath()
            body.move(to: CGPoint(x: w / 2 - rx, y: rimY))
            body.addLine(to: CGPoint(x: w / 2 - rx, y: ground - ry))
            body.addQuadCurve(to: CGPoint(x: w / 2 + rx, y: ground - ry), control: CGPoint(x: w / 2, y: ground + ry))
            body.addLine(to: CGPoint(x: w / 2 + rx, y: rimY))
            body.closeSubpath()
            Paint.outline(ctx, body, ink, width: 3)
            Paint.fillHorizontal(ctx, body, left: UIColor(hex: 0xA39E92), right: UIColor(hex: 0x6D695F))
            Paint.clipped(ctx, to: body) {
                for row in 0..<4 {
                    for col in 0..<6 {
                        let x = w / 2 - rx + CGFloat(col) * rx / 3 + (row % 2 == 0 ? 0 : rx / 6)
                        let y = rimY + CGFloat(row) * (ground - rimY) / 4 + 4
                        let stone = CGRect(x: x + 2, y: y, width: rx / 3 - 4, height: (ground - rimY) / 4 - 3)
                        Paint.fill(ctx, Paint.roundedRect(stone, 4), rng.vary(UIColor(hex: 0x9A958A), 0.08))
                    }
                }
            }
            let rim = CGRect(x: w / 2 - rx, y: rimY - ry, width: rx * 2, height: ry * 2)
            ctx.setFillColor(UIColor(hex: 0xB1AC9F).cgColor)
            ctx.fillEllipse(in: rim)
            ctx.setFillColor(UIColor(hex: 0x1E2A2E).cgColor)
            ctx.fillEllipse(in: rim.insetBy(dx: 12, dy: 5))
            // Posts and roof.
            let roofY = h * 0.14
            post(ctx, x: w / 2 - rx + 8, top: roofY + 20, bottom: rimY, width: 10, rng: &rng)
            post(ctx, x: w / 2 + rx - 8, top: roofY + 20, bottom: rimY, width: 10, rng: &rng)
            let roof = Paint.polygon([
                CGPoint(x: w * 0.08, y: roofY + 44), CGPoint(x: w / 2, y: roofY), CGPoint(x: w * 0.92, y: roofY + 44),
            ])
            Paint.outline(ctx, roof, ink, width: 3)
            Paint.fill(ctx, roof, top: UIColor(hex: 0x8C5443), bottom: UIColor(hex: 0x6E3F31))
            // Rope and bucket.
            ctx.setStrokeColor(UIColor(hex: 0xC9B48A).cgColor)
            ctx.setLineWidth(2)
            ctx.move(to: CGPoint(x: w / 2, y: roofY + 44)); ctx.addLine(to: CGPoint(x: w / 2, y: rimY - 30))
            ctx.strokePath()
            let bucket = Paint.polygon([
                CGPoint(x: w / 2 - 10, y: rimY - 32), CGPoint(x: w / 2 + 10, y: rimY - 32),
                CGPoint(x: w / 2 + 8, y: rimY - 14), CGPoint(x: w / 2 - 8, y: rimY - 14),
            ])
            Paint.fill(ctx, bucket, top: wood, bottom: woodDark)
        }
    }

    static func mailbox(_ size: CGSize, ground: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            let postRect = CGRect(x: w / 2 - 4, y: h * 0.4, width: 8, height: ground - h * 0.4)
            Paint.fillHorizontal(ctx, Paint.roundedRect(postRect, 2), left: wood, right: woodDark)
            let box = CGRect(x: w * 0.12, y: h * 0.16, width: w * 0.76, height: h * 0.26)
            let path = Paint.roundedRect(box, box.width * 0.35)
            Paint.outline(ctx, path, ink, width: 2.5)
            Paint.fill(ctx, path, top: UIColor(hex: 0x8F9A9E), bottom: UIColor(hex: 0x5F6A6E))
            // A rust spot.
            Paint.dab(ctx, CGPoint(x: box.minX + box.width * 0.3, y: box.maxY - 6), 6, 3, UIColor(hex: 0x8A5634).withAlpha(0.7))
            // Red flag.
            ctx.setFillColor(UIColor(hex: 0xB8432F).cgColor)
            ctx.fill(CGRect(x: box.maxX - 6, y: box.minY - 8, width: 4, height: 22))
            ctx.fill(CGRect(x: box.maxX - 6, y: box.minY - 8, width: 12, height: 8))
        }
    }

    static func logPile(_ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            // Side view of the stack's length first, then log ends on the left.
            let r = h * 0.14
            let rows = [4, 3, 2]
            for (row, count) in rows.enumerated() {
                for i in 0..<count {
                    let cx = w * 0.24 + CGFloat(i) * r * 1.9 + CGFloat(row) * r * 0.95
                    let cy = ground - r - CGFloat(row) * r * 1.65
                    let body = CGRect(x: cx, y: cy - r, width: w * 0.5, height: r * 2)
                    Paint.fill(ctx, Paint.roundedRect(body, r * 0.6), top: UIColor(hex: 0x8A6A4B), bottom: UIColor(hex: 0x5A4130))
                    let end = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                    ctx.setFillColor(UIColor(hex: 0x5C4128).cgColor)
                    ctx.fillEllipse(in: end)
                    ctx.setFillColor(rng.vary(UIColor(hex: 0xD6B98A), 0.05).cgColor)
                    ctx.fillEllipse(in: end.insetBy(dx: 3, dy: 3))
                    ctx.setStrokeColor(UIColor(hex: 0xA9885C).cgColor)
                    ctx.setLineWidth(1.2)
                    ctx.strokeEllipse(in: end.insetBy(dx: r * 0.45, dy: r * 0.45))
                }
            }
        }
    }

    static func crate(_ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            let front = CGRect(x: w * 0.1, y: ground - h * 0.6, width: w * 0.8, height: h * 0.6)
            let top = Paint.polygon([
                CGPoint(x: front.minX, y: front.minY), CGPoint(x: front.maxX, y: front.minY),
                CGPoint(x: front.maxX - 6, y: front.minY - h * 0.28), CGPoint(x: front.minX + 6, y: front.minY - h * 0.28),
            ])
            Paint.outline(ctx, top, ink, width: 2.5)
            Paint.fill(ctx, top, top: UIColor(hex: 0xC3A276), bottom: UIColor(hex: 0xB08F63))
            let frontPath = Paint.roundedRect(front, 2)
            Paint.outline(ctx, frontPath, ink, width: 2.5)
            Paint.fill(ctx, frontPath, top: UIColor(hex: 0xA3825A), bottom: UIColor(hex: 0x806341))
            ctx.setStrokeColor(UIColor(hex: 0x5E4630).withAlpha(0.6).cgColor)
            ctx.setLineWidth(2)
            for k in 1..<3 {
                let y = front.minY + front.height * CGFloat(k) / 3
                ctx.move(to: CGPoint(x: front.minX, y: y)); ctx.addLine(to: CGPoint(x: front.maxX, y: y))
            }
            ctx.move(to: CGPoint(x: front.minX + 4, y: front.minY + 4)); ctx.addLine(to: CGPoint(x: front.maxX - 4, y: front.maxY - 4))
            ctx.strokePath()
        }
    }

    static func hayBale(_ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        let straw = UIColor(hex: 0xD6B45F)
        return Canvas.image(size) { ctx in
            let front = CGRect(x: w * 0.06, y: ground - h * 0.55, width: w * 0.88, height: h * 0.55)
            let top = Paint.polygon([
                CGPoint(x: front.minX, y: front.minY), CGPoint(x: front.maxX, y: front.minY),
                CGPoint(x: front.maxX - 8, y: front.minY - h * 0.3), CGPoint(x: front.minX + 8, y: front.minY - h * 0.3),
            ])
            for (path, lit) in [(top, true), (Paint.roundedRect(front, 8), false)] {
                Paint.outline(ctx, path, UIColor(hex: 0x6B5227).withAlpha(0.5), width: 2.5)
                Paint.fill(ctx, path, top: straw.shaded(lit ? 0.08 : -0.02), bottom: straw.shaded(lit ? 0 : -0.16))
                Paint.clipped(ctx, to: path) {
                    let box = path.boundingBoxOfPath
                    for _ in 0..<90 {
                        let p = rng.point(in: box)
                        Paint.stroke(ctx, from: p, to: CGPoint(x: p.x + rng.cg(-10...10), y: p.y + rng.cg(-3...3)),
                                     bend: rng.cg(-2...2), width: 1.3, color: rng.chance(0.5) ? straw.shaded(0.15) : straw.shaded(-0.2))
                    }
                }
            }
            // Twine.
            ctx.setStrokeColor(UIColor(hex: 0x8C6A3A).cgColor)
            ctx.setLineWidth(2.5)
            for fx in [0.3, 0.7] {
                let x = front.minX + front.width * CGFloat(fx)
                ctx.move(to: CGPoint(x: x, y: front.maxY)); ctx.addLine(to: CGPoint(x: x, y: front.minY))
                ctx.addLine(to: CGPoint(x: x + (fx < 0.5 ? 3 : -3), y: front.minY - h * 0.3))
            }
            ctx.strokePath()
        }
    }

    static func forSaleSign(_ size: CGSize, ground: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            let stake = CGRect(x: w / 2 - 5, y: h * 0.4, width: 10, height: ground - h * 0.4)
            Paint.fillHorizontal(ctx, Paint.roundedRect(stake, 2), left: wood, right: woodDark)
            let board = CGRect(x: w * 0.06, y: h * 0.08, width: w * 0.88, height: h * 0.4)
            let path = Paint.roundedRect(board, 4)
            Paint.outline(ctx, path, ink, width: 3)
            Paint.fill(ctx, path, top: UIColor(hex: 0xF1E8D2), bottom: UIColor(hex: 0xDDD1B4))
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let font = UIFont.systemFont(ofSize: board.height * 0.3, weight: .heavy)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: UIColor(hex: 0xA8382A), .paragraphStyle: style,
            ]
            let text = NSAttributedString(string: "FOR\nSALE", attributes: attributes)
            text.draw(in: board.insetBy(dx: 4, dy: board.height * 0.1))
        }
    }
}
