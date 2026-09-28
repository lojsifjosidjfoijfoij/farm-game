import SpriteKit
import AcresCore

/// The outdoors: today's wild finds lying in the woods and meadows (with a
/// twinkle so they're easy to spot), and fishing: the line, the bobber, the
/// "!" when a fish bites and the catch bar above the farmer. Visual only.
@MainActor
final class OutdoorsRenderer {
    private let assets: AssetCatalog
    private let objectLayer: SKNode
    private let effectsLayer: SKNode

    private var finds: [Int: SKSpriteNode] = [:]
    private var shownFinds: [Int: String] = [:]
    private var findTimer: TimeInterval = 1

    private var bobber: SKSpriteNode?
    private var line: SKShapeNode?
    private var exclaim: SKSpriteNode?
    private var bar: (root: SKNode, zone: SKShapeNode, marker: SKShapeNode)?
    private var shownPhase: FishingSession.Phase?

    init(assets: AssetCatalog, objectLayer: SKNode, effectsLayer: SKNode) {
        self.assets = assets
        self.objectLayer = objectLayer
        self.effectsLayer = effectsLayer
    }

    func update(game: GameController, dt: TimeInterval) {
        findTimer += dt
        if findTimer > 0.5 {
            findTimer = 0
            syncFinds(game.forageFinds)
        }
        updateFishing(game.fishing, farmer: game.simulation.state.farmer.position)
    }

    // MARK: Wild finds

    private func syncFinds(_ list: [ForageSpawn]) {
        var wanted: [Int: ForageSpawn] = [:]
        for find in list { wanted[find.id] = find }
        for (id, node) in finds where wanted[id]?.item != shownFinds[id] {
            node.removeFromParent()
            finds[id] = nil
            shownFinds[id] = nil
        }
        for find in list where finds[find.id] == nil {
            let sprite = SKSpriteNode(texture: assets.texture("item_\(find.item)"))
            sprite.size = CGSize(width: World.tileSize * 0.55, height: World.tileSize * 0.55)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0.15)
            sprite.position = World.point(find.position)
            sprite.zPosition = World.depth(forY: sprite.position.y)
            let twinkle = SKSpriteNode(texture: assets.texture("fx_sparkle"))
            twinkle.size = CGSize(width: World.tileSize * 0.22, height: World.tileSize * 0.22)
            twinkle.position = CGPoint(x: sprite.size.width * 0.3, y: sprite.size.height * 0.75)
            twinkle.zPosition = 1
            twinkle.alpha = 0
            twinkle.run(.repeatForever(.sequence([
                .wait(forDuration: 0.8 + Double(find.id % 7) * 0.25),
                .fadeIn(withDuration: 0.25), .fadeOut(withDuration: 0.45),
            ])))
            sprite.addChild(twinkle)
            sprite.run(.repeatForever(.sequence([.scale(to: 1.06, duration: 0.9), .scale(to: 1, duration: 0.9)])))
            objectLayer.addChild(sprite)
            finds[find.id] = sprite
            shownFinds[find.id] = find.item
        }
    }

    /// A find was picked: it hops up and fades.
    func picked(_ id: Int) {
        guard let node = finds[id] else { return }
        finds[id] = nil
        shownFinds[id] = nil
        node.removeAllActions()
        node.zPosition = 60
        node.run(.sequence([
            .group([.moveBy(x: 0, y: World.tileSize * 0.8, duration: 0.35), .fadeOut(withDuration: 0.35)]),
            .removeFromParent(),
        ]))
    }

    // MARK: Fishing

    private func updateFishing(_ session: FishingSession?, farmer: Vec2) {
        guard let session else {
            if bobber != nil { endFishing() }
            return
        }
        let target = World.point(session.target)
        if bobber == nil {
            let node = SKSpriteNode(texture: assets.texture("fx_bobber"))
            node.size = CGSize(width: World.tileSize * 0.3, height: World.tileSize * 0.3)
            node.position = World.point(farmer)
            node.zPosition = 45
            effectsLayer.addChild(node)
            node.run(.move(to: target, duration: FishingSession.castTime))
            bobber = node
            let shape = SKShapeNode()
            shape.strokeColor = UIColor.white.withAlphaComponent(0.7)
            shape.lineWidth = 1.2
            shape.zPosition = 44
            effectsLayer.addChild(shape)
            line = shape
        }
        // The line hangs from the rod tip to the bobber.
        if let bobber, let line {
            let tip = CGPoint(x: World.point(farmer).x + (target.x > World.point(farmer).x ? 1 : -1) * World.tileSize * 0.5,
                              y: World.point(farmer).y + World.tileSize * 1.3)
            let end = bobber.position
            let path = CGMutablePath()
            path.move(to: tip)
            let sag: CGFloat = session.phase == .reeling || session.phase == .bite ? 0 : World.tileSize * 0.4
            path.addQuadCurve(to: end, control: CGPoint(x: (tip.x + end.x) / 2, y: min(tip.y, end.y) - sag))
            line.path = path
        }
        if shownPhase != session.phase {
            phaseChanged(to: session.phase, session: session, farmer: farmer)
            shownPhase = session.phase
        }
        if case .reeling = session.phase, let bar {
            let width = World.tileSize * 1.8
            bar.marker.position = CGPoint(x: (CGFloat(session.marker) - 0.5) * width, y: 0)
            bar.zone.fillColor = session.isInZone ? UIColor(red: 0.45, green: 0.85, blue: 0.4, alpha: 1)
                : UIColor(red: 0.36, green: 0.7, blue: 0.32, alpha: 1)
        }
    }

    private func phaseChanged(to phase: FishingSession.Phase, session: FishingSession, farmer: Vec2) {
        guard let bobber else { return }
        switch phase {
        case .casting:
            break
        case .waiting:
            bobber.removeAllActions()
            bobber.position = World.point(session.target)
            bobber.run(.repeatForever(.sequence([.moveBy(x: 0, y: 2, duration: 0.7), .moveBy(x: 0, y: -2, duration: 0.7)])))
            ripple(at: bobber.position)
        case .bite:
            bobber.removeAllActions()
            bobber.run(.repeatForever(.sequence([.moveBy(x: 0, y: -5, duration: 0.08), .moveBy(x: 0, y: 5, duration: 0.12)])))
            ripple(at: bobber.position)
            let mark = SKSpriteNode(texture: assets.texture("fx_exclaim"))
            mark.size = CGSize(width: World.tileSize * 0.55, height: World.tileSize * 0.55)
            mark.position = CGPoint(x: World.point(farmer).x, y: World.point(farmer).y + World.tileSize * 1.9)
            mark.zPosition = 70
            mark.setScale(0.3)
            mark.run(.scale(to: 1, duration: 0.12))
            effectsLayer.addChild(mark)
            exclaim = mark
        case .reeling:
            exclaim?.removeFromParent()
            exclaim = nil
            showBar(session, above: farmer)
        case .landed, .escaped:
            exclaim?.removeFromParent()
            exclaim = nil
            bar?.root.removeFromParent()
            bar = nil
            bobber.removeAllActions()
            bobber.run(.move(to: World.point(farmer), duration: 0.3))
            ripple(at: World.point(session.target))
        }
    }

    private func showBar(_ session: FishingSession, above farmer: Vec2) {
        let width = World.tileSize * 1.8, height = World.tileSize * 0.24
        let root = SKNode()
        root.position = CGPoint(x: World.point(farmer).x, y: World.point(farmer).y + World.tileSize * 1.95)
        root.zPosition = 70
        let back = SKShapeNode(rectOf: CGSize(width: width + 6, height: height + 6), cornerRadius: (height + 6) / 2)
        back.fillColor = UIColor(red: 0.2, green: 0.16, blue: 0.12, alpha: 0.85)
        back.strokeColor = UIColor(red: 0.96, green: 0.94, blue: 0.87, alpha: 1)
        back.lineWidth = 2
        root.addChild(back)
        let zone = SKShapeNode(rectOf: CGSize(width: width * CGFloat(session.zoneWidth), height: height), cornerRadius: height / 3)
        zone.position = CGPoint(x: (CGFloat(session.zoneCenter) - 0.5) * width, y: 0)
        zone.strokeColor = .clear
        root.addChild(zone)
        let marker = SKShapeNode(rectOf: CGSize(width: 4, height: height + 10), cornerRadius: 2)
        marker.fillColor = .white
        marker.strokeColor = UIColor(red: 0.2, green: 0.16, blue: 0.12, alpha: 1)
        marker.lineWidth = 1
        root.addChild(marker)
        effectsLayer.addChild(root)
        root.setScale(0.4)
        root.run(.scale(to: 1, duration: 0.15))
        bar = (root, zone, marker)
    }

    private func ripple(at point: CGPoint) {
        let ring = SKSpriteNode(texture: assets.texture("fx_water_ripple"))
        ring.size = CGSize(width: World.tileSize * 0.7, height: World.tileSize * 0.35)
        ring.position = point
        ring.zPosition = 43
        ring.alpha = 0.8
        effectsLayer.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 1.8, duration: 0.7), .fadeOut(withDuration: 0.7)]), .removeFromParent()]))
    }

    private func endFishing() {
        bobber?.removeFromParent()
        line?.removeFromParent()
        exclaim?.removeFromParent()
        bar?.root.removeFromParent()
        bobber = nil
        line = nil
        exclaim = nil
        bar = nil
        shownPhase = nil
    }

    /// A fish comes out of the water and flies to the farmer.
    func caught(_ item: String, from water: Vec2, to farmer: Vec2) {
        let fish = SKSpriteNode(texture: assets.texture("item_\(item)"))
        fish.size = CGSize(width: World.tileSize * 0.6, height: World.tileSize * 0.6)
        fish.position = World.point(water)
        fish.zPosition = 72
        effectsLayer.addChild(fish)
        let end = CGPoint(x: World.point(farmer).x, y: World.point(farmer).y + World.tileSize * 1.6)
        fish.run(.sequence([
            .group([.move(to: end, duration: 0.45), .rotate(byAngle: .pi * 2, duration: 0.45)]),
            .group([.moveBy(x: 0, y: World.tileSize * 0.6, duration: 0.6), .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.3)])]),
            .removeFromParent(),
        ]))
    }
}
