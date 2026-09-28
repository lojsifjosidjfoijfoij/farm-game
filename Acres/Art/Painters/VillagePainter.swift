import UIKit
import AcresCore

/// The village: houses, shops, the market stall, gas station and street props.
/// Buildings share one cottage layout so their night-light overlays line up.
enum VillagePainter {

    static func paint(_ spec: AssetSpec, rng: inout SeededRandom) -> UIImage? {
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        let ground = size.height * (1 - CGFloat(spec.anchorY))
        let lights = spec.name.hasSuffix("_lights")
        let base = lights ? String(spec.name.dropLast("_lights".count)) : spec.name
        if let style = cottageStyles[base] {
            return lights ? cottageLights(size, style) : cottage(size, style, rng: &rng)
        }
        switch spec.name {
        case "building_farmers_market_stall": return marketStall(size, ground: ground, rng: &rng)
        case "prop_market_goods": return marketGoods(size, ground: ground, rng: &rng)
        case "prop_gas_pump": return gasPump(size, ground: ground)
        case "prop_lamp_post": return lampPost(size, ground: ground)
        case "prop_lamp_post_lights": return lampLight(size)
        case "prop_bench": return bench(size, ground: ground)
        case "prop_signpost": return signpost(size, ground: ground)
        case "prop_for_rent_sign": return forRentSign(size, ground: ground)
        case "prop_open_sign": return openSign(size, ground: ground)
        default: return nil
        }
    }

    // MARK: Cottages and shops

    struct CottageStyle {
        var wall: UIColor
        var roof: UIColor
        var door: UIColor
        var trim = UIColor(hex: 0xEDE6D6)
        var sign: String?
        var signColor = UIColor(hex: 0x3F6B3A)
        var awning: UIColor?
        /// Part of the width (from the left) given to a gas-station canopy.
        var canopy: CGFloat = 0
        /// Part of the width (from the left) given to stacked timber (lumber yard).
        var timberYard: CGFloat = 0
        /// Stone pillars beside the door (the bank).
        var columns = false

        var sideYard: CGFloat { max(canopy, timberYard) }
    }

    static let cottageStyles: [String: CottageStyle] = [
        "building_house_village_a": CottageStyle(wall: UIColor(hex: 0xE3D5B4), roof: UIColor(hex: 0xA2493A), door: UIColor(hex: 0x6E4A30)),
        "building_house_village_b": CottageStyle(wall: UIColor(hex: 0xD9DCD6), roof: UIColor(hex: 0x5E6670), door: UIColor(hex: 0x3F5E7A)),
        "building_house_village_c": CottageStyle(wall: UIColor(hex: 0xE8C9A4), roof: UIColor(hex: 0x7A5A3A), door: UIColor(hex: 0x5E7A45)),
        "building_seed_shop": CottageStyle(wall: UIColor(hex: 0xEDE2C4), roof: UIColor(hex: 0x6F8F4A), door: UIColor(hex: 0x5A4030),
                                           sign: "SEEDS", signColor: UIColor(hex: 0x4E7A36), awning: UIColor(hex: 0x6F9E48)),
        "building_gas_station": CottageStyle(wall: UIColor(hex: 0xEFEDE6), roof: UIColor(hex: 0x8C8F92), door: UIColor(hex: 0x4A5560),
                                             sign: "GAS", signColor: UIColor(hex: 0xB8432F), awning: nil, canopy: 0.5),
        // Phase 6: the bank and the clients that take deliveries.
        "building_bank": CottageStyle(wall: UIColor(hex: 0xD6D2C8), roof: UIColor(hex: 0x4F5A66), door: UIColor(hex: 0x3A4A5E),
                                      trim: UIColor(hex: 0xF2EEE4), sign: "BANK", signColor: UIColor(hex: 0x2F4F7A), columns: true),
        "building_bakery": CottageStyle(wall: UIColor(hex: 0xC98A6A), roof: UIColor(hex: 0x7A3E2E), door: UIColor(hex: 0x6E4A30),
                                        sign: "BAKERY", signColor: UIColor(hex: 0x8A4B2A), awning: UIColor(hex: 0xE0A25A)),
        "building_restaurant": CottageStyle(wall: UIColor(hex: 0xF0E0C0), roof: UIColor(hex: 0xB8432F), door: UIColor(hex: 0x3F5E7A),
                                            sign: "DINER", signColor: UIColor(hex: 0xB8432F), awning: UIColor(hex: 0xC8453A)),
        // Phase 7: the corner shop the farmer can rent.
        "building_town_shop": CottageStyle(wall: UIColor(hex: 0xF2E6CC), roof: UIColor(hex: 0x3F6B8A), door: UIColor(hex: 0x5E4030),
                                           sign: "SHOP", signColor: UIColor(hex: 0x2F5A7A), awning: UIColor(hex: 0x4F86B0)),
        "building_deli": CottageStyle(wall: UIColor(hex: 0xEFE3C8), roof: UIColor(hex: 0x6E4A6E), door: UIColor(hex: 0x4A3A2A),
                                      sign: "DELI", signColor: UIColor(hex: 0x6E3A5E), awning: UIColor(hex: 0x8A5A8A)),
        "building_lumber_yard": CottageStyle(wall: UIColor(hex: 0xB08A5E), roof: UIColor(hex: 0x5A4A3A), door: UIColor(hex: 0x4A3A2A),
                                             sign: "LUMBER", signColor: UIColor(hex: 0x5A3E22), timberYard: 0.36),
    ]

    /// Layout in unit coordinates (top-left origin) of the building part.
    struct CottageLayout {
        let wall: CGRect
        let door: CGRect
        let windows: [CGRect]
        let sign: CGRect

        init(size: CGSize, style: CottageStyle) {
            let w = size.width, h = size.height
            let left = w * (style.sideYard > 0 ? style.sideYard + 0.04 : 0.14)
            let right = w * 0.86
            let top = h * 0.58, bottom = h * 0.94
            wall = CGRect(x: left, y: top, width: right - left, height: bottom - top)
            let ww = wall.width
            door = CGRect(x: wall.midX - ww * 0.09, y: bottom - h * 0.2, width: ww * 0.18, height: h * 0.2)
            windows = [
                CGRect(x: wall.minX + ww * 0.1, y: top + h * 0.1, width: ww * 0.2, height: h * 0.12),
                CGRect(x: wall.maxX - ww * 0.3, y: top + h * 0.1, width: ww * 0.2, height: h * 0.12),
            ]
            sign = CGRect(x: wall.midX - ww * 0.22, y: top + h * 0.015, width: ww * 0.44, height: h * 0.07)
        }
    }

    static func cottage(_ size: CGSize, _ style: CottageStyle, rng: inout SeededRandom) -> UIImage {
        let layout = CottageLayout(size: size, style: style)
        let wall = layout.wall
        let h = size.height
        let ink = UIColor(hex: 0x2E2419).withAlpha(0.5)
        return Canvas.image(size) { ctx in
            if style.canopy > 0 {
                canopy(ctx, size: size, width: style.canopy)
            }
            if style.timberYard > 0 {
                timberStacks(ctx, size: size, width: style.timberYard, rng: &rng)
            }
            // Roof seen from above: front slope, a thin back slope, a chimney for homes.
            let eave = wall.minY + 3
            let ridge = h * 0.33
            let back = Paint.polygon([
                CGPoint(x: wall.minX + 12, y: ridge), CGPoint(x: wall.maxX - 12, y: ridge),
                CGPoint(x: wall.maxX - 20, y: ridge - h * 0.07), CGPoint(x: wall.minX + 20, y: ridge - h * 0.07),
            ])
            let front = Paint.polygon([
                CGPoint(x: wall.minX - 16, y: eave), CGPoint(x: wall.maxX + 16, y: eave),
                CGPoint(x: wall.maxX - 12, y: ridge), CGPoint(x: wall.minX + 12, y: ridge),
            ])
            if style.sign == nil {
                let chimney = CGRect(x: wall.maxX - wall.width * 0.28, y: ridge - h * 0.13, width: wall.width * 0.08, height: h * 0.13)
                Paint.fill(ctx, Paint.roundedRect(chimney, 2), top: UIColor(hex: 0x9C6A52), bottom: UIColor(hex: 0x7A4E3C))
            }
            Paint.outline(ctx, back, ink, width: 2.5)
            Paint.fill(ctx, back, top: style.roof.shaded(-0.15), bottom: style.roof.shaded(-0.1))
            Paint.outline(ctx, front, ink, width: 2.5)
            Paint.fill(ctx, front, top: style.roof.shaded(0.04), bottom: style.roof.shaded(-0.08))
            Paint.clipped(ctx, to: front) {
                ctx.setStrokeColor(style.roof.shaded(-0.22).withAlpha(0.5).cgColor)
                ctx.setLineWidth(2)
                var y = ridge + 10
                while y < eave {
                    ctx.move(to: CGPoint(x: wall.minX - 20, y: y)); ctx.addLine(to: CGPoint(x: wall.maxX + 20, y: y))
                    y += 13
                }
                ctx.strokePath()
                Paint.softSpot(ctx, CGPoint(x: wall.minX, y: ridge), wall.width * 0.5, UIColor(hex: 0xFFF1D6).withAlpha(0.2))
            }

            // Walls.
            let wallPath = Paint.roundedRect(wall, 2)
            Paint.outline(ctx, wallPath, ink, width: 2.5)
            Paint.fill(ctx, wallPath, top: style.wall.shaded(0.02), bottom: style.wall.shaded(-0.08))
            Paint.clipped(ctx, to: wallPath) {
                ctx.drawLinearGradient(Paint.gradient([UIColor.black.withAlpha(0.25), UIColor.black.withAlpha(0)]),
                                       start: CGPoint(x: 0, y: wall.minY), end: CGPoint(x: 0, y: wall.minY + 20), options: [])
                for _ in 0..<20 {
                    Paint.dab(ctx, rng.point(in: wall), rng.cg(3...8), rng.cg(2...4), style.wall.shaded(-0.1).withAlpha(0.3))
                }
            }
            ctx.setFillColor(UIColor(hex: 0x8A857C).cgColor)
            ctx.fill(CGRect(x: wall.minX - 3, y: wall.maxY - 9, width: wall.width + 6, height: 10))

            // Windows, door, awning and sign.
            for window in layout.windows { windowShape(ctx, window, trim: style.trim) }
            if style.columns {
                for x in [layout.door.minX - wall.width * 0.1, layout.door.maxX + wall.width * 0.04] {
                    let pillar = CGRect(x: x, y: wall.minY + h * 0.05, width: wall.width * 0.06, height: wall.maxY - wall.minY - h * 0.05 - 8)
                    Paint.fillHorizontal(ctx, Paint.roundedRect(pillar, 2), left: style.trim, right: style.wall.shaded(-0.12))
                    Paint.outline(ctx, Paint.roundedRect(pillar, 2), ink, width: 1.5)
                    let capital = CGRect(x: pillar.minX - 3, y: pillar.minY - 4, width: pillar.width + 6, height: 6)
                    Paint.fill(ctx, Paint.roundedRect(capital, 1.5), style.trim)
                }
            }
            let door = Paint.roundedRect(layout.door, 3)
            Paint.fill(ctx, door, top: style.door.shaded(0.05), bottom: style.door.shaded(-0.1))
            Paint.outline(ctx, door, style.trim, width: 4)
            Paint.dab(ctx, CGPoint(x: layout.door.maxX - 8, y: layout.door.midY + 5), 2.5, 2.5, UIColor(hex: 0xD8B25A))
            if let awning = style.awning {
                let top = layout.door.minY - h * 0.06
                let shape = Paint.polygon([
                    CGPoint(x: wall.minX + 6, y: top), CGPoint(x: wall.maxX - 6, y: top),
                    CGPoint(x: wall.maxX + 4, y: top + h * 0.06), CGPoint(x: wall.minX - 4, y: top + h * 0.06),
                ])
                Paint.fill(ctx, shape, awning)
                Paint.clipped(ctx, to: shape) {
                    var x = wall.minX - 4
                    var stripe = false
                    while x < wall.maxX + 10 {
                        if stripe {
                            ctx.setFillColor(UIColor.white.withAlpha(0.85).cgColor)
                            ctx.fill(CGRect(x: x, y: top, width: 14, height: h * 0.07))
                        }
                        stripe.toggle()
                        x += 14
                    }
                }
                Paint.outline(ctx, shape, ink, width: 2)
            }
            if let text = style.sign {
                let board = Paint.roundedRect(layout.sign, 4)
                Paint.fill(ctx, board, UIColor(hex: 0xF4ECD8))
                Paint.outline(ctx, board, style.signColor, width: 3)
                label(text, in: layout.sign.insetBy(dx: 4, dy: 2), color: style.signColor)
            }
        }
    }

    static func cottageLights(_ size: CGSize, _ style: CottageStyle) -> UIImage {
        let layout = CottageLayout(size: size, style: style)
        return Canvas.image(size) { ctx in
            let warm = UIColor(hex: 0xFFC766)
            for window in layout.windows {
                Paint.softSpot(ctx, CGPoint(x: window.midX, y: window.midY), window.width * 1.2, warm.withAlpha(0.35))
                ctx.setFillColor(warm.withAlpha(0.85).cgColor)
                ctx.fill(window.insetBy(dx: 3, dy: 3))
            }
            if style.sign != nil {
                Paint.softSpot(ctx, CGPoint(x: layout.sign.midX, y: layout.sign.midY), layout.sign.width * 0.7, warm.withAlpha(0.25))
            }
        }
    }

    /// Timber stacked on the left of the canvas: sawn planks on top of log ends.
    static func timberStacks(_ ctx: CGContext, size: CGSize, width fraction: CGFloat, rng: inout SeededRandom) {
        let w = size.width, h = size.height
        let ground = h * 0.94
        let area = CGRect(x: w * 0.03, y: h * 0.6, width: w * (fraction - 0.03), height: ground - h * 0.6)
        let bark = UIColor(hex: 0x6E4B2E), wood = UIColor(hex: 0xE2C08A), ink = UIColor(hex: 0x2E2419).withAlpha(0.5)
        Paint.dab(ctx, CGPoint(x: area.midX, y: ground - 2), area.width * 0.55, 7, UIColor.black.withAlpha(0.18))
        // Three rows of log ends, fewer on each row up.
        let radius = area.width / 9
        for row in 0..<3 {
            let count = 4 - row
            let y = ground - radius * (1 + CGFloat(row) * 1.75)
            let start = area.midX - CGFloat(count - 1) * radius
            for i in 0..<count {
                let center = CGPoint(x: start + CGFloat(i) * radius * 2 + rng.cg(-1.5...1.5), y: y)
                let end = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                ctx.setFillColor(bark.cgColor)
                ctx.fillEllipse(in: end)
                ctx.setFillColor(wood.cgColor)
                ctx.fillEllipse(in: end.insetBy(dx: radius * 0.22, dy: radius * 0.22))
                ctx.setStrokeColor(bark.withAlpha(0.45).cgColor)
                ctx.setLineWidth(1.2)
                ctx.strokeEllipse(in: end.insetBy(dx: radius * 0.5, dy: radius * 0.5))
                ctx.setStrokeColor(ink.cgColor)
                ctx.setLineWidth(1.5)
                ctx.strokeEllipse(in: end)
            }
        }
        // A stack of planks on top.
        let top = ground - radius * 5.5 - 7
        for i in 0..<3 {
            let plank = CGRect(x: area.minX + area.width * 0.12 + CGFloat(i) * 2, y: top - CGFloat(i) * 7,
                               width: area.width * 0.76, height: 7)
            Paint.fill(ctx, Paint.roundedRect(plank, 1.5), top: wood.shaded(0.05), bottom: wood.shaded(-0.12))
            Paint.outline(ctx, Paint.roundedRect(plank, 1.5), ink, width: 1.2)
        }
    }

    /// A gas-station canopy on the left of the canvas, seen from above, on two posts.
    static func canopy(_ ctx: CGContext, size: CGSize, width fraction: CGFloat) {
        let w = size.width, h = size.height
        let roof = CGRect(x: w * 0.03, y: h * 0.24, width: w * (fraction - 0.03), height: h * 0.2)
        for x in [roof.minX + roof.width * 0.15, roof.maxX - roof.width * 0.15] {
            let post = CGRect(x: x - 5, y: roof.maxY - 4, width: 10, height: h * 0.94 - roof.maxY + 4)
            Paint.fillHorizontal(ctx, Paint.roundedRect(post, 2), left: UIColor(hex: 0xD8D8D2), right: UIColor(hex: 0x9A9A94))
        }
        let path = Paint.roundedRect(roof, 6)
        Paint.outline(ctx, path, UIColor(hex: 0x2E2419).withAlpha(0.5), width: 2.5)
        Paint.fill(ctx, path, top: UIColor(hex: 0xF2F0EA), bottom: UIColor(hex: 0xD9D6CC))
        ctx.setFillColor(UIColor(hex: 0xB8432F).cgColor)
        ctx.fill(CGRect(x: roof.minX, y: roof.maxY - roof.height * 0.25, width: roof.width, height: roof.height * 0.25))
    }

    static func windowShape(_ ctx: CGContext, _ rect: CGRect, trim: UIColor) {
        let glass = Paint.roundedRect(rect, 2)
        Paint.fill(ctx, glass, top: UIColor(hex: 0x5A6B78), bottom: UIColor(hex: 0x3A4650))
        Paint.clipped(ctx, to: glass) {
            ctx.setFillColor(UIColor.white.withAlpha(0.18).cgColor)
            ctx.fill(CGRect(x: rect.minX + rect.width * 0.15, y: rect.minY, width: rect.width * 0.16, height: rect.height))
        }
        Paint.outline(ctx, glass, trim, width: 5)
        ctx.setStrokeColor(trim.cgColor)
        ctx.setLineWidth(2.5)
        ctx.move(to: CGPoint(x: rect.midX, y: rect.minY)); ctx.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        ctx.strokePath()
    }

    static func label(_ text: String, in rect: CGRect, color: UIColor) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let font = UIFont.systemFont(ofSize: rect.height * 0.72, weight: .heavy)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
        NSAttributedString(string: text, attributes: attributes).draw(in: rect)
    }

    // MARK: Market

    static func marketStall(_ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        let wood = UIColor(hex: 0x9A7A58)
        return Canvas.image(size) { ctx in
            // Back posts, counter, front posts, awning on top.
            for x in [w * 0.16, w * 0.84] {
                Paint.fillHorizontal(ctx, Paint.roundedRect(CGRect(x: x - 4, y: h * 0.3, width: 8, height: ground - h * 0.36 - h * 0.3), 2),
                                     left: wood, right: wood.shaded(-0.2))
            }
            let counter = CGRect(x: w * 0.1, y: ground - h * 0.3, width: w * 0.8, height: h * 0.3)
            let counterTop = Paint.polygon([
                CGPoint(x: counter.minX, y: counter.minY), CGPoint(x: counter.maxX, y: counter.minY),
                CGPoint(x: counter.maxX - 6, y: counter.minY - h * 0.14), CGPoint(x: counter.minX + 6, y: counter.minY - h * 0.14),
            ])
            Paint.fill(ctx, counterTop, top: UIColor(hex: 0xB8966C), bottom: UIColor(hex: 0xA48258))
            Paint.fill(ctx, Paint.roundedRect(counter, 3), top: wood, bottom: wood.shaded(-0.18))
            Paint.outline(ctx, Paint.roundedRect(counter, 3), UIColor(hex: 0x3A2A1C).withAlpha(0.5), width: 2)
            // Produce on the counter.
            let colors = [CropPainter.gold, CropPainter.carrotOrange, CropPainter.potatoBrown, CropPainter.berryRed, CropPainter.leafGreen]
            for i in 0..<5 {
                let basket = CGRect(x: counter.minX + 8 + CGFloat(i) * counter.width / 5.2, y: counter.minY - h * 0.12,
                                    width: counter.width / 6, height: h * 0.09)
                Paint.fill(ctx, Paint.roundedRect(basket, 4), UIColor(hex: 0x8C6A42))
                for _ in 0..<6 {
                    Paint.dab(ctx, CGPoint(x: rng.cg(basket.minX + 4...basket.maxX - 4), y: basket.minY + rng.cg(-2...4)), 4, 3.5, colors[i])
                }
            }
            for x in [w * 0.12, w * 0.88] {
                Paint.fillHorizontal(ctx, Paint.roundedRect(CGRect(x: x - 4, y: h * 0.32, width: 8, height: ground - h * 0.32), 2),
                                     left: wood.shaded(0.05), right: wood.shaded(-0.15))
            }
            let awning = Paint.polygon([
                CGPoint(x: w * 0.04, y: h * 0.36), CGPoint(x: w * 0.96, y: h * 0.36),
                CGPoint(x: w * 0.88, y: h * 0.12), CGPoint(x: w * 0.12, y: h * 0.12),
            ])
            Paint.fill(ctx, awning, UIColor(hex: 0xC8503E))
            Paint.clipped(ctx, to: awning) {
                var x: CGFloat = 0
                var stripe = false
                while x < w {
                    if stripe {
                        ctx.setFillColor(UIColor(hex: 0xF4ECD8).cgColor)
                        ctx.fill(CGRect(x: x, y: 0, width: w * 0.08, height: h))
                    }
                    stripe.toggle()
                    x += w * 0.08
                }
                Paint.softSpot(ctx, CGPoint(x: w * 0.3, y: h * 0.15), w * 0.4, UIColor.white.withAlpha(0.2))
            }
            Paint.outline(ctx, awning, UIColor(hex: 0x4A1E16).withAlpha(0.5), width: 2.5)
        }
    }

    static func marketGoods(_ size: CGSize, ground: CGFloat, rng: inout SeededRandom) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            let colors = [CropPainter.pumpkinOrange, CropPainter.gold, CropPainter.berryRed]
            for i in 0..<3 {
                let crate = CGRect(x: w * 0.06 + CGFloat(i) * w * 0.31, y: ground - h * 0.45, width: w * 0.28, height: h * 0.4)
                Paint.fill(ctx, Paint.roundedRect(crate, 3), top: UIColor(hex: 0xB08D5F), bottom: UIColor(hex: 0x8A6A44))
                Paint.outline(ctx, Paint.roundedRect(crate, 3), UIColor(hex: 0x3A2A1C).withAlpha(0.5), width: 2)
                for _ in 0..<7 {
                    Paint.dab(ctx, CGPoint(x: rng.cg(crate.minX + 6...crate.maxX - 6), y: crate.minY + rng.cg(-4...6)), 6, 5, colors[i])
                }
            }
        }
    }

    // MARK: Street props

    static func gasPump(_ size: CGSize, ground: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            let body = CGRect(x: w * 0.18, y: h * 0.18, width: w * 0.64, height: ground - h * 0.18)
            let path = Paint.roundedRect(body, w * 0.16)
            Paint.outline(ctx, path, UIColor(hex: 0x4A1410).withAlpha(0.6), width: 2.5)
            Paint.fillHorizontal(ctx, path, left: UIColor(hex: 0xD04A36), right: UIColor(hex: 0x9E3024))
            let display = CGRect(x: body.minX + body.width * 0.18, y: body.minY + body.height * 0.14, width: body.width * 0.64, height: body.height * 0.22)
            Paint.fill(ctx, Paint.roundedRect(display, 3), UIColor(hex: 0xEFEBD9))
            ctx.setStrokeColor(UIColor(hex: 0x333333).cgColor)
            ctx.setLineWidth(3)
            ctx.move(to: CGPoint(x: body.maxX, y: body.midY))
            ctx.addQuadCurve(to: CGPoint(x: body.maxX + 6, y: ground - 10), control: CGPoint(x: body.maxX + 14, y: body.midY + 20))
            ctx.strokePath()
        }
    }

    static func lampPost(_ size: CGSize, ground: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            let iron = UIColor(hex: 0x3A3F42)
            ctx.setFillColor(iron.cgColor)
            ctx.fill(CGRect(x: w / 2 - 3, y: h * 0.2, width: 6, height: ground - h * 0.2))
            ctx.fill(CGRect(x: w / 2 - 8, y: ground - 8, width: 16, height: 8))
            let lantern = CGRect(x: w / 2 - w * 0.22, y: h * 0.07, width: w * 0.44, height: h * 0.14)
            Paint.fill(ctx, Paint.roundedRect(lantern, 3), top: UIColor(hex: 0xF3DE9A), bottom: UIColor(hex: 0xD8B35A))
            Paint.outline(ctx, Paint.roundedRect(lantern, 3), iron, width: 3)
            ctx.setFillColor(iron.cgColor)
            ctx.fill(CGRect(x: lantern.minX - 3, y: lantern.minY - 5, width: lantern.width + 6, height: 6))
        }
    }

    static func lampLight(_ size: CGSize) -> UIImage {
        let w = size.width, h = size.height
        return Canvas.image(size) { ctx in
            Paint.softSpot(ctx, CGPoint(x: w / 2, y: h * 0.14), w * 0.5, UIColor(hex: 0xFFD27A).withAlpha(0.9))
        }
    }

    static func bench(_ size: CGSize, ground: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        let wood = UIColor(hex: 0x9A7A58)
        return Canvas.image(size) { ctx in
            let iron = UIColor(hex: 0x3A3F42)
            ctx.setFillColor(iron.cgColor)
            for x in [w * 0.15, w * 0.82] {
                ctx.fill(CGRect(x: x, y: h * 0.35, width: 6, height: ground - h * 0.35))
            }
            for (i, y) in [h * 0.2, h * 0.32, h * 0.5, h * 0.6].enumerated() {
                let slat = CGRect(x: w * 0.08, y: y, width: w * 0.84, height: h * 0.08)
                Paint.fill(ctx, Paint.roundedRect(slat, 2), i < 2 ? wood.shaded(-0.05) : wood.shaded(0.06))
                Paint.outline(ctx, Paint.roundedRect(slat, 2), UIColor(hex: 0x3A2A1C).withAlpha(0.4), width: 1.2)
            }
        }
    }

    /// A "FOR RENT" board on a post (the corner shop, before it's rented).
    static func forRentSign(_ size: CGSize, ground: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        let wood = UIColor(hex: 0x9A7A58)
        return Canvas.image(size) { ctx in
            Paint.fillHorizontal(ctx, Paint.roundedRect(CGRect(x: w / 2 - 4, y: h * 0.3, width: 8, height: ground - h * 0.3), 2),
                                 left: wood, right: wood.shaded(-0.2))
            let board = CGRect(x: w * 0.06, y: h * 0.12, width: w * 0.88, height: h * 0.34)
            let path = Paint.roundedRect(board, 4)
            Paint.fill(ctx, path, top: UIColor(hex: 0xFBF6EA), bottom: UIColor(hex: 0xE9DFC8))
            Paint.outline(ctx, path, UIColor(hex: 0xB8432F), width: 3)
            label("FOR", in: CGRect(x: board.minX, y: board.minY + board.height * 0.08, width: board.width, height: board.height * 0.42),
                  color: UIColor(hex: 0xB8432F))
            label("RENT", in: CGRect(x: board.minX, y: board.midY, width: board.width, height: board.height * 0.42),
                  color: UIColor(hex: 0xB8432F))
        }
    }

    /// A chalkboard A-frame saying "OPEN", with a drawn carrot (your shop).
    static func openSign(_ size: CGSize, ground: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        let wood = UIColor(hex: 0x8A6A48)
        return Canvas.image(size) { ctx in
            // Back leg peeking out, then the front frame and its board.
            let back = Paint.polygon([CGPoint(x: w * 0.3, y: h * 0.12), CGPoint(x: w * 0.7, y: h * 0.12),
                                      CGPoint(x: w * 0.86, y: ground), CGPoint(x: w * 0.74, y: ground)])
            Paint.fill(ctx, back, wood.shaded(-0.25))
            let frame = Paint.polygon([CGPoint(x: w * 0.28, y: h * 0.1), CGPoint(x: w * 0.72, y: h * 0.1),
                                       CGPoint(x: w * 0.9, y: ground - 2), CGPoint(x: w * 0.1, y: ground - 2)])
            Paint.fill(ctx, frame, top: wood.shaded(0.05), bottom: wood.shaded(-0.1))
            Paint.outline(ctx, frame, UIColor(hex: 0x3E2A18).withAlpha(0.6), width: 2)
            let board = Paint.polygon([CGPoint(x: w * 0.33, y: h * 0.17), CGPoint(x: w * 0.67, y: h * 0.17),
                                       CGPoint(x: w * 0.8, y: ground - h * 0.1), CGPoint(x: w * 0.2, y: ground - h * 0.1)])
            Paint.fill(ctx, board, top: UIColor(hex: 0x3A4A40), bottom: UIColor(hex: 0x2C3A32))
            label("OPEN", in: CGRect(x: w * 0.2, y: h * 0.24, width: w * 0.6, height: h * 0.2), color: UIColor(hex: 0xF4F1E6))
            // A chalk carrot.
            let carrot = Paint.polygon([CGPoint(x: w * 0.42, y: h * 0.56), CGPoint(x: w * 0.58, y: h * 0.56),
                                        CGPoint(x: w * 0.5, y: h * 0.8)])
            Paint.fill(ctx, carrot, UIColor(hex: 0xF0924A))
            for dx in [-0.05, 0, 0.05] as [CGFloat] {
                Paint.stroke(ctx, from: CGPoint(x: w * 0.5, y: h * 0.56), to: CGPoint(x: w * (0.5 + dx * 1.6), y: h * 0.47),
                             bend: 0, width: 2.5, color: UIColor(hex: 0x8CCB6A))
            }
        }
    }

    static func signpost(_ size: CGSize, ground: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        let wood = UIColor(hex: 0x9A7A58)
        return Canvas.image(size) { ctx in
            Paint.fillHorizontal(ctx, Paint.roundedRect(CGRect(x: w / 2 - 5, y: h * 0.1, width: 10, height: ground - h * 0.1), 2),
                                 left: wood, right: wood.shaded(-0.2))
            for (y, pointsRight) in [(h * 0.14, true), (h * 0.34, false)] {
                let arrow: CGPath
                if pointsRight {
                    arrow = Paint.polygon([CGPoint(x: w * 0.3, y: y), CGPoint(x: w * 0.85, y: y), CGPoint(x: w * 0.98, y: y + h * 0.07),
                                           CGPoint(x: w * 0.85, y: y + h * 0.14), CGPoint(x: w * 0.3, y: y + h * 0.14)])
                } else {
                    arrow = Paint.polygon([CGPoint(x: w * 0.7, y: y), CGPoint(x: w * 0.15, y: y), CGPoint(x: w * 0.02, y: y + h * 0.07),
                                           CGPoint(x: w * 0.15, y: y + h * 0.14), CGPoint(x: w * 0.7, y: y + h * 0.14)])
                }
                Paint.fill(ctx, arrow, top: UIColor(hex: 0xE9DCC0), bottom: UIColor(hex: 0xD2C29E))
                Paint.outline(ctx, arrow, UIColor(hex: 0x5E4630), width: 2)
            }
        }
    }
}
