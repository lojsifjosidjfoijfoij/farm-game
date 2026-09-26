import SpriteKit
import AcresCore

/// The SpriteKit nodes that represent one map object.
struct ObjectNodes {
    /// Standing sprite (depth-sorted) or flat sprite.
    let main: SKNode
    let isFlat: Bool
    /// Soft contact shadow on the ground, if any.
    let shadow: SKNode?
    /// Additive night-light sprites whose alpha follows the time of day.
    let lights: [SKNode]
}

/// Turns map objects into sprites: size and anchor from the asset manifest,
/// soft shadows, gentle sway for plants, night lights and chimney smoke.
@MainActor
struct WorldObjectFactory {
    let assets: AssetCatalog

    /// Sway animations, shared between nodes (SKActions are reusable).
    private static let treeSway = sway(angle: 0.012, period: 3.6)
    private static let plantSway = sway(angle: 0.05, period: 2.2)

    func makeNodes(for object: MapObject, season: Season) -> ObjectNodes? {
        guard let name = AssetManifest.assetName(forObjectKind: object.kind, season: season),
              let spec = AssetManifest.spec(named: name) else { return nil }

        let sprite = SKSpriteNode(texture: assets.texture(name))
        let isNature = object.kind.hasPrefix("tree_") || object.kind.hasPrefix("nature_")
        // Natural things vary a little in size and are sometimes mirrored.
        let scale: CGFloat = isNature && spec.layer == .standing ? 0.9 + 0.07 * CGFloat(object.variant % 4) : 1
        sprite.size = CGSize(width: CGFloat(spec.tilesWide) * World.tileSize * scale,
                             height: CGFloat(spec.tilesHigh) * World.tileSize * scale)
        if isNature && object.variant % 2 == 1 {
            sprite.xScale = -1
        }
        sprite.anchorPoint = CGPoint(x: 0.5, y: CGFloat(spec.anchorY))
        sprite.position = World.point(object.position)

        let isFlat = spec.layer == .flat
        sprite.zPosition = isFlat ? 0 : World.depth(forY: sprite.position.y)

        // Shadow on the ground, nudged away from the light (upper left).
        var shadow: SKSpriteNode?
        if spec.shadowWidth > 0 {
            let s = SKSpriteNode(texture: assets.texture("fx_shadow_soft"))
            let width = CGFloat(spec.shadowWidth) * World.tileSize * scale
            s.size = CGSize(width: width, height: width * 0.42)
            s.position = CGPoint(x: sprite.position.x + width * 0.08, y: sprite.position.y - width * 0.03)
            s.alpha = 0.3
            s.zPosition = 1
            shadow = s
        }

        // Night lights (e.g. glowing windows).
        var lights: [SKNode] = []
        let lightsName = name + "_lights"
        if AssetManifest.spec(named: lightsName) != nil {
            let glow = SKSpriteNode(texture: assets.texture(lightsName))
            glow.size = sprite.size
            glow.anchorPoint = sprite.anchorPoint
            glow.blendMode = .add
            glow.alpha = 0
            glow.zPosition = ZLayer.nightLightOffset
            sprite.addChild(glow)
            lights.append(glow)
        }

        if let chimney = Self.chimneys[name] {
            sprite.addChild(makeSmoke(at: CGPoint(
                x: (chimney.x - 0.5) * sprite.size.width,
                y: (chimney.y - sprite.anchorPoint.y) * sprite.size.height)))
        }

        if object.kind.hasPrefix("tree_") && object.kind != "tree_stump" {
            runSway(Self.treeSway, on: sprite, variant: object.variant)
        } else if object.kind.hasPrefix("nature_grass_tuft") || object.kind.hasPrefix("nature_flowers") {
            runSway(Self.plantSway, on: sprite, variant: object.variant)
        }

        return ObjectNodes(main: sprite, isFlat: isFlat, shadow: shadow, lights: lights)
    }

    /// The truck parked at its saved position (driving arrives in Phase 3).
    func makeTruck(_ truck: TruckState) -> ObjectNodes {
        // Phase 1 has one parked sprite (facing west); Phase 3 picks one of 16 by heading.
        let name = "vehicle_truck_old_dir08"
        let sprite = SKSpriteNode(texture: assets.texture(name))
        if let spec = AssetManifest.spec(named: name) {
            sprite.size = CGSize(width: CGFloat(spec.tilesWide) * World.tileSize, height: CGFloat(spec.tilesHigh) * World.tileSize)
            sprite.anchorPoint = CGPoint(x: 0.5, y: CGFloat(spec.anchorY))
        }
        sprite.position = World.point(truck.position)
        sprite.zPosition = World.depth(forY: sprite.position.y)
        sprite.name = "truck"

        let shadow = SKSpriteNode(texture: assets.texture("fx_shadow_soft"))
        shadow.size = CGSize(width: World.tileSize * 2.4, height: World.tileSize * 1.1)
        shadow.position = CGPoint(x: sprite.position.x + 4, y: sprite.position.y - 2)
        shadow.alpha = 0.35
        shadow.zPosition = 1
        return ObjectNodes(main: sprite, isFlat: false, shadow: shadow, lights: [])
    }

    // MARK: Decorations

    /// Chimney tops in unit sprite coordinates (origin bottom-left).
    private static let chimneys: [String: CGPoint] = [
        "building_farmhouse_t0": BuildingPainter.FarmhouseLayout.chimneyTopUnit,
    ]

    private func makeSmoke(at position: CGPoint) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = assets.texture("fx_smoke_puff")
        emitter.particleSize = CGSize(width: 30, height: 30)
        emitter.particleBirthRate = 2.2
        emitter.particleLifetime = 4.5
        emitter.particleLifetimeRange = 1.5
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = 0.35
        emitter.particleSpeed = 20
        emitter.particleSpeedRange = 8
        emitter.xAcceleration = 5  // a light breeze
        emitter.particleAlpha = 0.5
        emitter.particleAlphaRange = 0.15
        emitter.particleAlphaSpeed = -0.1
        emitter.particleScale = 0.5
        emitter.particleScaleRange = 0.15
        emitter.particleScaleSpeed = 0.3
        emitter.particleRotationRange = .pi
        emitter.particleRotationSpeed = 0.2
        emitter.particlePositionRange = CGVector(dx: 6, dy: 2)
        emitter.position = position
        emitter.zPosition = 1
        emitter.advanceSimulationTime(5)
        return emitter
    }

    private func runSway(_ action: SKAction, on node: SKNode, variant: Int) {
        // Offset each plant's phase so they don't sway in lockstep.
        let offset = Double(abs(Int(node.position.x * 7 + node.position.y * 13)) % 1000) / 1000 * 3
        node.run(.sequence([.wait(forDuration: offset), action]))
    }

    private static func sway(angle: CGFloat, period: TimeInterval) -> SKAction {
        let half = period / 2
        let right = SKAction.rotate(toAngle: -angle, duration: half)
        right.timingMode = .easeInEaseOut
        let left = SKAction.rotate(toAngle: angle, duration: half)
        left.timingMode = .easeInEaseOut
        return .repeatForever(.sequence([right, left]))
    }
}
