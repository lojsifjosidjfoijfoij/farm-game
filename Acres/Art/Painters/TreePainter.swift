import UIKit
import AcresCore

/// Trees, saplings and stumps. Canvas sizes come from the manifest; the tree
/// stands on the foot point (`anchorY`) at the bottom center.
enum TreePainter {

    static func paint(_ spec: AssetSpec, rng: inout SeededRandom) -> UIImage? {
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        let ground = size.height * (1 - CGFloat(spec.anchorY))
        let parts = spec.name.split(separator: "_").map(String.init)  // tree, species, look
        guard parts.count >= 2, parts[0] == "tree" else { return nil }

        if spec.name == "tree_stump" { return stump(size, ground: ground, rng: &rng) }
        guard parts.count == 3 else { return nil }
        let species = parts[1]
        let look = parts[2]
        let season = Season.allCases.first { $0.name.lowercased() == look }
        switch look {
        case "sapling": return sapling(species, size, ground: ground, rng: &rng)
        case "young": return deciduousOrPine(species, .summer, size, ground: ground, rng: &rng)
        case "fruit": return nil  // overlays arrive with Phase 4
        default:
            guard let season else { return nil }
            return deciduousOrPine(species, season, size, ground: ground, rng: &rng)
        }
    }

    private static func deciduousOrPine(_ species: String, _ season: Season, _ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        species == "pine"
            ? pine(size, ground: ground, season: season, rng: &rng)
            : deciduous(species, size, ground: ground, season: season, rng: &rng)
    }

    // MARK: Palettes

    struct Palette {
        let leaves: UIColor
        let accent: UIColor?     // blossoms / autumn highlights
        let bark: UIColor
        let snow: Bool
        let bare: Bool
    }

    static func palette(_ species: String, _ season: Season) -> Palette {
        let bark = species == "birch" ? UIColor(hex: 0xE6E0D2) : UIColor(hex: 0x6E5039)
        let summer: UIColor = switch species {
        case "birch": UIColor(hex: 0x86AE52)
        case "apple", "cherry": UIColor(hex: 0x6E9A48)
        case "maple": UIColor(hex: 0x6C9446)
        default: UIColor(hex: 0x5E8A3F)  // oak
        }
        switch season {
        case .summer:
            return Palette(leaves: summer, accent: nil, bark: bark, snow: false, bare: false)
        case .spring:
            let blossom: UIColor? = species == "cherry" ? UIColor(hex: 0xF2C4CE) : (species == "apple" ? UIColor(hex: 0xF7E9EC) : nil)
            return Palette(leaves: summer.shaded(0.1).mixed(with: UIColor(hex: 0xB6D36B), 0.35), accent: blossom, bark: bark, snow: false, bare: false)
        case .autumn:
            let leaves: UIColor = switch species {
            case "birch": UIColor(hex: 0xD9A93A)
            case "maple": UIColor(hex: 0xC4452D)
            default: UIColor(hex: 0xC7792F)
            }
            return Palette(leaves: leaves, accent: UIColor(hex: 0xE3B04B), bark: bark, snow: false, bare: false)
        case .winter:
            return Palette(leaves: UIColor(hex: 0x8B8F86), accent: nil, bark: bark, snow: true, bare: true)
        }
    }

    // MARK: Deciduous

    static func deciduous(_ species: String, _ size: CGSize, ground: CGFloat, season: Season, rng: inout SeededRandom) -> UIImage {
        let pal = palette(species, season)
        let w = size.width, h = size.height
        let isBirch = species == "birch"
        let trunkWidth = w * (isBirch ? 0.09 : 0.13)
        let canopyCenter = CGPoint(x: w / 2, y: h * (isBirch ? 0.36 : 0.4))
        let canopyRX = w * (isBirch ? 0.4 : 0.44)
        let canopyRY = h * (isBirch ? 0.3 : 0.32)
        let outlineColor = UIColor(hex: 0x2E3A22).withAlpha(0.45)

        return Canvas.image(size) { ctx in
            // Trunk (drawn first; the canopy covers its top).
            let trunkTop = canopyCenter.y + canopyRY * 0.2
            let trunk = CGMutablePath()
            trunk.move(to: CGPoint(x: w / 2 - trunkWidth * 0.7, y: ground))
            trunk.addQuadCurve(to: CGPoint(x: w / 2 - trunkWidth * 0.4, y: trunkTop),
                               control: CGPoint(x: w / 2 - trunkWidth * 0.35, y: ground - (ground - trunkTop) * 0.4))
            trunk.addLine(to: CGPoint(x: w / 2 + trunkWidth * 0.4, y: trunkTop))
            trunk.addQuadCurve(to: CGPoint(x: w / 2 + trunkWidth * 0.75, y: ground),
                               control: CGPoint(x: w / 2 + trunkWidth * 0.35, y: ground - (ground - trunkTop) * 0.4))
            trunk.closeSubpath()
            Paint.outline(ctx, trunk, outlineColor, width: 3)
            Paint.fillHorizontal(ctx, trunk, left: pal.bark.shaded(0.08), right: pal.bark.shaded(-0.22))
            Paint.clipped(ctx, to: trunk) {
                for _ in 0..<(isBirch ? 14 : 22) {
                    let y = rng.cg(trunkTop...ground)
                    let x = w / 2 + rng.cg(-trunkWidth * 0.5...trunkWidth * 0.5)
                    let color = isBirch ? UIColor(hex: 0x2F2A26).withAlpha(0.8) : pal.bark.shaded(-0.18).withAlpha(0.6)
                    if isBirch {
                        Paint.dab(ctx, CGPoint(x: x, y: y), rng.cg(3...7), rng.cg(1...2), color)
                    } else {
                        Paint.stroke(ctx, from: CGPoint(x: x, y: y), to: CGPoint(x: x + rng.cg(-2...2), y: y + rng.cg(10...24)),
                                     bend: rng.cg(-2...2), width: rng.cg(1.2...2.2), color: color)
                    }
                }
            }

            if pal.bare {
                bareBranches(ctx, from: CGPoint(x: w / 2, y: trunkTop + 10), spread: canopyRX, height: canopyRY * 1.6, color: pal.bark.shaded(-0.1), rng: &rng)
                return
            }

            // Canopy: a cluster of lumpy blobs. Outline pass first (fat dark
            // blobs), then the fill, so only the outer silhouette is outlined.
            var blobs: [CGPath] = []
            let count = isBirch ? 7 : 9
            for i in 0..<count {
                let angle = CGFloat(i) / CGFloat(count) * .pi * 2 + rng.cg(-0.3...0.3)
                let dist = i == 0 ? 0 : rng.cg(0.35...0.6)
                let c = CGPoint(x: canopyCenter.x + cos(angle) * canopyRX * dist,
                                y: canopyCenter.y + sin(angle) * canopyRY * dist * 0.9)
                let r = i == 0 ? 0.62 : rng.cg(0.38...0.5)
                blobs.append(Paint.blobPath(c, rx: canopyRX * r, ry: canopyRY * r, lumps: 11, lumpiness: 0.12, rng: &rng))
            }
            let canopy = CGMutablePath()
            for blob in blobs { canopy.addPath(blob) }

            ctx.saveGState()
            ctx.addPath(canopy)
            ctx.setStrokeColor(outlineColor.cgColor)
            ctx.setLineWidth(5)
            ctx.setLineJoin(.round)
            ctx.strokePath()
            ctx.restoreGState()
            Paint.fill(ctx, canopy, top: pal.leaves.shaded(0.06), bottom: pal.leaves.shaded(-0.16))

            // Leaf texture and light.
            Paint.leafDabs(ctx, in: canopy, base: pal.leaves, count: Int(w * 1.4), size: (w * 0.012)...(w * 0.028), rng: &rng)
            Paint.clipped(ctx, to: canopy) {
                Paint.softSpot(ctx, CGPoint(x: canopyCenter.x - canopyRX * 0.35, y: canopyCenter.y - canopyRY * 0.45),
                               canopyRX * 0.7, UIColor(hex: 0xFFF6D8).withAlpha(0.22))
                Paint.softSpot(ctx, CGPoint(x: canopyCenter.x + canopyRX * 0.3, y: canopyCenter.y + canopyRY * 0.6),
                               canopyRX * 0.8, UIColor(hex: 0x1E2A14).withAlpha(0.22))
            }
            if let accent = pal.accent {
                Paint.leafDabs(ctx, in: canopy, base: accent, count: Int(w * 0.35), size: (w * 0.01)...(w * 0.02), rng: &rng)
            }
            if pal.snow {
                snowCaps(ctx, on: canopy, rng: &rng)
            }
        }
    }

    // MARK: Pine

    static func pine(_ size: CGSize, ground: CGFloat, season: Season, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        let green = season == .spring ? UIColor(hex: 0x4A7A4C) : UIColor(hex: 0x3E6B47)
        let outlineColor = UIColor(hex: 0x1F3325).withAlpha(0.5)
        return Canvas.image(size) { ctx in
            // Short trunk.
            let trunk = Paint.roundedRect(CGRect(x: w / 2 - w * 0.05, y: ground - h * 0.14, width: w * 0.1, height: h * 0.14), 3)
            Paint.fillHorizontal(ctx, trunk, left: UIColor(hex: 0x76553B), right: UIColor(hex: 0x4E3726))

            // Tiers from bottom (wide) to top (narrow), each with a soft jagged lower edge.
            let tiers = 5
            let top = h * 0.04
            let bottom = ground - h * 0.1
            for i in 0..<tiers {
                let t = CGFloat(i) / CGFloat(tiers - 1)          // 0 = bottom tier
                let tierBottom = bottom - (bottom - top) * t * 0.78
                let tierTop = tierBottom - (bottom - top) * 0.36
                let halfWidth = w * (0.47 - 0.3 * t)
                let path = CGMutablePath()
                path.move(to: CGPoint(x: w / 2 + rng.cg(-2...2), y: max(top, tierTop)))
                // Jagged hem: little drooping points along the bottom edge.
                let teeth = 6
                path.addLine(to: CGPoint(x: w / 2 + halfWidth, y: tierBottom - 6))
                for k in stride(from: teeth, through: 0, by: -1) {
                    let x = w / 2 - halfWidth + 2 * halfWidth * CGFloat(k) / CGFloat(teeth)
                    let y = tierBottom + (k % 2 == 0 ? 0 : -10) + rng.cg(-3...3)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.closeSubpath()
                Paint.outline(ctx, path, outlineColor, width: 3.5)
                Paint.fill(ctx, path, top: green.shaded(0.08 - 0.04 * t), bottom: green.shaded(-0.16))
                // Needle texture: light on the left, dark on the right.
                Paint.clipped(ctx, to: path) {
                    Paint.softSpot(ctx, CGPoint(x: w / 2 - halfWidth * 0.5, y: tierBottom - 20), halfWidth * 0.8, UIColor(hex: 0xE8F2C8).withAlpha(0.14))
                    Paint.softSpot(ctx, CGPoint(x: w / 2 + halfWidth * 0.7, y: tierBottom - 10), halfWidth * 0.8, UIColor.black.withAlpha(0.14))
                }
                Paint.leafDabs(ctx, in: path, base: green, count: Int(halfWidth * 1.1), size: 2.5...5.5, rng: &rng)
                if season == .winter {
                    snowCaps(ctx, on: path, rng: &rng)
                }
            }
        }
    }

    // MARK: Small pieces

    static func sapling(_ species: String, _ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        let leaves = palette(species, .summer).leaves
        return Canvas.image(size) { ctx in
            // Stake and thin stem.
            ctx.setFillColor(UIColor(hex: 0x9C7A55).cgColor)
            ctx.fill(CGRect(x: w * 0.62, y: h * 0.25, width: 5, height: ground - h * 0.25))
            Paint.stroke(ctx, from: CGPoint(x: w / 2, y: ground), to: CGPoint(x: w / 2, y: h * 0.35), bend: 3, width: 4, color: UIColor(hex: 0x6E5039))
            Paint.dab(ctx, CGPoint(x: w / 2, y: ground), w * 0.25, w * 0.08, UIColor(hex: 0x6E5238).withAlpha(0.8))
            for _ in 0..<7 {
                let p = CGPoint(x: w / 2 + rng.cg(-w * 0.22...w * 0.22), y: rng.cg(h * 0.15...h * 0.45))
                Paint.dab(ctx, p, w * 0.12, w * 0.07, rng.vary(leaves, 0.1), rotation: rng.cg(0...3))
            }
        }
    }

    static func stump(_ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            let topY = h * 0.3
            let rx = w * 0.34, ry = h * 0.16
            // Side of the stump.
            let side = CGMutablePath()
            side.move(to: CGPoint(x: w / 2 - rx, y: topY))
            side.addLine(to: CGPoint(x: w / 2 - rx * 1.12, y: ground - ry * 0.4))
            side.addQuadCurve(to: CGPoint(x: w / 2 + rx * 1.12, y: ground - ry * 0.4), control: CGPoint(x: w / 2, y: ground + ry * 0.9))
            side.addLine(to: CGPoint(x: w / 2 + rx, y: topY))
            side.closeSubpath()
            Paint.outline(ctx, side, UIColor(hex: 0x2E2217).withAlpha(0.5), width: 3)
            Paint.fillHorizontal(ctx, side, left: UIColor(hex: 0x7A5A3E), right: UIColor(hex: 0x4A3424))
            Paint.clipped(ctx, to: side) {
                for _ in 0..<10 {
                    let x = rng.cg((w / 2 - rx)...(w / 2 + rx))
                    Paint.stroke(ctx, from: CGPoint(x: x, y: topY), to: CGPoint(x: x + rng.cg(-3...3), y: ground),
                                 bend: rng.cg(-2...2), width: 1.8, color: UIColor(hex: 0x3C2A1C).withAlpha(0.5))
                }
                Paint.softSpot(ctx, CGPoint(x: w / 2 - rx * 0.6, y: ground - 4), rx * 0.6, UIColor(hex: 0x6F8F3F).withAlpha(0.5))
            }
            // Cut surface with rings.
            let top = CGRect(x: w / 2 - rx, y: topY - ry, width: rx * 2, height: ry * 2)
            ctx.setFillColor(UIColor(hex: 0xD9BC8C).cgColor)
            ctx.fillEllipse(in: top)
            ctx.setStrokeColor(UIColor(hex: 0xA9885C).withAlpha(0.8).cgColor)
            ctx.setLineWidth(1.5)
            for k in 1...4 {
                let f = CGFloat(k) / 5
                ctx.strokeEllipse(in: top.insetBy(dx: rx * f, dy: ry * f))
            }
            ctx.setStrokeColor(UIColor(hex: 0x5C4128).cgColor)
            ctx.setLineWidth(3)
            ctx.strokeEllipse(in: top)
        }
    }

    // MARK: Details

    private static func snowCaps(_ ctx: CGContext, on path: CGPath, rng: inout SeededRandom) {
        let box = path.boundingBoxOfPath
        Paint.clipped(ctx, to: path) {
            for _ in 0..<Int(box.width * 0.25) {
                let p = CGPoint(x: rng.cg(box.minX...box.maxX), y: rng.cg(box.minY...(box.minY + box.height * 0.7)))
                Paint.dab(ctx, p, rng.cg(5...12), rng.cg(2.5...5), UIColor(hex: 0xF4F7FA).withAlpha(0.85))
            }
        }
    }

    private static func bareBranches(_ ctx: CGContext, from base: CGPoint, spread: CGFloat, height: CGFloat, color: UIColor, rng: inout SeededRandom) {
        for i in 0..<7 {
            let angle = -CGFloat.pi / 2 + (CGFloat(i) - 3) * 0.28 + rng.cg(-0.1...0.1)
            let length = height * rng.cg(0.55...0.8)
            let end = CGPoint(x: base.x + cos(angle) * length * (spread / height) * 1.3, y: base.y + sin(angle) * length)
            Paint.stroke(ctx, from: base, to: end, bend: rng.cg(-12...12), width: rng.cg(4...7), color: color)
            Paint.dab(ctx, CGPoint(x: end.x, y: end.y + 2), 8, 3, UIColor(hex: 0xF4F7FA).withAlpha(0.85))
        }
    }
}
