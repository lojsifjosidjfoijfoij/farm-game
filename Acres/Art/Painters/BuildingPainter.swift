import UIKit
import AcresCore

/// Placeholder buildings in 3/4 view: the front (south) wall faces the camera
/// and the roof is seen from above.
enum BuildingPainter {

    static func paint(_ spec: AssetSpec, rng: inout SeededRandom) -> UIImage? {
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        switch spec.name {
        case "building_farmhouse_t0": return farmhouse(size, rng: &rng)
        case "building_farmhouse_t0_lights": return farmhouseLights(size)
        case "building_barn_old": return oldBarn(size, rng: &rng)
        default: return nil
        }
    }

    // MARK: Farmhouse (starter, run-down)

    /// Shared geometry so the night-lights overlay lines up with the windows,
    /// and the scene knows where the chimney is. Fractions of the canvas,
    /// origin top-left.
    enum FarmhouseLayout {
        static let wall = CGRect(x: 0.16, y: 0.645, width: 0.68, height: 0.295)
        static let leftWindow = CGRect(x: 0.225, y: 0.72, width: 0.11, height: 0.11)
        static let rightWindow = CGRect(x: 0.62, y: 0.72, width: 0.11, height: 0.11)
        static let door = CGRect(x: 0.4, y: 0.75, width: 0.095, height: 0.19)
        static let chimney = CGRect(x: 0.66, y: 0.29, width: 0.065, height: 0.13)
        /// Top center of the chimney in SpriteKit-style unit coordinates
        /// (origin bottom-left), for the smoke emitter.
        static var chimneyTopUnit: CGPoint {
            CGPoint(x: chimney.midX, y: 1 - chimney.minY)
        }
    }

    static func farmhouse(_ size: CGSize, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        func r(_ rect: CGRect) -> CGRect { CGRect(x: rect.minX * w, y: rect.minY * h, width: rect.width * w, height: rect.height * h) }
        let wall = r(FarmhouseLayout.wall)
        let ink = UIColor(hex: 0x2E2419).withAlpha(0.55)

        return Canvas.image(size) { ctx in
            // Roof: back slope (thin, darker) and front slope (big), seen from above.
            let eaveY = wall.minY + 4
            let ridgeY = h * 0.39
            let backY = h * 0.32
            let back = Paint.polygon([
                CGPoint(x: wall.minX + 14, y: ridgeY), CGPoint(x: wall.maxX - 14, y: ridgeY),
                CGPoint(x: wall.maxX - 22, y: backY), CGPoint(x: wall.minX + 22, y: backY),
            ])
            let front = Paint.polygon([
                CGPoint(x: wall.minX - 22, y: eaveY), CGPoint(x: wall.maxX + 22, y: eaveY),
                CGPoint(x: wall.maxX - 14, y: ridgeY), CGPoint(x: wall.minX + 14, y: ridgeY),
            ])
            // Chimney behind the ridge.
            let chimney = r(FarmhouseLayout.chimney)
            let chimneyPath = Paint.roundedRect(chimney, 3)
            Paint.outline(ctx, chimneyPath, ink, width: 3)
            Paint.fillHorizontal(ctx, chimneyPath, left: UIColor(hex: 0xA0634B), right: UIColor(hex: 0x6F4232))
            Paint.clipped(ctx, to: chimneyPath) {
                ctx.setStrokeColor(UIColor(hex: 0x4E2E22).withAlpha(0.5).cgColor)
                ctx.setLineWidth(1.5)
                var y = chimney.minY + 10
                while y < chimney.maxY {
                    ctx.move(to: CGPoint(x: chimney.minX, y: y)); ctx.addLine(to: CGPoint(x: chimney.maxX, y: y))
                    y += 11
                }
                ctx.strokePath()
            }
            ctx.setFillColor(UIColor(hex: 0x4A3B35).cgColor)
            ctx.fill(CGRect(x: chimney.minX - 4, y: chimney.minY - 5, width: chimney.width + 8, height: 9))

            Paint.outline(ctx, back, ink, width: 3)
            Paint.fill(ctx, back, top: UIColor(hex: 0x5E3A30), bottom: UIColor(hex: 0x6E4436))
            Paint.outline(ctx, front, ink, width: 3)
            Paint.fill(ctx, front, top: UIColor(hex: 0x8C5443), bottom: UIColor(hex: 0x7A4536))
            // Shingle rows with a few missing ones and a tarp patch.
            Paint.clipped(ctx, to: front) {
                var row = 0
                var y = ridgeY + 6
                while y < eaveY {
                    let offset: CGFloat = row % 2 == 0 ? 0 : 13
                    var x = wall.minX - 30 + offset
                    while x < wall.maxX + 30 {
                        let tile = CGRect(x: x, y: y, width: 24, height: 14)
                        let color = rng.chance(0.04) ? UIColor(hex: 0x3A2620) : rng.vary(UIColor(hex: 0x875040), 0.06)
                        ctx.setFillColor(color.cgColor)
                        ctx.fill(tile.insetBy(dx: 1, dy: 1))
                        x += 26
                    }
                    ctx.setFillColor(UIColor(hex: 0x4A2C23).withAlpha(0.35).cgColor)
                    ctx.fill(CGRect(x: wall.minX - 30, y: y + 12, width: wall.width + 60, height: 2))
                    y += 15
                    row += 1
                }
                // Tarp patch: the roof leaks.
                let tarp = Paint.polygon([
                    CGPoint(x: wall.minX + w * 0.12, y: ridgeY + 22), CGPoint(x: wall.minX + w * 0.27, y: ridgeY + 16),
                    CGPoint(x: wall.minX + w * 0.29, y: ridgeY + 70), CGPoint(x: wall.minX + w * 0.1, y: ridgeY + 76),
                ])
                Paint.fill(ctx, tarp, top: UIColor(hex: 0x6F8FA0), bottom: UIColor(hex: 0x557585))
                Paint.outline(ctx, tarp, UIColor(hex: 0x33444D).withAlpha(0.6), width: 2)
                // Light from the upper left.
                Paint.softSpot(ctx, CGPoint(x: wall.minX, y: ridgeY), w * 0.4, UIColor(hex: 0xFFF1D6).withAlpha(0.18))
            }
            // Eave shadow on the wall.
            let wallPath = Paint.roundedRect(wall, 2)
            Paint.outline(ctx, wallPath, ink, width: 3)
            Paint.fill(ctx, wallPath, top: UIColor(hex: 0xB9A47F), bottom: UIColor(hex: 0xA38F6D))
            Paint.clipped(ctx, to: wallPath) {
                // Vertical siding boards.
                var x = wall.minX + 8
                ctx.setStrokeColor(UIColor(hex: 0x6E5C43).withAlpha(0.45).cgColor)
                ctx.setLineWidth(2)
                while x < wall.maxX {
                    ctx.move(to: CGPoint(x: x, y: wall.minY)); ctx.addLine(to: CGPoint(x: x + rng.cg(-1...1), y: wall.maxY))
                    x += 20
                }
                ctx.strokePath()
                // Peeling paint and grime near the ground.
                for _ in 0..<40 {
                    let p = rng.point(in: wall)
                    Paint.dab(ctx, p, rng.cg(3...9), rng.cg(2...5), UIColor(hex: 0x8C6E4B).withAlpha(0.35))
                }
                ctx.drawLinearGradient(Paint.gradient([UIColor.black.withAlpha(0), UIColor(hex: 0x3B2E1E).withAlpha(0.35)]),
                                       start: CGPoint(x: 0, y: wall.maxY - 40), end: CGPoint(x: 0, y: wall.maxY), options: [])
                ctx.drawLinearGradient(Paint.gradient([UIColor.black.withAlpha(0.3), UIColor.black.withAlpha(0)]),
                                       start: CGPoint(x: 0, y: wall.minY), end: CGPoint(x: 0, y: wall.minY + 26), options: [])
            }
            // Stone foundation.
            let foundation = CGRect(x: wall.minX - 4, y: wall.maxY - 12, width: wall.width + 8, height: 14)
            ctx.setFillColor(UIColor(hex: 0x8A857C).cgColor)
            ctx.fill(foundation)
            for _ in 0..<26 {
                Paint.dab(ctx, rng.point(in: foundation), rng.cg(4...8), rng.cg(3...5), rng.vary(UIColor(hex: 0x9C968B), 0.1))
            }

            // Door with a little step.
            let door = r(FarmhouseLayout.door)
            let doorPath = Paint.roundedRect(door, 3)
            Paint.fill(ctx, doorPath, top: UIColor(hex: 0x7A5638), bottom: UIColor(hex: 0x5E412A))
            Paint.outline(ctx, doorPath, UIColor(hex: 0xE3D9C2), width: 5)
            Paint.dab(ctx, CGPoint(x: door.maxX - 10, y: door.midY + 6), 3, 3, UIColor(hex: 0xD8B25A))
            ctx.setFillColor(UIColor(hex: 0x9D968A).cgColor)
            ctx.fill(CGRect(x: door.minX - 12, y: door.maxY - 4, width: door.width + 24, height: 10))

            // Windows: left intact, right boarded up.
            window(ctx, r(FarmhouseLayout.leftWindow))
            let right = r(FarmhouseLayout.rightWindow)
            window(ctx, right)
            for k in 0..<2 {
                let y = right.minY + right.height * (0.3 + 0.4 * CGFloat(k))
                let board = Paint.polygon([
                    CGPoint(x: right.minX - 8, y: y - 6 + CGFloat(k) * 6), CGPoint(x: right.maxX + 8, y: y - 10 + CGFloat(k) * 10),
                    CGPoint(x: right.maxX + 8, y: y + 4 + CGFloat(k) * 10), CGPoint(x: right.minX - 8, y: y + 8 + CGFloat(k) * 6),
                ])
                Paint.fill(ctx, board, top: UIColor(hex: 0xA88A63), bottom: UIColor(hex: 0x8A6E4C))
                Paint.outline(ctx, board, UIColor(hex: 0x4E3B28).withAlpha(0.6), width: 1.5)
            }
        }
    }

    private static func window(_ ctx: CGContext, _ rect: CGRect) {
        let glass = Paint.roundedRect(rect, 2)
        Paint.fill(ctx, glass, top: UIColor(hex: 0x4B5A66), bottom: UIColor(hex: 0x303B44))
        Paint.clipped(ctx, to: glass) {
            ctx.setFillColor(UIColor.white.withAlpha(0.18).cgColor)
            ctx.fill(CGRect(x: rect.minX + rect.width * 0.15, y: rect.minY, width: rect.width * 0.18, height: rect.height))
        }
        Paint.outline(ctx, glass, UIColor(hex: 0xE3D9C2), width: 6)
        ctx.setStrokeColor(UIColor(hex: 0xE3D9C2).cgColor)
        ctx.setLineWidth(3)
        ctx.move(to: CGPoint(x: rect.midX, y: rect.minY)); ctx.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        ctx.move(to: CGPoint(x: rect.minX, y: rect.midY)); ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        ctx.strokePath()
    }

    /// Night overlay: warm light in the windows (drawn additively by the scene).
    static func farmhouseLights(_ size: CGSize) -> UIImage {
        let w = size.width, h = size.height
        func r(_ rect: CGRect) -> CGRect { CGRect(x: rect.minX * w, y: rect.minY * h, width: rect.width * w, height: rect.height * h) }
        return Canvas.image(size) { ctx in
            let warm = UIColor(hex: 0xFFC766)
            for (rect, strength) in [(r(FarmhouseLayout.leftWindow), CGFloat(1)), (r(FarmhouseLayout.rightWindow), CGFloat(0.45))] {
                Paint.softSpot(ctx, CGPoint(x: rect.midX, y: rect.midY), rect.width * 1.3, warm.withAlpha(0.35 * strength))
                ctx.setFillColor(warm.withAlpha(0.85 * strength).cgColor)
                ctx.fill(rect.insetBy(dx: 3, dy: 3))
            }
            // Light spilling under the door.
            let door = r(FarmhouseLayout.door)
            ctx.setFillColor(warm.withAlpha(0.5).cgColor)
            ctx.fill(CGRect(x: door.minX + 4, y: door.maxY - 5, width: door.width - 8, height: 3))
        }
    }

    // MARK: Old barn

    static func oldBarn(_ size: CGSize, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        let ground = h * 0.94
        let ink = UIColor(hex: 0x2A1A14).withAlpha(0.55)
        // Gable wall faces the camera; the gambrel roof recedes behind it.
        let left = w * 0.2, right = w * 0.8
        let eave = h * 0.6
        let knee = h * 0.46, kneeInset = w * 0.07
        let peak = h * 0.38
        let depth = h * 0.21  // how far the roof recedes upward on screen

        let gable = [
            CGPoint(x: left, y: ground), CGPoint(x: left, y: eave), CGPoint(x: left + kneeInset, y: knee),
            CGPoint(x: w / 2, y: peak), CGPoint(x: right - kneeInset, y: knee), CGPoint(x: right, y: eave),
            CGPoint(x: right, y: ground),
        ]
        func up(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: p.y - depth) }

        return Canvas.image(size) { ctx in
            // Roof faces, back to front: lower slopes (steep, darker), upper slopes (lit).
            let roofDark = UIColor(hex: 0x54443D), roofLight = UIColor(hex: 0x6E5A50)
            let faces: [([CGPoint], UIColor)] = [
                ([gable[1], gable[2], up(gable[2]), up(gable[1])], roofDark.shaded(-0.05)),
                ([gable[5], gable[4], up(gable[4]), up(gable[5])], roofDark.shaded(-0.1)),
                ([gable[2], gable[3], up(gable[3]), up(gable[2])], roofLight.shaded(0.06)),
                ([gable[3], gable[4], up(gable[4]), up(gable[3])], roofLight),
            ]
            for (points, color) in faces {
                let path = Paint.polygon(points)
                Paint.outline(ctx, path, ink, width: 3)
                Paint.fill(ctx, path, top: color.shaded(0.04), bottom: color.shaded(-0.06))
                Paint.clipped(ctx, to: path) {
                    // Shingle lines and a few holes.
                    ctx.setStrokeColor(UIColor.black.withAlpha(0.18).cgColor)
                    ctx.setLineWidth(1.5)
                    let box = path.boundingBoxOfPath
                    var y = box.minY + 6
                    while y < box.maxY {
                        ctx.move(to: CGPoint(x: box.minX, y: y)); ctx.addLine(to: CGPoint(x: box.maxX, y: y + 3))
                        y += 12
                    }
                    ctx.strokePath()
                    for _ in 0..<3 {
                        guard rng.chance(0.7) else { continue }
                        Paint.dab(ctx, rng.point(in: box.insetBy(dx: 10, dy: 10)), rng.cg(6...12), rng.cg(4...7), UIColor(hex: 0x1E1511).withAlpha(0.8))
                    }
                }
            }

            // Front gable wall: faded red boards.
            let wallPath = Paint.polygon(gable)
            Paint.outline(ctx, wallPath, ink, width: 3.5)
            Paint.fill(ctx, wallPath, top: UIColor(hex: 0x9A4535), bottom: UIColor(hex: 0x7E362A))
            Paint.clipped(ctx, to: wallPath) {
                var x = left + 10
                ctx.setStrokeColor(UIColor(hex: 0x4E1D16).withAlpha(0.45).cgColor)
                ctx.setLineWidth(2)
                while x < right {
                    ctx.move(to: CGPoint(x: x, y: peak)); ctx.addLine(to: CGPoint(x: x, y: ground))
                    x += 19
                }
                ctx.strokePath()
                for _ in 0..<60 {
                    Paint.dab(ctx, rng.point(in: CGRect(x: left, y: peak, width: right - left, height: ground - peak)),
                              rng.cg(3...10), rng.cg(2...5), UIColor(hex: 0xB9A58A).withAlpha(0.25))
                }
                // Missing boards.
                for _ in 0..<2 {
                    let x = rng.cg((left + 20)...(right - 60))
                    ctx.setFillColor(UIColor(hex: 0x24140F).withAlpha(0.85).cgColor)
                    ctx.fill(CGRect(x: x, y: rng.cg((eave - 20)...(eave + 30)), width: 14, height: rng.cg(30...60)))
                }
                ctx.drawLinearGradient(Paint.gradient([UIColor.black.withAlpha(0), UIColor(hex: 0x2B170F).withAlpha(0.4)]),
                                       start: CGPoint(x: 0, y: ground - 60), end: CGPoint(x: 0, y: ground), options: [])
            }
            // White trim along the gable.
            let trim = CGMutablePath()
            trim.addLines(between: Array(gable[1...5]))
            Paint.outline(ctx, trim, UIColor(hex: 0xE4DCCB), width: 7)

            // Big double doors with X braces.
            let door = CGRect(x: w * 0.36, y: ground - h * 0.25, width: w * 0.28, height: h * 0.25)
            ctx.setFillColor(UIColor(hex: 0x6E2C22).cgColor)
            ctx.fill(door)
            ctx.setStrokeColor(UIColor(hex: 0xE4DCCB).cgColor)
            ctx.setLineWidth(6)
            for half in [CGRect(x: door.minX, y: door.minY, width: door.width / 2, height: door.height),
                         CGRect(x: door.midX, y: door.minY, width: door.width / 2, height: door.height)] {
                ctx.stroke(half.insetBy(dx: 3, dy: 3))
                ctx.move(to: CGPoint(x: half.minX + 3, y: half.minY + 3)); ctx.addLine(to: CGPoint(x: half.maxX - 3, y: half.maxY - 3))
                ctx.move(to: CGPoint(x: half.maxX - 3, y: half.minY + 3)); ctx.addLine(to: CGPoint(x: half.minX + 3, y: half.maxY - 3))
                ctx.strokePath()
            }
            // Hayloft door.
            let loft = CGRect(x: w * 0.45, y: knee + 6, width: w * 0.1, height: h * 0.08)
            ctx.setFillColor(UIColor(hex: 0x2B1712).cgColor)
            ctx.fill(loft)
            ctx.setStrokeColor(UIColor(hex: 0xE4DCCB).cgColor)
            ctx.setLineWidth(4)
            ctx.stroke(loft)
        }
    }
}
