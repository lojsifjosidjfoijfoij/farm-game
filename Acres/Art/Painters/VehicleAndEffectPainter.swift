import UIKit
import AcresCore

/// The player's truck, drawn from simple 3D boxes so every one of the 16
/// directions is consistent: rotate the boxes, project them into the 3/4 view,
/// draw the faces that point toward the camera, back to front.
enum VehiclePainter {

    static func paint(_ spec: AssetSpec, rng: inout SeededRandom) -> UIImage? {
        // vehicle_truck_old_dirNN  or  vehicle_truck_old_loadL_dirNN
        let name = spec.name
        guard name.hasPrefix("vehicle_truck_old"), let range = name.range(of: "_dir"),
              let direction = Int(name[range.upperBound...]) else { return nil }
        let heading = CGFloat(direction) * .pi / 8
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        let origin = CGPoint(x: size.width / 2, y: size.height * (1 - CGFloat(spec.anchorY)))
        let pixelsPerTile = size.width / CGFloat(spec.tilesWide)
        let boxes: [Box]
        if name.contains("_load1_") {
            boxes = bedWalls + load(level: 1)
        } else if name.contains("_load2_") {
            boxes = bedWalls + load(level: 2)
        } else {
            boxes = truck
        }
        return Canvas.image(size) { ctx in
            draw(boxes, heading: heading, origin: origin, pixelsPerTile: pixelsPerTile, ctx: ctx)
        }
    }

    // MARK: Model (tile units: x forward, y left, z up)

    struct Box {
        var x0: CGFloat, x1: CGFloat, y0: CGFloat, y1: CGFloat, z0: CGFloat, z1: CGFloat
        var color: UIColor
        var style: Style = .plain

        enum Style { case plain, cab, glass }
    }

    static let paint = UIColor(hex: 0x4F8A86)
    static let paintDark = UIColor(hex: 0x3D6C69)
    static let tire = UIColor(hex: 0x262626)
    static let chrome = UIColor(hex: 0xBFC4C2)
    static let wood = UIColor(hex: 0x8A7152)

    static let bedWalls: [Box] = [
        Box(x0: -0.95, x1: -0.08, y0: 0.36, y1: 0.42, z0: 0.34, z1: 0.56, color: paint),
        Box(x0: -0.95, x1: -0.08, y0: -0.42, y1: -0.36, z0: 0.34, z1: 0.56, color: paint),
        Box(x0: -0.95, x1: -0.89, y0: -0.36, y1: 0.36, z0: 0.34, z1: 0.54, color: paint),
    ]

    static let truck: [Box] = {
        var boxes: [Box] = []
        for x in [-0.6, 0.58] as [CGFloat] {
            for (y0, y1) in [(-0.46, -0.3), (0.3, 0.46)] as [(CGFloat, CGFloat)] {
                boxes.append(Box(x0: x - 0.17, x1: x + 0.17, y0: y0, y1: y1, z0: 0, z1: 0.3, color: tire))
            }
        }
        boxes.append(Box(x0: -0.95, x1: 0.95, y0: -0.42, y1: 0.42, z0: 0.14, z1: 0.34, color: paintDark))
        boxes.append(Box(x0: 0.45, x1: 0.95, y0: -0.42, y1: 0.42, z0: 0.34, z1: 0.52, color: paint))
        boxes.append(Box(x0: -0.08, x1: 0.45, y0: -0.42, y1: 0.42, z0: 0.34, z1: 0.8, color: paint, style: .cab))
        boxes.append(Box(x0: -0.95, x1: -0.08, y0: -0.36, y1: 0.36, z0: 0.34, z1: 0.38, color: wood))
        boxes += bedWalls
        boxes.append(Box(x0: 0.95, x1: 1.0, y0: -0.4, y1: 0.4, z0: 0.14, z1: 0.26, color: chrome))
        boxes.append(Box(x0: -1.0, x1: -0.95, y0: -0.4, y1: 0.4, z0: 0.14, z1: 0.26, color: chrome))
        for y in [-0.28, 0.28] as [CGFloat] {
            boxes.append(Box(x0: 0.95, x1: 0.97, y0: y - 0.06, y1: y + 0.06, z0: 0.38, z1: 0.46, color: UIColor(hex: 0xF6E7B0)))
        }
        return boxes
    }()

    static func load(level: Int) -> [Box] {
        let crate = UIColor(hex: 0xB08D5F), sack = UIColor(hex: 0xC9B27F), green = UIColor(hex: 0x7FA34E)
        var boxes = [
            Box(x0: -0.86, x1: -0.56, y0: -0.3, y1: 0.0, z0: 0.38, z1: 0.62, color: crate),
            Box(x0: -0.5, x1: -0.2, y0: 0.02, y1: 0.3, z0: 0.38, z1: 0.6, color: sack),
            Box(x0: -0.5, x1: -0.16, y0: -0.3, y1: -0.02, z0: 0.38, z1: 0.56, color: green),
        ]
        if level >= 2 {
            boxes += [
                Box(x0: -0.86, x1: -0.56, y0: 0.02, y1: 0.3, z0: 0.38, z1: 0.62, color: crate.shaded(-0.05)),
                Box(x0: -0.84, x1: -0.58, y0: -0.26, y1: 0.0, z0: 0.62, z1: 0.82, color: crate.shaded(0.05)),
                Box(x0: -0.48, x1: -0.2, y0: 0.04, y1: 0.28, z0: 0.6, z1: 0.78, color: crate),
            ]
        }
        return boxes
    }

    // MARK: Projection

    /// How much 1 tile of height rises on screen (the 3/4 view's tilt).
    static let heightFactor: CGFloat = 0.8

    static func draw(_ boxes: [Box], heading: CGFloat, origin: CGPoint, pixelsPerTile ppt: CGFloat, ctx: CGContext) {
        let c = cos(heading), s = sin(heading)
        func ground(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * c - y * s, y: x * s + y * c) }
        func project(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CGPoint {
            let g = ground(x, y)
            return CGPoint(x: origin.x + g.x * ppt, y: origin.y - (g.y + z * heightFactor) * ppt)
        }
        // Far boxes first: depth grows toward the north and downward.
        let sorted = boxes.sorted { a, b in
            let ga = ground((a.x0 + a.x1) / 2, (a.y0 + a.y1) / 2), gb = ground((b.x0 + b.x1) / 2, (b.y0 + b.y1) / 2)
            let da = ga.y - (a.z0 + a.z1) / 2 / heightFactor
            let db = gb.y - (b.z0 + b.z1) / 2 / heightFactor
            return da > db
        }
        // Light from the upper left of the screen (north-west, above).
        let light = (x: CGFloat(-0.55), y: CGFloat(0.45), z: CGFloat(0.7))
        for box in sorted {
            // (corners, outward normal in local x/y, is top face, face kind)
            let faces: [([CGPoint], CGFloat, CGFloat, Bool, String)] = [
                ([project(box.x0, box.y0, box.z1), project(box.x1, box.y0, box.z1), project(box.x1, box.y1, box.z1), project(box.x0, box.y1, box.z1)], 0, 0, true, "top"),
                ([project(box.x1, box.y0, box.z0), project(box.x1, box.y1, box.z0), project(box.x1, box.y1, box.z1), project(box.x1, box.y0, box.z1)], 1, 0, false, "front"),
                ([project(box.x0, box.y1, box.z0), project(box.x0, box.y0, box.z0), project(box.x0, box.y0, box.z1), project(box.x0, box.y1, box.z1)], -1, 0, false, "back"),
                ([project(box.x1, box.y1, box.z0), project(box.x0, box.y1, box.z0), project(box.x0, box.y1, box.z1), project(box.x1, box.y1, box.z1)], 0, 1, false, "left"),
                ([project(box.x0, box.y0, box.z0), project(box.x1, box.y0, box.z0), project(box.x1, box.y0, box.z1), project(box.x0, box.y0, box.z1)], 0, -1, false, "right"),
            ]
            for (corners, nx, ny, isTop, kind) in faces {
                var brightness: CGFloat
                if isTop {
                    brightness = 1.1
                } else {
                    let world = ground(nx, ny)
                    guard world.y < -0.001 else { continue }  // faces away from the camera
                    brightness = 0.78 + 0.3 * max(0, world.x * light.x + world.y * light.y)
                }
                let color = box.color.shaded((brightness - 1) * 0.5)
                let path = Paint.polygon(corners)
                Paint.fill(ctx, path, color)
                if box.style == .cab && !isTop {
                    // Windows: the windshield (front) is mostly glass, the sides have a window.
                    let glass = UIColor(hex: kind == "front" ? 0x9FB9C2 : 0x86A2AD)
                    let window = quad(corners, u: 0.1...0.9, v: kind == "front" ? 0.35...0.92 : 0.45...0.9)
                    Paint.fill(ctx, Paint.polygon(window), glass.shaded((brightness - 1) * 0.3))
                    ctx.setStrokeColor(UIColor.white.withAlpha(0.35).cgColor)
                    ctx.setLineWidth(1.5)
                    ctx.move(to: window[0]); ctx.addLine(to: window[2])
                    ctx.strokePath()
                }
                Paint.outline(ctx, path, UIColor(hex: 0x1E2626).withAlpha(0.45), width: 1.5)
            }
        }
    }

    /// Sub-quad of a face given as [bottom-start, bottom-end, top-end, top-start].
    static func quad(_ c: [CGPoint], u: ClosedRange<CGFloat>, v: ClosedRange<CGFloat>) -> [CGPoint] {
        func at(_ uu: CGFloat, _ vv: CGFloat) -> CGPoint {
            let bottom = CGPoint(x: c[0].x + (c[1].x - c[0].x) * uu, y: c[0].y + (c[1].y - c[0].y) * uu)
            let top = CGPoint(x: c[3].x + (c[2].x - c[3].x) * uu, y: c[3].y + (c[2].y - c[3].y) * uu)
            return CGPoint(x: bottom.x + (top.x - bottom.x) * vv, y: bottom.y + (top.y - bottom.y) * vv)
        }
        return [at(u.lowerBound, v.lowerBound), at(u.upperBound, v.lowerBound), at(u.upperBound, v.upperBound), at(u.lowerBound, v.upperBound)]
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
        case "fx_sparkle":
            return Canvas.image(size) { ctx in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                Paint.softSpot(ctx, c, size.width * 0.45, UIColor(hex: 0xFFF3C4).withAlpha(0.6))
                let r = size.width * 0.46, t = size.width * 0.07
                let star = Paint.polygon([
                    CGPoint(x: c.x, y: c.y - r), CGPoint(x: c.x + t, y: c.y - t), CGPoint(x: c.x + r, y: c.y),
                    CGPoint(x: c.x + t, y: c.y + t), CGPoint(x: c.x, y: c.y + r), CGPoint(x: c.x - t, y: c.y + t),
                    CGPoint(x: c.x - r, y: c.y), CGPoint(x: c.x - t, y: c.y - t),
                ])
                Paint.fill(ctx, star, UIColor(hex: 0xFFFBEA))
            }
        case "fx_harvest_pop":
            return Canvas.image(size) { ctx in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                for k in 0..<10 {
                    let a = CGFloat(k) / 10 * .pi * 2 + rng.cg(-0.2...0.2)
                    let d = size.width * rng.cg(0.25...0.42)
                    let p = CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d)
                    let color = k % 3 == 0 ? UIColor(hex: 0x7A5638) : UIColor(hex: 0x8AB85C)
                    Paint.dab(ctx, p, size.width * 0.06, size.width * 0.035, color, rotation: a)
                }
            }
        case "fx_water_drops":
            return Canvas.image(size) { ctx in
                for _ in 0..<7 {
                    let p = CGPoint(x: rng.cg(size.width * 0.2...size.width * 0.8), y: rng.cg(size.height * 0.2...size.height * 0.8))
                    let r = size.width * rng.cg(0.04...0.07)
                    let drop = CGMutablePath()
                    drop.move(to: CGPoint(x: p.x, y: p.y - r * 2))
                    drop.addQuadCurve(to: CGPoint(x: p.x, y: p.y + r), control: CGPoint(x: p.x + r * 1.6, y: p.y + r * 0.6))
                    drop.addQuadCurve(to: CGPoint(x: p.x, y: p.y - r * 2), control: CGPoint(x: p.x - r * 1.6, y: p.y + r * 0.6))
                    Paint.fill(ctx, drop, top: UIColor(hex: 0xCFE6F2), bottom: UIColor(hex: 0x6FA6C8))
                    Paint.dab(ctx, CGPoint(x: p.x - r * 0.3, y: p.y - r * 0.2), r * 0.3, r * 0.2, UIColor.white.withAlpha(0.8))
                }
            }
        case "fx_dust_puff":
            return Canvas.image(size) { ctx in
                for _ in 0..<5 {
                    let c = CGPoint(x: size.width / 2 + rng.cg(-8...8), y: size.height / 2 + rng.cg(-6...6))
                    Paint.softSpot(ctx, c, size.width * rng.cg(0.22...0.36), UIColor(hex: 0xC2A27A).withAlpha(0.75))
                }
            }
        case "fx_guide_arrow":
            return Canvas.image(size) { ctx in
                let w = size.width, h = size.height
                let arrow = Paint.polygon([
                    CGPoint(x: w * 0.1, y: h * 0.38), CGPoint(x: w * 0.55, y: h * 0.38), CGPoint(x: w * 0.55, y: h * 0.18),
                    CGPoint(x: w * 0.92, y: h * 0.5), CGPoint(x: w * 0.55, y: h * 0.82), CGPoint(x: w * 0.55, y: h * 0.62),
                    CGPoint(x: w * 0.1, y: h * 0.62),
                ])
                ctx.setShadow(offset: CGSize(width: 0, height: 3), blur: 4, color: UIColor.black.withAlpha(0.35).cgColor)
                Paint.fill(ctx, arrow, top: UIColor(hex: 0xFFE08A), bottom: UIColor(hex: 0xF2B544))
                ctx.setShadow(offset: .zero, blur: 0, color: nil)
                Paint.outline(ctx, arrow, UIColor(hex: 0x7A4E12).withAlpha(0.8), width: w * 0.04)
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
