import SpriteKit
import AcresCore

/// The farm's own additions in the world: the storage shed and silos,
/// sprinklers (with a spray now and then), workshops (puffing while they
/// work, with a bubble when goods are ready), FOR SALE signs on land that
/// isn't yours, and the farmhands walking to their jobs. Visual only: the
/// simulation decides what they do.
@MainActor
final class EstateRenderer {
    private let assets: AssetCatalog
    private let factory: WorldObjectFactory
    private let objectLayer: SKNode
    private let flatLayer: SKNode
    private let effectsLayer: SKNode

    private var shownEstate: EstateState?
    private var shownLand: [String]?
    private var shownFields: [String]?
    private var staticNodes: [SKNode] = []
    private var sprinklerTiles: [TileCoord] = []
    private var workshopSprites: [TileCoord: SKSpriteNode] = [:]
    private var bubbles: [TileCoord: (icon: String, node: SKSpriteNode)] = [:]
    private var puffTimer: TimeInterval = 0
    private var workers: [Int: FarmhandSprite] = [:]
    private var sprayTimer: TimeInterval = 0
    private var rng = SeededRandom(seed: 0xE57A7E)

    init(assets: AssetCatalog, objectLayer: SKNode, flatLayer: SKNode, effectsLayer: SKNode) {
        self.assets = assets
        self.factory = WorldObjectFactory(assets: assets)
        self.objectLayer = objectLayer
        self.flatLayer = flatLayer
        self.effectsLayer = effectsLayer
    }

    // MARK: Buildings, sprinklers, signs

    /// Rebuilds the standing pieces when the estate or the land changes.
    func sync(game: GameController, force: Bool = false) {
        let state = game.simulation.state
        let estate = state.estate
        let layoutChanged = shownEstate.map {
            $0.storageLevel != estate.storageLevel || $0.sprinklers != estate.sprinklers
                || $0.workshops.map(\.tile) != estate.workshops.map(\.tile) || $0.workshops.map(\.kind) != estate.workshops.map(\.kind)
        } ?? true
        guard force || layoutChanged || shownLand != state.ownedProperties || shownFields != state.ownedFields else {
            syncWorkers(estate.workers)
            shownEstate = estate
            return
        }
        shownEstate = estate
        shownLand = state.ownedProperties
        shownFields = state.ownedFields
        for node in staticNodes { node.removeFromParent() }
        staticNodes = []
        workshopSprites = [:]
        for bubble in bubbles.values { bubble.node.removeFromParent() }
        bubbles = [:]

        var objects: [MapObject] = EstateLayout.standing(estate).map { MapObject(kind: $0.kind, position: $0.position) }
        for sprinkler in estate.sprinklers {
            let kind = sprinkler.kind == "sprinkler_pro" ? "prop_sprinkler_pro" : "prop_sprinkler"
            objects.append(MapObject(kind: kind, position: sprinkler.tile.center))
        }
        for property in PropertyCatalog.forSale where !state.ownedProperties.contains(property.id) {
            if let spot = property.signSpot { objects.append(MapObject(kind: "prop_sign_for_sale", position: spot)) }
        }
        // Fields: yours are marked out; ones on your land you could buy get a faint outline and a sign.
        for field in FieldCatalog.all where state.ownedProperties.contains(field.propertyID) {
            let owned = state.ownedFields.contains(field.id)
            let border = Self.fieldBorder(field, owned: owned)
            flatLayer.addChild(border)
            staticNodes.append(border)
            if !owned {
                objects.append(MapObject(kind: "prop_sign_for_sale", position: Vec2(field.area.minX + 0.5, field.area.minY + 0.25)))
            }
        }
        for object in objects {
            guard let nodes = factory.makeNodes(for: object, season: game.season) else { continue }
            (nodes.isFlat ? flatLayer : objectLayer).addChild(nodes.main)
            staticNodes.append(nodes.main)
            if let shadow = nodes.shadow {
                flatLayer.addChild(shadow)
                staticNodes.append(shadow)
            }
        }
        for workshop in estate.workshops {
            let object = MapObject(kind: "prop_workshop_\(workshop.kind)", position: Self.workshopBase(workshop.tile))
            guard let nodes = factory.makeNodes(for: object, season: game.season) else { continue }
            objectLayer.addChild(nodes.main)
            staticNodes.append(nodes.main)
            if let sprite = nodes.main as? SKSpriteNode { workshopSprites[workshop.tile] = sprite }
            if let shadow = nodes.shadow {
                flatLayer.addChild(shadow)
                staticNodes.append(shadow)
            }
        }
        sprinklerTiles = estate.sprinklers.map(\.tile)
        syncWorkers(estate.workers)
    }

    /// A field marked out on the ground: a soft soil tint with an edge (yours),
    /// or just a faint outline (for sale).
    private static func fieldBorder(_ field: FieldDefinition, owned: Bool) -> SKShapeNode {
        let origin = World.point(Vec2(field.area.minX, field.area.minY))
        let rect = CGRect(x: origin.x, y: origin.y, width: CGFloat(field.area.width) * World.tileSize,
                          height: CGFloat(field.area.height) * World.tileSize)
        let node = SKShapeNode(rect: rect.insetBy(dx: 2, dy: 2), cornerRadius: World.tileSize * 0.18)
        if owned {
            node.fillColor = UIColor(red: 0.45, green: 0.33, blue: 0.2, alpha: 0.16)
            node.strokeColor = UIColor(red: 0.42, green: 0.3, blue: 0.18, alpha: 0.6)
            node.lineWidth = 3
        } else {
            node.fillColor = UIColor(white: 1, alpha: 0.06)
            node.strokeColor = UIColor(white: 1, alpha: 0.45)
            node.lineWidth = 2
        }
        node.zPosition = 0.2
        return node
    }

    /// Where a workshop's picture stands on its tile.
    static func workshopBase(_ tile: TileCoord) -> Vec2 { tile.center + Vec2(0, -0.3) }

    /// A workshop was set up, or its goods collected: a bounce (and the goods popping out).
    func workshopFeedback(at tile: TileCoord, collected item: String?) {
        guard let sprite = workshopSprites[tile] else { return }
        sprite.removeAction(forKey: "bounce")
        sprite.run(.sequence([.scaleX(to: 1.12, y: 0.9, duration: 0.08), .scale(to: 1, duration: 0.25)]), withKey: "bounce")
        puff(at: tile, count: item == nil ? 5 : 2)
        guard let item else { return }
        let icon = SKSpriteNode(texture: assets.texture("item_\(item)"))
        icon.size = CGSize(width: World.tileSize * 0.5, height: World.tileSize * 0.5)
        icon.position = CGPoint(x: sprite.position.x, y: sprite.position.y + World.tileSize * 0.9)
        icon.zPosition = 60
        effectsLayer.addChild(icon)
        icon.run(.sequence([
            .group([.moveBy(x: 0, y: World.tileSize * 0.9, duration: 0.5), .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.2)])]),
            .removeFromParent(),
        ]))
    }

    /// Smoke from the chimney (or a busy workshop's roof).
    private func puff(at tile: TileCoord, count: Int) {
        guard let sprite = workshopSprites[tile] else { return }
        for k in 0..<count {
            let puff = SKSpriteNode(texture: assets.texture("fx_smoke_puff"))
            puff.size = CGSize(width: World.tileSize * 0.3, height: World.tileSize * 0.3)
            puff.position = CGPoint(x: sprite.position.x + World.tileSize * 0.22 + CGFloat(k) * 3,
                                    y: sprite.position.y + sprite.size.height * 0.85)
            puff.zPosition = 40
            puff.alpha = 0.7
            puff.setScale(0.6)
            effectsLayer.addChild(puff)
            puff.run(.sequence([
                .wait(forDuration: Double(k) * 0.12),
                .group([.moveBy(x: 6, y: World.tileSize * 0.6, duration: 1.4), .scale(to: 1.4, duration: 1.4), .fadeOut(withDuration: 1.4)]),
                .removeFromParent(),
            ]))
        }
    }

    /// Bubbles over workshops with goods ready; puffs from the busy ones.
    private func updateWorkshops(_ workshops: [Workshop], dt: TimeInterval) {
        var wanted: [TileCoord: String] = [:]
        var busy: [TileCoord] = []
        for workshop in workshops {
            if workshop.ready > 0, let recipe = workshop.currentRecipe ?? workshop.lastRecipe.flatMap({ id in
                workshop.definition?.recipes.first { $0.id == id }
            }) {
                wanted[workshop.tile] = "item_\(recipe.output)"
            }
            if workshop.queued > 0, workshop.definition?.isAutomatic == false { busy.append(workshop.tile) }
        }
        for (tile, bubble) in bubbles where wanted[tile] != bubble.icon {
            bubble.node.removeFromParent()
            bubbles[tile] = nil
        }
        for (tile, icon) in wanted where bubbles[tile] == nil {
            guard let sprite = workshopSprites[tile] else { continue }
            let bubble = SKSpriteNode(texture: assets.texture("fx_bubble"))
            bubble.size = CGSize(width: World.tileSize * 0.62, height: World.tileSize * 0.62)
            bubble.position = CGPoint(x: sprite.position.x, y: sprite.position.y + sprite.size.height * 0.95 + bubble.size.height * 0.4)
            bubble.zPosition = 55
            let item = SKSpriteNode(texture: assets.texture(icon))
            item.size = CGSize(width: bubble.size.width * 0.6, height: bubble.size.height * 0.6)
            item.position = CGPoint(x: 0, y: bubble.size.height * 0.06)
            bubble.addChild(item)
            bubble.setScale(0.2)
            bubble.run(.sequence([.scale(to: 1, duration: 0.25),
                                  .repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 0.6), .moveBy(x: 0, y: -5, duration: 0.6)]))]))
            effectsLayer.addChild(bubble)
            bubbles[tile] = (icon, bubble)
        }
        guard !busy.isEmpty else { return }
        puffTimer -= dt
        if puffTimer <= 0 {
            puffTimer = 1.1 + rng.nextUnit() * 0.9
            puff(at: busy[Int(rng.nextUnit() * Double(busy.count)) % busy.count], count: 1)
        }
    }

    /// A burst of spray from one sprinkler.
    func spray(at tile: TileCoord) {
        let center = World.point(tile.center)
        for k in 0..<8 {
            let drop = SKSpriteNode(texture: assets.texture("fx_water_drops"))
            drop.size = CGSize(width: World.tileSize * 0.36, height: World.tileSize * 0.36)
            drop.position = CGPoint(x: center.x, y: center.y + 18)
            drop.zPosition = 20
            drop.alpha = 0.85
            effectsLayer.addChild(drop)
            let angle = CGFloat(k) * .pi / 4 + CGFloat(rng.nextUnit()) * 0.3
            let reach = World.tileSize * (0.8 + CGFloat(rng.nextUnit()) * 0.3)
            drop.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * reach, y: sin(angle) * reach * 0.55 - 6, duration: 0.55),
                    .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.25)]),
                ]),
                .removeFromParent(),
            ]))
        }
    }

    // MARK: Per frame

    func update(game: GameController, dt: TimeInterval) {
        // Every few seconds one of the sprinklers puffs.
        if !sprinklerTiles.isEmpty {
            sprayTimer -= dt
            if sprayTimer <= 0 {
                sprayTimer = 1.4 + rng.nextUnit() * 1.6
                let index = Int(rng.nextUnit() * Double(sprinklerTiles.count)) % sprinklerTiles.count
                spray(at: sprinklerTiles[index])
            }
        }
        let workshops = game.simulation.state.estate.workshops
        if !workshops.isEmpty || !bubbles.isEmpty { updateWorkshops(workshops, dt: dt) }
        let working = game.hour >= game.balance.workStartHour && game.hour < game.balance.workEndHour
        for worker in game.simulation.state.estate.workers {
            workers[worker.id]?.update(worker, working: working, dt: dt, assets: assets)
        }
    }

    private func syncWorkers(_ list: [Worker]) {
        let ids = Set(list.map(\.id))
        for (id, sprite) in workers where !ids.contains(id) {
            sprite.remove()
            workers[id] = nil
        }
        for worker in list where workers[worker.id] == nil {
            workers[worker.id] = FarmhandSprite(worker, assets: assets, objectLayer: objectLayer, flatLayer: flatLayer)
        }
    }
}

/// One farmhand on screen: walks to where their last job was, then shows the
/// work (watering, picking) for a moment. Off work, they head home.
@MainActor
private final class FarmhandSprite {
    private let sprite: SKSpriteNode
    private let shadow: SKSpriteNode
    private let look: Int
    private let home: Vec2
    private var position: Vec2
    private var seenTasks: Int
    private var workTime: TimeInterval = 0
    private var stepClock: TimeInterval = 0
    private var facing = Vec2(0, -1)
    private var shownTexture = ""
    private static let speed = 2.4

    init(_ worker: Worker, assets: AssetCatalog, objectLayer: SKNode, flatLayer: SKNode) {
        look = worker.look
        home = HomeValleyMap.farmhouseDoor + Vec2(1.2 + Double(worker.id % 3) * 0.7, -0.8)
        position = worker.position
        seenTasks = worker.tasksDone
        let name = "character_worker\(worker.look)_down_idle"
        let spec = AssetManifest.spec(named: name)
        sprite = SKSpriteNode(texture: assets.texture(name))
        sprite.size = assets.worldSize(name) ?? CGSize(width: World.tileSize * 0.9, height: World.tileSize * 1.5)
        sprite.anchorPoint = CGPoint(x: 0.5, y: CGFloat(spec?.anchorY ?? 0.05))
        objectLayer.addChild(sprite)
        shadow = SKSpriteNode(texture: assets.texture("fx_shadow_soft"))
        shadow.size = CGSize(width: World.tileSize * 0.58, height: World.tileSize * 0.24)
        shadow.alpha = 0.3
        shadow.zPosition = 1
        flatLayer.addChild(shadow)
    }

    func remove() {
        sprite.removeFromParent()
        shadow.removeFromParent()
    }

    func update(_ worker: Worker, working: Bool, dt: TimeInterval, assets: AssetCatalog) {
        if worker.tasksDone != seenTasks {
            seenTasks = worker.tasksDone
            workTime = 1.2  // show the work once they get there
        }
        // Stand beside the job rather than on it.
        let target = working ? worker.position + Vec2(-0.45, -0.35) : home
        let offset = target - position
        let distance = offset.length
        var pose = "idle"
        if distance > 0.05 {
            let step = min(distance, Self.speed * dt)
            position = position + offset * (step / distance)
            facing = offset
            stepClock += dt
            pose = Int(stepClock / 0.16) % 2 == 0 ? "walk1" : "walk2"
        } else if workTime > 0, working {
            workTime -= dt
            facing = Vec2(0.45, 0.35)
            let tool = worker.lastTask == .water || worker.lastTask == .fillTrough ? "can" : "hands"
            pose = tool + (Int(workTime / 0.3) % 2 == 0 ? "1" : "2")
        }
        // Home for the night: fade out at the door, back in the morning.
        let alpha: CGFloat = !working && distance <= 0.05 ? 0 : 1
        sprite.alpha += (alpha - sprite.alpha) * min(1, CGFloat(dt) * 4)
        shadow.alpha = sprite.alpha * 0.3

        let point = World.point(position)
        sprite.position = point
        sprite.zPosition = World.depth(forY: point.y) + 0.1
        shadow.position = CGPoint(x: point.x + 2, y: point.y - 1)
        let side: String
        if abs(facing.y) > abs(facing.x) * 1.2 {
            side = facing.y > 0 ? "up" : "down"
            sprite.xScale = 1
        } else {
            side = "side"
            sprite.xScale = facing.x > 0 ? -1 : 1
        }
        let name = "character_worker\(look)_\(side)_\(pose)"
        if name != shownTexture {
            shownTexture = name
            sprite.texture = assets.texture(name)
        }
    }
}
