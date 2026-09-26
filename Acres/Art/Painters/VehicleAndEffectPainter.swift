import UIKit
import AcresCore

/// The player's truck and small effect sprites.
enum VehiclePainter {

    static func paint(_ spec: AssetSpec, rng: inout SeededRandom) -> UIImage? {
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        // Phase 1 only needs the parked truck facing west (dir08). The 16-direction
        // set arrives with driving in Phase 3.
        guard spec.name == "vehicle_truck_old_dir08" else { return nil }
        return truckFacingWest(size, rng: &rng)
    }

    /// Old pickup seen in 3/4 view, facing left: we see its roof and bed from
    /// above and its south side toward the camera.
    static func truckFacingWest(_ size: CGSize, rng: inout SeededRandom) -> UIImage {
        let s = size.width / 320  // layout designed on a 320 px canvas
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x * s, y: y * s, width: w * s, height: h * s) }
        let paint = UIColor(hex: 0x4F8A86)
        let ink = UIColor(hex: 0x1E2B2A).withAlpha(0.6)

        return Canvas.image(size) { ctx in
            // Wheels (south side) peek out below the body.
            for x in [CGFloat(72), 238] {
                ctx.setFillColor(UIColor(hex: 0x262626).cgColor)
                ctx.fillEllipse(in: rect(x - 20, 212, 40, 30))
                ctx.setFillColor(UIColor(hex: 0x8C8C86).cgColor)
                ctx.fillEllipse(in: rect(x - 8, 220, 16, 13))
            }

            // Top surfaces.
            let hoodTop = Paint.polygon([p(34, 104), p(106, 100), p(110, 192), p(30, 194)])
            let windshield = Paint.polygon([p(106, 100), p(122, 80), p(124, 168), p(110, 192)])
            let roof = Paint.roundedRect(rect(120, 78, 56, 90), 8)
            let bedRim = Paint.roundedRect(rect(176, 100, 116, 94), 4)
            let bedFloor = rect(186, 110, 98, 76)

            for path in [hoodTop, roof, bedRim] {
                Paint.outline(ctx, path, ink, width: 3)
            }
            Paint.fill(ctx, hoodTop, top: paint.shaded(0.14), bottom: paint.shaded(0.02))
            Paint.fill(ctx, windshield, top: UIColor(hex: 0x9FB7C0), bottom: UIColor(hex: 0x5D7680))
            Paint.outline(ctx, windshield, ink, width: 2)
            Paint.fill(ctx, roof, top: paint.shaded(0.18), bottom: paint.shaded(0.06))
            Paint.fill(ctx, bedRim, top: paint.shaded(0.1), bottom: paint.shaded(-0.02))
            // Bed floor: worn planks.
            let floor = Paint.roundedRect(bedFloor, 3)
            Paint.fill(ctx, floor, top: UIColor(hex: 0x6E5A44), bottom: UIColor(hex: 0x8A7152))
            Paint.clipped(ctx, to: floor) {
                ctx.setStrokeColor(UIColor(hex: 0x4A3B2C).withAlpha(0.6).cgColor)
                ctx.setLineWidth(2)
                var y = bedFloor.minY + 15 * s
                while y < bedFloor.maxY {
                    ctx.move(to: CGPoint(x: bedFloor.minX, y: y)); ctx.addLine(to: CGPoint(x: bedFloor.maxX, y: y))
                    y += 15 * s
                }
                ctx.strokePath()
            }

            // South side panels.
            let side = CGMutablePath()
            side.move(to: p(30, 194)); side.addLine(to: p(110, 192)); side.addLine(to: p(124, 168))
            side.addLine(to: p(176, 168)); side.addLine(to: p(176, 194)); side.addLine(to: p(292, 194))
            side.addLine(to: p(292, 222)); side.addLine(to: p(28, 224)); side.closeSubpath()
            Paint.outline(ctx, side, ink, width: 3)
            Paint.fill(ctx, side, top: paint.shaded(-0.04), bottom: paint.shaded(-0.2))
            Paint.clipped(ctx, to: side) {
                // Side window and door seam.
                Paint.fill(ctx, Paint.polygon([p(118, 190), p(128, 172), p(170, 172), p(170, 190)]), top: UIColor(hex: 0x8FA8B2), bottom: UIColor(hex: 0x566E78))
                ctx.setStrokeColor(ink.cgColor)
                ctx.setLineWidth(2)
                ctx.move(to: p(114, 196)); ctx.addLine(to: p(114, 220))
                ctx.move(to: p(172, 196)); ctx.addLine(to: p(172, 220))
                ctx.strokePath()
                // Rust and faded paint.
                for _ in 0..<14 {
                    let spot = CGPoint(x: rng.cg(40 * s...285 * s), y: rng.cg(200 * s...222 * s))
                    Paint.dab(ctx, spot, rng.cg(3...8) * s, rng.cg(2...4) * s, UIColor(hex: 0x8A4F2C).withAlpha(0.55))
                }
                // Wheel arches.
                for x in [CGFloat(72), 238] {
                    ctx.setFillColor(UIColor(hex: 0x1B1F1F).cgColor)
                    ctx.fillEllipse(in: rect(x - 24, 208, 48, 34))
                }
            }
            // Headlight and bumper.
            ctx.setFillColor(UIColor(hex: 0xF3E3A8).cgColor)
            ctx.fillEllipse(in: rect(26, 198, 10, 10))
            ctx.setFillColor(UIColor(hex: 0xBFC4C2).cgColor)
            ctx.fill(rect(22, 210, 10, 14))
            ctx.fill(rect(290, 208, 8, 14))
        }
    }
}

enum EffectPainter {

    static func paint(_ spec: AssetSpec, rng: inout SeededRandom) -> UIImage? {
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        switch spec.name {
        case "fx_shadow_soft":
            // Black ellipse fading out; the scene sets the overall opacity.
            return Canvas.image(size) { ctx in
                Paint.softSpot(ctx, CGPoint(x: size.width / 2, y: size.height / 2), size.width / 2, UIColor.black,
                               scaleY: size.height / size.width)
            }
        case "fx_smoke_puff":
            return Canvas.image(size) { ctx in
                for _ in 0..<5 {
                    let c = CGPoint(x: size.width / 2 + rng.cg(-8...8), y: size.height / 2 + rng.cg(-8...8))
                    Paint.softSpot(ctx, c, size.width * rng.cg(0.25...0.4), UIColor(hex: 0xF2F0EC).withAlpha(0.7))
                }
            }
        case "fx_window_glow":
            return Canvas.image(size) { ctx in
                Paint.softSpot(ctx, CGPoint(x: size.width / 2, y: size.height / 2), size.width / 2, UIColor(hex: 0xFFC766))
            }
        case "fx_tile_highlight":
            return Canvas.image(size) { ctx in
                let inset = size.width * 0.08
                let path = Paint.roundedRect(CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset), size.width * 0.16)
                Paint.fill(ctx, path, UIColor.white.withAlpha(0.18))
                Paint.outline(ctx, path, UIColor.white.withAlpha(0.9), width: size.width * 0.04)
            }
        default:
            return nil
        }
    }
}
