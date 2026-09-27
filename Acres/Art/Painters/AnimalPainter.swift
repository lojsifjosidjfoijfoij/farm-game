import UIKit
import AcresCore

/// Farm animals in five poses (idle, walk1, walk2, eat, sleep), drawn facing
/// left; the renderer mirrors them to face right. Four-legged animals share
/// one parametric body, birds another.
enum AnimalPainter {

    static func paint(_ spec: AssetSpec, rng: inout SeededRandom) -> UIImage? {
        // animal_<kind>_<pose>, where kind may contain an underscore (sheep_sheared).
        guard spec.name.hasPrefix("animal_"), let split = spec.name.lastIndex(of: "_") else { return nil }
        let kind = String(spec.name[spec.name.index(spec.name.startIndex, offsetBy: 7)..<split])
        guard let pose = Pose(rawValue: String(spec.name[spec.name.index(after: split)...])) else { return nil }
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        let ground = size.height * (1 - CGFloat(spec.anchorY))
        switch kind {
        case "chicken": return bird(size, ground: ground, pose: pose, chick: false, rng: &rng)
        case "chick": return bird(size, ground: ground, pose: pose, chick: true, rng: &rng)
        default:
            guard let look = looks[kind] else { return nil }
            return quadruped(size, ground: ground, pose: pose, look: look, rng: &rng)
        }
    }

    enum Pose: String {
        case idle, walk1, walk2, eat, sleep
    }

    static let ink = UIColor(hex: 0x2E2218).withAlpha(0.55)

    // MARK: Four legs

    enum Ears { case cow, floppy, pointed }
    enum Tail { case tuft, curl, stub }

    struct Look {
        var body: UIColor
        var spots: UIColor?
        var head: UIColor
        var snout: UIColor
        var legs: UIColor
        var hoof: UIColor
        /// Body size as a fraction of the canvas.
        var bodyWidth: CGFloat
        var bodyHeight: CGFloat
        /// Leg length as a fraction of the canvas height.
        var legLength: CGFloat
        /// Head radius as a fraction of the canvas width.
        var headSize: CGFloat
        var ears: Ears
        var tail: Tail
        var woolly = false
        var horns = false
        var roundSnout = false
    }

    static let looks: [String: Look] = {
        let cowBody = UIColor(hex: 0xF1ECE2), cowSpots = UIColor(hex: 0x6B4A33)
        let pig = UIColor(hex: 0xEDB3A8)
        let wool = UIColor(hex: 0xF0E8D6), sheepFace = UIColor(hex: 0x4E4640)
        return [
            "cow": Look(body: cowBody, spots: cowSpots, head: cowBody, snout: UIColor(hex: 0xE9A99A), legs: cowBody.shaded(-0.08),
                        hoof: UIColor(hex: 0x4A3A30), bodyWidth: 0.64, bodyHeight: 0.4, legLength: 0.3, headSize: 0.14,
                        ears: .cow, tail: .tuft, horns: true),
            "calf": Look(body: UIColor(hex: 0xC99E74), spots: UIColor(hex: 0xF3EDE3), head: UIColor(hex: 0xC99E74),
                         snout: UIColor(hex: 0xE3A596), legs: UIColor(hex: 0xB88C63), hoof: UIColor(hex: 0x4A3A30),
                         bodyWidth: 0.58, bodyHeight: 0.36, legLength: 0.34, headSize: 0.17, ears: .cow, tail: .tuft),
            "sheep": Look(body: wool, spots: nil, head: sheepFace, snout: sheepFace.shaded(0.08), legs: sheepFace,
                          hoof: UIColor(hex: 0x2E2824), bodyWidth: 0.68, bodyHeight: 0.5, legLength: 0.24, headSize: 0.13,
                          ears: .floppy, tail: .stub, woolly: true),
            "sheep_sheared": Look(body: UIColor(hex: 0xE6DCC8), spots: nil, head: sheepFace, snout: sheepFace.shaded(0.08),
                                  legs: sheepFace, hoof: UIColor(hex: 0x2E2824), bodyWidth: 0.6, bodyHeight: 0.38,
                                  legLength: 0.28, headSize: 0.14, ears: .floppy, tail: .stub),
            "lamb": Look(body: UIColor(hex: 0xF7F2E6), spots: nil, head: UIColor(hex: 0xEDE3D0), snout: UIColor(hex: 0xE8B7AA),
                         legs: UIColor(hex: 0xE3D8C4), hoof: UIColor(hex: 0x6A5A50), bodyWidth: 0.62, bodyHeight: 0.44,
                         legLength: 0.28, headSize: 0.17, ears: .floppy, tail: .stub, woolly: true),
            "pig": Look(body: pig, spots: UIColor(hex: 0x8A6A52).withAlpha(0.45), head: pig, snout: UIColor(hex: 0xE39A90),
                        legs: pig.shaded(-0.06), hoof: UIColor(hex: 0x8C5E54), bodyWidth: 0.7, bodyHeight: 0.46,
                        legLength: 0.18, headSize: 0.16, ears: .pointed, tail: .curl, roundSnout: true),
            "piglet": Look(body: UIColor(hex: 0xF4C2B8), spots: nil, head: UIColor(hex: 0xF4C2B8), snout: UIColor(hex: 0xE9A298),
                           legs: UIColor(hex: 0xEAB5AA), hoof: UIColor(hex: 0x9C6A5E), bodyWidth: 0.64, bodyHeight: 0.44,
                           legLength: 0.2, headSize: 0.2, ears: .pointed, tail: .curl, roundSnout: true),
        ]
    }()

    static func quadruped(_ size: CGSize, ground: CGFloat, pose: Pose, look: Look, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        let lying = pose == .sleep
        let bodyRX = w * look.bodyWidth / 2
        let bodyRY = h * look.bodyHeight / 2
        let legLength = lying ? 0 : h * look.legLength
        let bodyCenter = CGPoint(x: w * 0.56, y: ground - legLength - bodyRY * (lying ? 0.85 : 0.9))
        let headR = w * look.headSize
        let headCenter: CGPoint = switch pose {
        case .eat: CGPoint(x: bodyCenter.x - bodyRX * 0.95, y: ground - headR * 0.9)
        case .sleep: CGPoint(x: bodyCenter.x - bodyRX * 0.95, y: bodyCenter.y + bodyRY * 0.1)
        default: CGPoint(x: bodyCenter.x - bodyRX * 1.0, y: bodyCenter.y - bodyRY * 0.75)
        }

        return Canvas.image(size) { ctx in
            // Legs: far pair first (darker), then the near pair.
            if !lying {
                let swing: CGFloat = pose == .walk1 ? 1 : (pose == .walk2 ? -1 : 0)
                let legWidth = max(3, w * 0.07)
                let hipY = bodyCenter.y + bodyRY * 0.4
                let legXs: [(CGFloat, Bool, CGFloat)] = [
                    (bodyCenter.x - bodyRX * 0.55, false, swing), (bodyCenter.x + bodyRX * 0.55, false, -swing),
                    (bodyCenter.x - bodyRX * 0.35, true, -swing), (bodyCenter.x + bodyRX * 0.75, true, swing),
                ]
                for (x, near, s) in legXs {
                    let foot = CGPoint(x: x + s * w * 0.05, y: ground)
                    let color = near ? look.legs : look.legs.shaded(-0.14)
                    Paint.stroke(ctx, from: CGPoint(x: x, y: hipY), to: foot, bend: 0, width: legWidth, color: color)
                    Paint.dab(ctx, CGPoint(x: foot.x, y: foot.y - legWidth * 0.3), legWidth * 0.55, legWidth * 0.4, look.hoof)
                }
            }

            // Tail (behind the body, on the right).
            let tailRoot = CGPoint(x: bodyCenter.x + bodyRX * 0.95, y: bodyCenter.y - bodyRY * 0.3)
            switch look.tail {
            case .tuft:
                let tip = CGPoint(x: tailRoot.x + w * 0.04, y: tailRoot.y + h * 0.28)
                Paint.stroke(ctx, from: tailRoot, to: tip, bend: w * 0.03, width: max(2, w * 0.02), color: look.body.shaded(-0.2))
                Paint.dab(ctx, tip, w * 0.025, h * 0.05, look.spots ?? look.body.shaded(-0.3))
            case .curl:
                ctx.setStrokeColor(look.body.shaded(-0.1).cgColor)
                ctx.setLineWidth(max(2, w * 0.022))
                ctx.addPath(CGPath(ellipseIn: CGRect(x: tailRoot.x, y: tailRoot.y - h * 0.06, width: w * 0.07, height: h * 0.08), transform: nil))
                ctx.strokePath()
            case .stub:
                Paint.dab(ctx, CGPoint(x: tailRoot.x + w * 0.02, y: tailRoot.y), w * 0.045, h * 0.05, look.body.shaded(-0.05))
            }

            // Body.
            let bodyPath: CGPath = look.woolly
                ? Paint.blobPath(bodyCenter, rx: bodyRX, ry: bodyRY, lumps: 14, lumpiness: 0.07, rng: &rng)
                : CGPath(ellipseIn: CGRect(x: bodyCenter.x - bodyRX, y: bodyCenter.y - bodyRY, width: bodyRX * 2, height: bodyRY * 2), transform: nil)
            Paint.outline(ctx, bodyPath, ink, width: max(2, w * 0.015))
            Paint.fill(ctx, bodyPath, top: look.body.shaded(0.05), bottom: look.body.shaded(-0.12))
            Paint.clipped(ctx, to: bodyPath) {
                if look.woolly {
                    for _ in 0..<40 {
                        let p = rng.point(in: bodyPath.boundingBoxOfPath)
                        let r = rng.cg((w * 0.03)...(w * 0.06))
                        Paint.dab(ctx, p, r, r * 0.85, look.body.shaded(rng.cg(-0.1...0.06)).withAlpha(0.8))
                    }
                }
                if let spots = look.spots {
                    for _ in 0..<(look.woolly ? 0 : 4) {
                        let p = rng.point(in: bodyPath.boundingBoxOfPath.insetBy(dx: bodyRX * 0.2, dy: bodyRY * 0.2))
                        let blob = Paint.blobPath(p, rx: rng.cg((w * 0.05)...(w * 0.11)), ry: rng.cg((h * 0.05)...(h * 0.1)),
                                                  lumps: 7, lumpiness: 0.25, rng: &rng)
                        Paint.fill(ctx, blob, spots)
                    }
                }
                // Soft belly shadow.
                ctx.drawLinearGradient(Paint.gradient([UIColor.black.withAlpha(0), UIColor.black.withAlpha(0.14)]),
                                       start: CGPoint(x: 0, y: bodyCenter.y), end: CGPoint(x: 0, y: bodyCenter.y + bodyRY), options: [])
            }

            head(ctx, center: headCenter, radius: headR, look: look, pose: pose, w: w, h: h)
        }
    }

    private static func head(_ ctx: CGContext, center: CGPoint, radius r: CGFloat, look: Look, pose: Pose, w: CGFloat, h: CGFloat) {
        let lying = pose == .sleep
        // Ears behind the head.
        switch look.ears {
        case .cow:
            Paint.dab(ctx, CGPoint(x: center.x + r * 0.85, y: center.y - r * 0.55), r * 0.5, r * 0.22, look.head.shaded(-0.1), rotation: -0.4)
            Paint.dab(ctx, CGPoint(x: center.x - r * 0.3, y: center.y - r * 0.85), r * 0.45, r * 0.2, look.head.shaded(-0.15), rotation: 0.6)
        case .floppy:
            Paint.dab(ctx, CGPoint(x: center.x + r * 0.8, y: center.y - r * 0.2), r * 0.55, r * 0.22, look.head.shaded(-0.12), rotation: 0.5)
        case .pointed:
            let ear = Paint.polygon([CGPoint(x: center.x + r * 0.1, y: center.y - r * 0.7), CGPoint(x: center.x + r * 0.75, y: center.y - r * 0.55),
                                     CGPoint(x: center.x + r * 0.55, y: center.y - r * 1.25)])
            Paint.fill(ctx, ear, look.head.shaded(-0.1))
        }
        if look.horns {
            Paint.stroke(ctx, from: CGPoint(x: center.x + r * 0.2, y: center.y - r * 0.8), to: CGPoint(x: center.x + r * 0.5, y: center.y - r * 1.3),
                         bend: r * 0.2, width: max(2, r * 0.18), color: UIColor(hex: 0xE8DCC0))
        }
        // Head: a rounded shape stretched toward the snout (left).
        let headPath = CGPath(ellipseIn: CGRect(x: center.x - r * 1.05, y: center.y - r * 0.85, width: r * 2, height: r * 1.7), transform: nil)
        Paint.outline(ctx, headPath, ink, width: max(2, w * 0.014))
        Paint.fill(ctx, headPath, top: look.head.shaded(0.05), bottom: look.head.shaded(-0.1))
        // Snout.
        let snoutCenter = CGPoint(x: center.x - r * 0.85, y: center.y + r * 0.25)
        if look.roundSnout {
            let disc = CGPath(ellipseIn: CGRect(x: snoutCenter.x - r * 0.4, y: snoutCenter.y - r * 0.32, width: r * 0.7, height: r * 0.64), transform: nil)
            Paint.outline(ctx, disc, ink, width: 1.5)
            Paint.fill(ctx, disc, look.snout)
            Paint.dab(ctx, CGPoint(x: snoutCenter.x - r * 0.15, y: snoutCenter.y), r * 0.06, r * 0.1, look.snout.shaded(-0.35))
            Paint.dab(ctx, CGPoint(x: snoutCenter.x + r * 0.08, y: snoutCenter.y), r * 0.06, r * 0.1, look.snout.shaded(-0.35))
        } else {
            Paint.dab(ctx, snoutCenter, r * 0.45, r * 0.38, look.snout)
            Paint.dab(ctx, CGPoint(x: snoutCenter.x - r * 0.18, y: snoutCenter.y - r * 0.05), r * 0.06, r * 0.08, look.snout.shaded(-0.4))
        }
        // Eye: open dot, or a sleepy arc.
        let eye = CGPoint(x: center.x - r * 0.3, y: center.y - r * 0.2)
        if lying {
            Paint.stroke(ctx, from: CGPoint(x: eye.x - r * 0.14, y: eye.y), to: CGPoint(x: eye.x + r * 0.14, y: eye.y), bend: 0,
                         width: max(1.5, r * 0.08), color: UIColor(hex: 0x2A1E16))
        } else {
            Paint.dab(ctx, eye, max(2, r * 0.13), max(2, r * 0.15), UIColor(hex: 0x1E1612))
            Paint.dab(ctx, CGPoint(x: eye.x - r * 0.04, y: eye.y - r * 0.05), max(1, r * 0.04), max(1, r * 0.04), UIColor.white.withAlpha(0.9))
        }
        // A rosy cheek for charm.
        Paint.softSpot(ctx, CGPoint(x: center.x - r * 0.05, y: center.y + r * 0.3), r * 0.3, UIColor(hex: 0xE58C7E).withAlpha(0.35))
    }

    // MARK: Birds

    static func bird(_ size: CGSize, ground: CGFloat, pose: Pose, chick: Bool, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        let feathers = chick ? UIColor(hex: 0xF6D55C) : UIColor(hex: 0xB4693A)
        let lying = pose == .sleep
        let legLength = lying ? 0 : h * (chick ? 0.14 : 0.2)
        let bodyRX = w * (chick ? 0.3 : 0.32)
        let bodyRY = h * (chick ? 0.28 : 0.25)
        let bodyCenter = CGPoint(x: w * 0.54, y: ground - legLength - bodyRY * 0.85)
        let headR = w * (chick ? 0.17 : 0.13)
        let headCenter: CGPoint = switch pose {
        case .eat: CGPoint(x: bodyCenter.x - bodyRX * 0.95, y: ground - headR * 1.1)
        case .sleep: CGPoint(x: bodyCenter.x - bodyRX * 0.55, y: bodyCenter.y - bodyRY * 0.55)
        default: CGPoint(x: bodyCenter.x - bodyRX * 0.75, y: bodyCenter.y - bodyRY * 1.05)
        }

        return Canvas.image(size) { ctx in
            if !lying {
                let swing: CGFloat = pose == .walk1 ? 1 : (pose == .walk2 ? -1 : 0)
                let legColor = UIColor(hex: 0xE39A3B)
                for (dx, s) in [(-0.12, swing), (0.1, -swing)] as [(CGFloat, CGFloat)] {
                    let hip = CGPoint(x: bodyCenter.x + bodyRX * dx, y: bodyCenter.y + bodyRY * 0.7)
                    let foot = CGPoint(x: hip.x + s * w * 0.06, y: ground)
                    Paint.stroke(ctx, from: hip, to: foot, bend: 0, width: max(2, w * 0.035), color: legColor)
                    Paint.stroke(ctx, from: foot, to: CGPoint(x: foot.x - w * 0.07, y: foot.y), bend: 0, width: max(2, w * 0.03), color: legColor)
                }
            }
            // Tail feathers up at the back (hens only).
            if !chick {
                let tail = Paint.polygon([CGPoint(x: bodyCenter.x + bodyRX * 0.6, y: bodyCenter.y - bodyRY * 0.2),
                                          CGPoint(x: bodyCenter.x + bodyRX * 1.25, y: bodyCenter.y - bodyRY * 1.3),
                                          CGPoint(x: bodyCenter.x + bodyRX * 1.05, y: bodyCenter.y + bodyRY * 0.2)])
                Paint.outline(ctx, tail, ink, width: 2)
                Paint.fill(ctx, tail, top: UIColor(hex: 0x6E3A22), bottom: feathers.shaded(-0.1))
            }
            let body = CGPath(ellipseIn: CGRect(x: bodyCenter.x - bodyRX, y: bodyCenter.y - bodyRY, width: bodyRX * 2, height: bodyRY * 2), transform: nil)
            Paint.outline(ctx, body, ink, width: 2)
            Paint.fill(ctx, body, top: feathers.shaded(0.08), bottom: feathers.shaded(-0.12))
            Paint.clipped(ctx, to: body) {
                for _ in 0..<14 {
                    let p = rng.point(in: body.boundingBoxOfPath)
                    Paint.dab(ctx, p, w * 0.04, h * 0.025, feathers.shaded(rng.cg(-0.12...0.1)).withAlpha(0.7), rotation: rng.cg(0...0.6))
                }
            }
            // Wing.
            Paint.dab(ctx, CGPoint(x: bodyCenter.x + bodyRX * 0.15, y: bodyCenter.y + bodyRY * 0.05), bodyRX * 0.55, bodyRY * 0.45,
                      feathers.shaded(-0.1), rotation: 0.25)

            // Head with beak, comb and eye.
            if !chick {
                Paint.dab(ctx, CGPoint(x: headCenter.x + headR * 0.1, y: headCenter.y - headR * 0.9), headR * 0.45, headR * 0.3, UIColor(hex: 0xD2412F))
                Paint.dab(ctx, CGPoint(x: headCenter.x - headR * 0.55, y: headCenter.y + headR * 0.7), headR * 0.2, headR * 0.3, UIColor(hex: 0xD2412F))
            }
            let headPath = CGPath(ellipseIn: CGRect(x: headCenter.x - headR, y: headCenter.y - headR, width: headR * 2, height: headR * 2), transform: nil)
            Paint.outline(ctx, headPath, ink, width: 2)
            Paint.fill(ctx, headPath, top: feathers.shaded(0.1), bottom: feathers.shaded(-0.04))
            let beakTip = CGPoint(x: headCenter.x - headR * 1.55, y: headCenter.y + headR * (pose == .eat ? 0.6 : 0.2))
            Paint.fill(ctx, Paint.polygon([CGPoint(x: headCenter.x - headR * 0.8, y: headCenter.y - headR * 0.2), beakTip,
                                           CGPoint(x: headCenter.x - headR * 0.8, y: headCenter.y + headR * 0.4)]), UIColor(hex: 0xE8A33A))
            let eye = CGPoint(x: headCenter.x - headR * 0.3, y: headCenter.y - headR * 0.15)
            if lying {
                Paint.stroke(ctx, from: CGPoint(x: eye.x - headR * 0.2, y: eye.y), to: CGPoint(x: eye.x + headR * 0.2, y: eye.y), bend: 0,
                             width: 1.5, color: UIColor(hex: 0x2A1E16))
            } else {
                Paint.dab(ctx, eye, max(1.5, headR * 0.16), max(1.5, headR * 0.18), UIColor(hex: 0x1E1612))
            }
        }
    }
}
