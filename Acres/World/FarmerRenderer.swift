import SpriteKit
import AcresCore

/// Draws the farmer: the right facing and pose each frame (walking steps,
/// tool swings), a soft shadow, and small markers on lined-up jobs.
@MainActor
final class FarmerRenderer {
    private let assets: AssetCatalog
    private let sprite: SKSpriteNode
    private let shadow: SKSpriteNode
    private let markerLayer = SKNode()
    private var shownTexture = ""
    private var walkClock: TimeInterval = 0

    init(assets: AssetCatalog, objectLayer: SKNode, flatLayer: SKNode, effectsLayer: SKNode) {
        self.assets = assets
        let spec = AssetManifest.spec(named: "character_farmer_down_idle")
        sprite = SKSpriteNode(texture: nil)
        sprite.size = CGSize(width: CGFloat(spec?.tilesWide ?? 0.9) * World.tileSize,
                             height: CGFloat(spec?.tilesHigh ?? 1.5) * World.tileSize)
        sprite.anchorPoint = CGPoint(x: 0.5, y: CGFloat(spec?.anchorY ?? 0.05))
        objectLayer.addChild(sprite)

        shadow = SKSpriteNode(texture: assets.texture("fx_shadow_soft"))
        shadow.size = CGSize(width: World.tileSize * 0.62, height: World.tileSize * 0.26)
        shadow.alpha = 0.32
        shadow.zPosition = 1
        flatLayer.addChild(shadow)

        markerLayer.zPosition = 4
        flatLayer.addChild(markerLayer)
    }

    func update(_ farmer: FarmerVisual, dt: TimeInterval) {
        sprite.isHidden = farmer.inTruck
        shadow.isHidden = farmer.inTruck
        guard !farmer.inTruck else { return }
        let point = World.point(farmer.position)
        sprite.position = point
        sprite.zPosition = World.depth(forY: point.y) + 0.1  // stands in front of what's on the same row
        shadow.position = CGPoint(x: point.x + 2, y: point.y - 1)

        // Facing: mostly up/down, or sideways (the art faces left).
        let f = farmer.facing
        let facing: String
        if abs(f.y) > abs(f.x) * 1.2 {
            facing = f.y > 0 ? "up" : "down"
        } else {
            facing = "side"
            sprite.xScale = f.x > 0 ? -1 : 1
        }
        if facing != "side" { sprite.xScale = 1 }

        let pose: String
        switch farmer.activity {
        case .idle:
            walkClock = 0
            pose = "idle"
        case .walking:
            walkClock += dt * (farmer.isTired ? 0.6 : 1)
            pose = Int(walkClock / 0.16) % 2 == 0 ? "walk1" : "walk2"
        case .working(let tool, let progress):
            // Two beats per job: wind up, then the stroke.
            let beat = progress < 0.45 || (progress > 0.7 && progress < 0.85) ? "1" : "2"
            pose = tool.rawValue + beat
        }
        let name = "character_farmer_\(facing)_\(pose)"
        if name != shownTexture {
            shownTexture = name
            sprite.texture = assets.texture(name)
        }
    }

    /// Markers on the jobs lined up.
    func showMarkers(_ positions: [Vec2]) {
        markerLayer.removeAllChildren()
        for (index, position) in positions.enumerated() {
            let marker = SKSpriteNode(texture: assets.texture("fx_job_marker"))
            marker.size = CGSize(width: World.tileSize * 0.42, height: World.tileSize * 0.42)
            marker.position = World.point(position)
            marker.alpha = index == 0 ? 0.95 : 0.7
            markerLayer.addChild(marker)
            marker.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.5), .scale(to: 0.94, duration: 0.5)])))
        }
    }
}
