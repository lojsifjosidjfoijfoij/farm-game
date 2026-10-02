import SpriteKit
import AcresCore

/// The village projects in the world: what the farm has helped build (the
/// post office, the market hall, the fair, the boathouse, the windmill with
/// its sails turning), a "coming soon" sign where an open project will go,
/// and the old windmill's ruin until it's rebuilt. Visual only: what stands
/// where is `VillageLayout`'s call.
@MainActor
final class VillageRenderer {
    private let assets: AssetCatalog
    private let factory: WorldObjectFactory
    private let objectLayer: SKNode
    private let flatLayer: SKNode

    private var shown: [MapObject]?
    private var shownSeason: Season?
    private var nodes: [SKNode] = []
    private var lights: [SKNode] = []
    private var sails: SKSpriteNode?
    private var sailFrame = 0
    private var sailClock: TimeInterval = 0
    private var nightLevel: CGFloat = 0

    /// Seconds per sail frame (15° each): a slow, steady turn.
    private static let sailFrameTime: TimeInterval = 0.32
    private static let sailFrames = 6

    init(assets: AssetCatalog, objectLayer: SKNode, flatLayer: SKNode) {
        self.assets = assets
        self.factory = WorldObjectFactory(assets: assets)
        self.objectLayer = objectLayer
        self.flatLayer = flatLayer
    }

    /// Rebuilds the pieces when what stands changes (a project finished, a
    /// new one opened). Returns true when it changed.
    @discardableResult
    func sync(game: GameController, force: Bool = false) -> Bool {
        let objects = VillageLayout.standing(game.simulation.state)
        guard force || objects != shown || game.season != shownSeason else { return false }
        shown = objects
        shownSeason = game.season
        for node in nodes { node.removeFromParent() }
        nodes = []
        lights = []
        sails = nil
        for object in objects {
            guard let made = factory.makeNodes(for: object, season: game.season) else { continue }
            (made.isFlat ? flatLayer : objectLayer).addChild(made.main)
            nodes.append(made.main)
            if let shadow = made.shadow {
                flatLayer.addChild(shadow)
                nodes.append(shadow)
            }
            for light in made.lights { light.alpha = nightLevel }
            lights += made.lights
            decorate(object, sprite: made.main)
        }
        return true
    }

    /// Lanterns and windows follow the night like the rest of the world's lights.
    func setLightIntensity(_ value: CGFloat) {
        guard abs(value - nightLevel) > 0.004 else { return }
        nightLevel = value
        for light in lights { light.alpha = value }
    }

    func update(dt: TimeInterval) {
        guard let sails else { return }
        sailClock += dt
        if sailClock >= Self.sailFrameTime {
            sailClock -= Self.sailFrameTime
            sailFrame = (sailFrame + 1) % Self.sailFrames
            sails.texture = assets.texture("building_windmill_sails_\(sailFrame)")
        }
    }

    // MARK: Life

    private func decorate(_ object: MapObject, sprite: SKNode) {
        guard let sprite = sprite as? SKSpriteNode else { return }
        switch object.kind {
        case "building_windmill":
            // The sails: a frame-by-frame overlay, pixel-aligned with the mill.
            let overlay = SKSpriteNode(texture: assets.texture("building_windmill_sails_\(sailFrame)"))
            overlay.size = sprite.size
            overlay.anchorPoint = sprite.anchorPoint
            overlay.zPosition = 0.01
            sprite.addChild(overlay)
            sails = overlay
        case "prop_rowboat":
            // Afloat: a slow one-pixel bob, each boat out of step with the other.
            let pixel = World.tileSize / CGFloat(PixelArt.pixelsPerTile)  // one art pixel
            let bob = SKAction.sequence([
                .wait(forDuration: 0.9 + 0.5 * Double(object.variant)),
                .moveBy(x: 0, y: pixel, duration: 0),
                .wait(forDuration: 1.1),
                .moveBy(x: 0, y: -pixel, duration: 0),
            ])
            sprite.run(.repeatForever(bob))
        case "prop_bunting", "prop_fair_lantern":
            WindSway.apply(WindSway.plant, to: sprite, seed: sprite.position)
        default:
            break
        }
    }
}
