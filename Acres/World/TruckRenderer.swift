import SpriteKit
import AcresCore

/// Draws the player's truck: the right one of 16 direction sprites, the load
/// in its bed, a shadow that turns with it, dust on dirt roads, a guide
/// arrow toward the current goal, and a "Get out" bubble when it's stopped
/// (the truck is the drive button: tap it to get in or out).
@MainActor
final class TruckRenderer {
    private let assets: AssetCatalog
    let body: SKSpriteNode
    private let load: SKSpriteNode
    private let shadow: SKSpriteNode
    private let dust: SKEmitterNode
    private let guide: SKSpriteNode
    private let exitBubble = SKNode()
    private var direction = -1
    private var loadLevel = -1

    init(assets: AssetCatalog, objectLayer: SKNode, flatLayer: SKNode, effectsLayer: SKNode) {
        self.assets = assets
        let spec = AssetManifest.spec(named: "vehicle_truck_old_dir00")
        let size = CGSize(width: CGFloat(spec?.tilesWide ?? 2.5) * World.tileSize, height: CGFloat(spec?.tilesHigh ?? 2.5) * World.tileSize)
        let anchor = CGPoint(x: 0.5, y: CGFloat(spec?.anchorY ?? 0.4))

        body = SKSpriteNode(texture: nil, size: size)
        body.anchorPoint = anchor
        body.name = "truck"
        objectLayer.addChild(body)

        load = SKSpriteNode(texture: nil, size: size)
        load.anchorPoint = anchor
        load.zPosition = 0.01
        load.isHidden = true
        body.addChild(load)

        shadow = SKSpriteNode(texture: assets.texture("fx_shadow_soft"))
        shadow.size = CGSize(width: World.tileSize * 2.3, height: World.tileSize * 1.05)
        shadow.alpha = 0.35
        shadow.zPosition = 1
        flatLayer.addChild(shadow)

        dust = SKEmitterNode()
        dust.particleTexture = assets.texture("fx_dust_puff")
        dust.particleSize = CGSize(width: 26, height: 26)
        dust.particleBirthRate = 0
        dust.particleLifetime = 0.9
        dust.particleLifetimeRange = 0.3
        dust.particleSpeed = 12
        dust.particleSpeedRange = 8
        dust.emissionAngleRange = .pi
        dust.particleAlpha = 0.55
        dust.particleAlphaSpeed = -0.6
        dust.particleScale = 0.6
        dust.particleScaleSpeed = 1.2
        dust.particlePositionRange = CGVector(dx: 14, dy: 8)
        dust.zPosition = 0
        dust.targetNode = effectsLayer
        effectsLayer.addChild(dust)

        guide = SKSpriteNode(texture: assets.texture("fx_guide_arrow"))
        guide.size = CGSize(width: World.tileSize * 0.8, height: World.tileSize * 0.8)
        guide.zPosition = 10
        guide.alpha = 0
        effectsLayer.addChild(guide)
        guide.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.5), .scale(to: 1, duration: 0.5)])))

        // "Get out": a small dark pill over the stopped truck.
        let pill = SKShapeNode(rectOf: CGSize(width: 96, height: 30), cornerRadius: 15)
        pill.fillColor = SKColor(red: 0.11, green: 0.14, blue: 0.13, alpha: 0.86)
        pill.strokeColor = SKColor(white: 1, alpha: 0.9)
        pill.lineWidth = 2
        exitBubble.addChild(pill)
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "Get out"
        label.fontSize = 16
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        exitBubble.addChild(label)
        exitBubble.zPosition = 12
        exitBubble.alpha = 0
        exitBubble.isHidden = true
        effectsLayer.addChild(exitBubble)
        exitBubble.run(.repeatForever(.sequence([.scale(to: 1.06, duration: 0.6), .scale(to: 1, duration: 0.6)])))
    }

    /// Whether a tap (scene point) counts as tapping the truck: its picture
    /// with some room around it, anything within `tolerance` of its middle,
    /// or the "Get out" bubble.
    func isHit(_ point: CGPoint, tolerance: CGFloat) -> Bool {
        let frame = body.calculateAccumulatedFrame().insetBy(dx: -World.tileSize * 0.5, dy: -World.tileSize * 0.5)
        if frame.contains(point) { return true }
        let middle = CGPoint(x: body.position.x, y: body.position.y + World.tileSize * 0.3)
        if hypot(point.x - middle.x, point.y - middle.y) < tolerance { return true }
        if !exitBubble.isHidden, exitBubble.calculateAccumulatedFrame().insetBy(dx: -12, dy: -12).contains(point) { return true }
        return false
    }

    /// Shows the "Get out" bubble over the truck (driving and stopped).
    func showExit(_ visible: Bool) {
        exitBubble.position = CGPoint(x: body.position.x, y: body.position.y + World.tileSize * 2)
        if visible {
            exitBubble.isHidden = false
            if exitBubble.alpha < 1 { exitBubble.alpha = min(1, exitBubble.alpha + 0.1) }
        } else if !exitBubble.isHidden {
            exitBubble.alpha = max(0, exitBubble.alpha - 0.2)
            if exitBubble.alpha <= 0 { exitBubble.isHidden = true }
        }
    }

    /// Updates everything for this frame.
    func update(truck: TruckState, speed: Double, surface: Terrain, cargoFraction: Double, guideTarget: Vec2?) {
        let position = World.point(truck.position)
        body.position = position
        body.zPosition = World.depth(forY: position.y)

        let newDirection = TruckPhysics.directionIndex(for: truck.heading)
        if newDirection != direction {
            direction = newDirection
            body.texture = assets.texture(Self.name("vehicle_truck_old", newDirection))
            loadLevel = -1  // refresh the load for the new direction
        }
        let level = cargoFraction <= 0 ? 0 : (cargoFraction < 0.5 ? 1 : 2)
        if level != loadLevel {
            loadLevel = level
            load.isHidden = level == 0
            if level > 0 {
                load.texture = assets.texture(Self.name("vehicle_truck_old_load\(level)", direction))
            }
        }

        shadow.position = CGPoint(x: position.x + 4, y: position.y - 3)
        shadow.zRotation = CGFloat(truck.heading)

        // Dust from the rear wheels on loose ground.
        let loose = surface != .asphalt
        dust.particleBirthRate = loose && speed > 1.5 ? CGFloat(speed * 5) : 0
        let rear = CGPoint(x: position.x - cos(CGFloat(truck.heading)) * World.tileSize * 0.9,
                           y: position.y - sin(CGFloat(truck.heading)) * World.tileSize * 0.9)
        dust.position = rear

        // Guide arrow: circles the truck, pointing at the goal.
        if let target = guideTarget, truck.position.distance(to: target) > 4 {
            let angle = atan2(target.y - truck.position.y, target.x - truck.position.x)
            guide.zRotation = CGFloat(angle)
            guide.position = CGPoint(x: position.x + CGFloat(cos(angle)) * World.tileSize * 1.7,
                                     y: position.y + CGFloat(sin(angle)) * World.tileSize * 1.7 + World.tileSize * 0.5)
            if guide.alpha < 1 { guide.alpha = min(1, guide.alpha + 0.1) }
        } else if guide.alpha > 0 {
            guide.alpha = max(0, guide.alpha - 0.1)
        }
    }

    static func name(_ base: String, _ direction: Int) -> String {
        "\(base)_dir\(direction < 10 ? "0" : "")\(direction)"
    }
}
