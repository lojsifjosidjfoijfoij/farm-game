import UIKit
import AcresCore

/// The farmer: a small, friendly figure in a straw hat, checked shirt and blue
/// overalls. Three facings (down = toward the camera, up = away, side =
/// facing left; mirrored in code) and poses for walking and each tool.
enum FarmerPainter {

    static func paint(_ spec: AssetSpec, rng: inout SeededRandom) -> UIImage? {
        // character_farmer_<facing>_<pose>
        let parts = spec.name.split(separator: "_").map(String.init)
        guard parts.count == 4, parts[0] == "character", parts[1] == "farmer",
              let facing = Facing(rawValue: parts[2]), let pose = Pose(rawValue: parts[3]) else { return nil }
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        let ground = size.height * (1 - CGFloat(spec.anchorY))
        return Canvas.image(size) { ctx in
            draw(ctx, size: size, ground: ground, facing: facing, pose: pose)
        }
    }

    enum Facing: String { case down, up, side }

    enum Pose: String {
        case idle, walk1, walk2, hoe1, hoe2, can1, can2, hands1, hands2, axe1, axe2
    }

    enum Tool { case hoe, can, axe }

    // Palette.
    static let skin = UIColor(hex: 0xF1C9A5)
    static let hair = UIColor(hex: 0x7A4B2A)
    static let straw = UIColor(hex: 0xE6C76E)
    static let band = UIColor(hex: 0xB5553B)
    static let shirt = UIColor(hex: 0xC8553F)
    static let overalls = UIColor(hex: 0x4F6FA3)
    static let boots = UIColor(hex: 0x5A3C28)
    static let ink = UIColor(hex: 0x2E2218).withAlpha(0.6)

    /// Where hands, feet and the tool go for a pose (offsets in design units,
    /// a 100 × 160 box; +x toward the facing side for `side`).
    struct Layout {
        var bob: CGFloat = 0                 // body lowered (bending)
        var leftFoot = CGPoint(x: -10, y: 0)  // (dx, lift)
        var rightFoot = CGPoint(x: 10, y: 0)
        var leftHand = CGPoint(x: -22, y: 36)
        var rightHand = CGPoint(x: 22, y: 36)
        var tool: Tool?
        /// Tool direction from the hand, radians (0 = right, positive = down on screen).
        var toolAngle: CGFloat = 0
        var pouring = false
    }

    static func layout(_ pose: Pose, _ facing: Facing) -> Layout {
        var l = Layout()
        let side = facing == .side
        switch pose {
        case .idle:
            break
        case .walk1, .walk2:
            let sign: CGFloat = pose == .walk1 ? 1 : -1
            if side {
                l.leftFoot = CGPoint(x: -10 * sign, y: 0)
                l.rightFoot = CGPoint(x: 10 * sign, y: 4)
                l.leftHand = CGPoint(x: 10 * sign, y: 34)
                l.rightHand = CGPoint(x: -10 * sign, y: 34)
            } else {
                l.leftFoot = CGPoint(x: -10, y: sign > 0 ? 6 : 0)
                l.rightFoot = CGPoint(x: 10, y: sign > 0 ? 0 : 6)
                l.leftHand = CGPoint(x: -22, y: 32 + 4 * sign)
                l.rightHand = CGPoint(x: 22, y: 32 - 4 * sign)
            }
            l.bob = -2
        case .hoe1:
            l.tool = .hoe
            l.leftHand = CGPoint(x: side ? -4 : 12, y: -10)
            l.rightHand = CGPoint(x: side ? 2 : 18, y: -4)
            l.toolAngle = side ? -2.2 : -1.7
        case .hoe2:
            l.tool = .hoe
            l.bob = 5
            l.leftHand = CGPoint(x: side ? -16 : 8, y: 36)
            l.rightHand = CGPoint(x: side ? -10 : 14, y: 30)
            l.toolAngle = side ? 2.2 : 1.2
        case .can1, .can2:
            l.tool = .can
            l.pouring = pose == .can2
            l.rightHand = CGPoint(x: side ? -18 : 24, y: 30)
            l.leftHand = CGPoint(x: side ? 6 : -20, y: 36)
            l.bob = pose == .can2 ? 3 : 0
        case .hands1:
            l.bob = 10
            l.leftHand = CGPoint(x: side ? -14 : -12, y: 52)
            l.rightHand = CGPoint(x: side ? -6 : 12, y: 52)
        case .hands2:
            l.bob = 16
            l.leftHand = CGPoint(x: side ? -18 : -8, y: 66)
            l.rightHand = CGPoint(x: side ? -10 : 8, y: 66)
            l.leftFoot = CGPoint(x: side ? 6 : -12, y: 0)
            l.rightFoot = CGPoint(x: side ? -8 : 12, y: 0)
        case .axe1:
            l.tool = .axe
            l.leftHand = CGPoint(x: side ? 6 : 14, y: -12)
            l.rightHand = CGPoint(x: side ? 10 : 20, y: -6)
            l.toolAngle = side ? -1.2 : -1.9
        case .axe2:
            l.tool = .axe
            l.bob = 4
            l.leftHand = CGPoint(x: side ? -18 : 6, y: 30)
            l.rightHand = CGPoint(x: side ? -12 : 12, y: 26)
            l.toolAngle = side ? 2.9 : 0.9
        }
        return l
    }

    // MARK: Drawing

    static func draw(_ ctx: CGContext, size: CGSize, ground: CGFloat, facing: Facing, pose: Pose) {
        let s = size.width / 100 * 1.1   // design unit → pixels
        let cx = size.width / 2
        let l = layout(pose, facing)
        let hip = ground - 42 * s + l.bob * s
        let shoulderY = hip - 40 * s
        let headCenter = CGPoint(x: cx + (facing == .side ? -2 * s : 0), y: shoulderY - 22 * s + (l.bob > 8 ? 4 * s : 0))
        let side = facing == .side
        let bodyHalf: CGFloat = (side ? 14 : 20) * s

        // Hands are placed relative to the shoulders; in `side`, negative x is toward the face (left).
        let shoulderL = CGPoint(x: cx - bodyHalf * (side ? 0.3 : 1), y: shoulderY + 4 * s)
        let shoulderR = CGPoint(x: cx + bodyHalf * (side ? 0.3 : 1), y: shoulderY + 4 * s)
        let handL = CGPoint(x: cx + l.leftHand.x * s, y: shoulderY + l.leftHand.y * s)
        let handR = CGPoint(x: cx + l.rightHand.x * s, y: shoulderY + l.rightHand.y * s)

        // Soft contact shadow is drawn by the renderer; here only the figure.

        // Tool behind the body when seen from behind.
        if facing == .up, let tool = l.tool { drawTool(ctx, tool, at: handR, angle: l.toolAngle, pouring: l.pouring, s: s) }

        // Legs and boots.
        for (foot, isLeft) in [(l.leftFoot, true), (l.rightFoot, false)] {
            let top = CGPoint(x: cx + (isLeft ? -8 : 8) * s * (side ? 0.4 : 1), y: hip)
            let bottom = CGPoint(x: cx + foot.x * s, y: ground - foot.y * s - 6 * s)
            let back = side && !isLeft
            Paint.stroke(ctx, from: top, to: bottom, bend: 0, width: 12 * s, color: back ? overalls.shaded(-0.12) : overalls)
            let bootRect = CGRect(x: bottom.x - (side ? 10 : 7) * s, y: bottom.y - 2 * s, width: (side ? 14 : 14) * s, height: 9 * s)
            Paint.fill(ctx, Paint.roundedRect(bootRect, 4 * s), back ? boots.shaded(-0.1) : boots)
        }

        // Far arm (side view) behind the body.
        if side {
            Paint.stroke(ctx, from: shoulderR, to: handR, bend: 0, width: 9 * s, color: shirt.shaded(-0.15))
            Paint.dab(ctx, handR, 4.5 * s, 4.5 * s, skin.shaded(-0.1))
        }

        // Body: shirt, then the overall bib and trousers.
        let torso = Paint.roundedRect(CGRect(x: cx - bodyHalf, y: shoulderY, width: bodyHalf * 2, height: hip - shoulderY + 6 * s), 10 * s)
        Paint.outline(ctx, torso, ink, width: 2 * s)
        Paint.fill(ctx, torso, top: shirt.shaded(0.05), bottom: shirt.shaded(-0.08))
        Paint.clipped(ctx, to: torso) {
            // Checks.
            ctx.setStrokeColor(UIColor(hex: 0xF3D9C8).withAlpha(0.45).cgColor)
            ctx.setLineWidth(1.6 * s)
            var x = cx - bodyHalf + 4 * s
            while x < cx + bodyHalf {
                ctx.move(to: CGPoint(x: x, y: shoulderY)); ctx.addLine(to: CGPoint(x: x, y: hip + 6 * s))
                x += 7 * s
            }
            var y = shoulderY + 4 * s
            while y < hip {
                ctx.move(to: CGPoint(x: cx - bodyHalf, y: y)); ctx.addLine(to: CGPoint(x: cx + bodyHalf, y: y))
                y += 7 * s
            }
            ctx.strokePath()
            // Overalls: bib and trousers top.
            let bibTop = shoulderY + (facing == .up ? 10 : 14) * s
            let bib = CGRect(x: cx - bodyHalf * 0.72, y: bibTop, width: bodyHalf * 1.44, height: hip - bibTop + 8 * s)
            Paint.fill(ctx, Paint.roundedRect(bib, 4 * s), top: overalls.shaded(0.05), bottom: overalls.shaded(-0.06))
            ctx.setFillColor(overalls.cgColor)
            ctx.fill(CGRect(x: cx - bodyHalf, y: hip - 6 * s, width: bodyHalf * 2, height: 14 * s))
            // Straps and buttons.
            ctx.setStrokeColor(overalls.shaded(-0.08).cgColor)
            ctx.setLineWidth(4 * s)
            if facing == .up {
                ctx.move(to: CGPoint(x: cx - bodyHalf * 0.7, y: shoulderY)); ctx.addLine(to: CGPoint(x: cx + bodyHalf * 0.5, y: bibTop + 6 * s))
                ctx.move(to: CGPoint(x: cx + bodyHalf * 0.7, y: shoulderY)); ctx.addLine(to: CGPoint(x: cx - bodyHalf * 0.5, y: bibTop + 6 * s))
            } else {
                ctx.move(to: CGPoint(x: cx - bodyHalf * 0.55, y: shoulderY)); ctx.addLine(to: CGPoint(x: cx - bodyHalf * 0.55, y: bibTop + 2 * s))
                ctx.move(to: CGPoint(x: cx + bodyHalf * 0.55, y: shoulderY)); ctx.addLine(to: CGPoint(x: cx + bodyHalf * 0.55, y: bibTop + 2 * s))
            }
            ctx.strokePath()
            if facing == .down {
                for bx in [cx - bodyHalf * 0.5, cx + bodyHalf * 0.5] {
                    Paint.dab(ctx, CGPoint(x: bx, y: bibTop + 3 * s), 2 * s, 2 * s, UIColor(hex: 0xE8D27A))
                }
                // A little pocket.
                Paint.fill(ctx, Paint.roundedRect(CGRect(x: cx - 7 * s, y: bibTop + 8 * s, width: 14 * s, height: 9 * s), 2 * s),
                           overalls.shaded(-0.1))
            }
        }

        // Arms (near arm on top).
        if !side {
            for (shoulder, hand) in [(shoulderL, handL), (shoulderR, handR)] {
                Paint.stroke(ctx, from: shoulder, to: hand, bend: 0, width: 9 * s, color: shirt.shaded(-0.04))
                Paint.dab(ctx, hand, 4.5 * s, 4.5 * s, skin)
            }
        }

        // Head.
        let headR: CGFloat = 20 * s
        let head = CGPath(ellipseIn: CGRect(x: headCenter.x - headR, y: headCenter.y - headR, width: headR * 2, height: headR * 2), transform: nil)
        Paint.outline(ctx, head, ink, width: 2 * s)
        Paint.fill(ctx, head, top: skin.shaded(0.04), bottom: skin.shaded(-0.06))
        switch facing {
        case .down:
            Paint.clipped(ctx, to: head) {
                // Hair peeking out under the hat.
                Paint.dab(ctx, CGPoint(x: headCenter.x, y: headCenter.y - headR * 0.75), headR * 0.95, headR * 0.35, hair)
            }
            for dx in [-7.5, 7.5] as [CGFloat] {
                Paint.dab(ctx, CGPoint(x: headCenter.x + dx * s, y: headCenter.y + 1 * s), 2.4 * s, 3 * s, UIColor(hex: 0x2A1E16))
                Paint.dab(ctx, CGPoint(x: headCenter.x + dx * s * 1.45, y: headCenter.y + 7 * s), 3.6 * s, 2.4 * s,
                          UIColor(hex: 0xE58C7E).withAlpha(0.5))
            }
            Paint.stroke(ctx, from: CGPoint(x: headCenter.x - 4 * s, y: headCenter.y + 9 * s),
                         to: CGPoint(x: headCenter.x + 4 * s, y: headCenter.y + 9 * s), bend: 0,
                         width: 1.8 * s, color: UIColor(hex: 0x8A4A3A))
        case .up:
            Paint.clipped(ctx, to: head) {
                Paint.dab(ctx, CGPoint(x: headCenter.x, y: headCenter.y + headR * 0.1), headR * 1.05, headR * 0.95, hair)
            }
        case .side:
            Paint.clipped(ctx, to: head) {
                Paint.dab(ctx, CGPoint(x: headCenter.x + headR * 0.45, y: headCenter.y - headR * 0.15), headR * 0.7, headR * 0.85, hair)
            }
            // Nose and eye toward the left.
            Paint.dab(ctx, CGPoint(x: headCenter.x - headR * 0.98, y: headCenter.y + 3 * s), 3 * s, 3.2 * s, skin.shaded(-0.04))
            Paint.dab(ctx, CGPoint(x: headCenter.x - headR * 0.45, y: headCenter.y), 2.3 * s, 3 * s, UIColor(hex: 0x2A1E16))
            Paint.dab(ctx, CGPoint(x: headCenter.x - headR * 0.3, y: headCenter.y + 7 * s), 3.4 * s, 2.2 * s,
                      UIColor(hex: 0xE58C7E).withAlpha(0.5))
        }

        // Straw hat.
        let brimY = headCenter.y - headR * 0.55
        let brim = CGPath(ellipseIn: CGRect(x: headCenter.x - 32 * s + (side ? -4 * s : 0), y: brimY - 8 * s, width: 64 * s, height: 16 * s),
                          transform: nil)
        Paint.outline(ctx, brim, ink, width: 2 * s)
        Paint.fill(ctx, brim, top: straw.shaded(0.08), bottom: straw.shaded(-0.1))
        let crown = Paint.roundedRect(CGRect(x: headCenter.x - 17 * s, y: brimY - 22 * s, width: 34 * s, height: 20 * s), 9 * s)
        Paint.outline(ctx, crown, ink, width: 2 * s)
        Paint.fill(ctx, crown, top: straw.shaded(0.12), bottom: straw.shaded(-0.04))
        ctx.setFillColor(band.cgColor)
        ctx.fill(CGRect(x: headCenter.x - 17 * s, y: brimY - 9 * s, width: 34 * s, height: 5 * s))

        // Near arm (side view) and the tool in front.
        if side {
            Paint.stroke(ctx, from: shoulderL, to: handL, bend: 0, width: 9 * s, color: shirt)
            Paint.dab(ctx, handL, 4.5 * s, 4.5 * s, skin)
        }
        if facing != .up, let tool = l.tool {
            drawTool(ctx, tool, at: side ? handL : handR, angle: l.toolAngle, pouring: l.pouring, s: s)
        }
    }

    static func drawTool(_ ctx: CGContext, _ tool: Tool, at hand: CGPoint, angle: CGFloat, pouring: Bool, s: CGFloat) {
        let wood = UIColor(hex: 0x9A7148)
        let metal = UIColor(hex: 0x8C9196)
        switch tool {
        case .hoe, .axe:
            let length: CGFloat = (tool == .hoe ? 58 : 44) * s
            let tip = CGPoint(x: hand.x + cos(angle) * length, y: hand.y + sin(angle) * length)
            let butt = CGPoint(x: hand.x - cos(angle) * 10 * s, y: hand.y - sin(angle) * 10 * s)
            Paint.stroke(ctx, from: butt, to: tip, bend: 0, width: 4.5 * s, color: wood)
            ctx.saveGState()
            ctx.translateBy(x: tip.x, y: tip.y)
            ctx.rotate(by: angle)
            if tool == .hoe {
                let blade = Paint.polygon([CGPoint(x: -2 * s, y: -2 * s), CGPoint(x: 4 * s, y: -2 * s),
                                           CGPoint(x: 4 * s, y: 16 * s), CGPoint(x: -4 * s, y: 14 * s)])
                Paint.fill(ctx, blade, top: metal.shaded(0.1), bottom: metal.shaded(-0.1))
            } else {
                let head = Paint.polygon([CGPoint(x: -6 * s, y: -12 * s), CGPoint(x: 6 * s, y: -8 * s),
                                          CGPoint(x: 6 * s, y: 8 * s), CGPoint(x: -6 * s, y: 12 * s)])
                Paint.fill(ctx, head, top: metal.shaded(0.12), bottom: metal.shaded(-0.12))
                Paint.outline(ctx, head, ink, width: 1.4 * s)
            }
            ctx.restoreGState()
        case .can:
            ctx.saveGState()
            ctx.translateBy(x: hand.x, y: hand.y + 6 * s)
            ctx.rotate(by: pouring ? -0.55 : 0)
            let body = Paint.roundedRect(CGRect(x: -12 * s, y: -4 * s, width: 24 * s, height: 18 * s), 4 * s)
            Paint.outline(ctx, body, ink, width: 1.6 * s)
            Paint.fill(ctx, body, top: UIColor(hex: 0x6FA35A), bottom: UIColor(hex: 0x4E7E3E))
            Paint.stroke(ctx, from: CGPoint(x: -10 * s, y: 6 * s), to: CGPoint(x: -26 * s, y: -6 * s), bend: 0,
                         width: 3.5 * s, color: UIColor(hex: 0x5E8E4A))
            ctx.restoreGState()
            if pouring {
                for k in 0..<4 {
                    let x = hand.x - 26 * s + CGFloat(k) * 2.5 * s
                    let y = hand.y + 14 * s + CGFloat(k) * 6 * s
                    Paint.dab(ctx, CGPoint(x: x, y: y), 1.8 * s, 3 * s, UIColor(hex: 0x8CC4DA))
                }
            }
        }
    }
}
