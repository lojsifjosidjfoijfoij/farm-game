import SpriteKit
import AcresCore

/// Draws the pens (fences, trough, shelter) and the animals living in them.
/// Animals wander, graze and nap on their own; that's presentation only,
/// nothing about it is saved. Bubbles show what an animal has or wants.
@MainActor
final class RanchRenderer {

    private struct PenLook: Equatable {
        var repaired: Bool
        var water: Bool
    }

    private final class PenNodes {
        var parts: [SKNode] = []
        let trough: SKSpriteNode
        var look: PenLook

        init(trough: SKSpriteNode, look: PenLook) {
            self.trough = trough
            self.look = look
        }
    }

    private struct AnimalLook: Equatable {
        var art: String
        var bubble: String?
    }

    private enum Activity { case idle, walk, eat, sleep }

    private final class AnimalNodes {
        let id: Int
        let sprite: SKSpriteNode
        let shadow: SKSpriteNode
        var bubble: SKSpriteNode?
        var look: AnimalLook
        /// World position in tile units (presentation only).
        var position: Vec2
        var target: Vec2
        var activity = Activity.idle
        var timeLeft: TimeInterval
        var stepTimer: TimeInterval = 0
        var stepFrame = false
        var shownPose = ""

        init(id: Int, sprite: SKSpriteNode, shadow: SKSpriteNode, look: AnimalLook, position: Vec2, timeLeft: TimeInterval) {
            self.id = id
            self.sprite = sprite
            self.shadow = shadow
            self.look = look
            self.position = position
            self.target = position
            self.timeLeft = timeLeft
        }
    }

    private let assets: AssetCatalog
    private let flatLayer: SKNode
    private let objectLayer: SKNode
    private let effectsLayer: SKNode
    private var pens: [String: PenNodes] = [:]
    private var animals: [String: [Int: AnimalNodes]] = [:]
    private var rng = SeededRandom(seed: 0xA11A)
    /// 0 (day) … 1 (night): animals doze off after dark.
    var nightLevel: CGFloat = 0

    init(assets: AssetCatalog, flatLayer: SKNode, objectLayer: SKNode, effectsLayer: SKNode) {
        self.assets = assets
        self.flatLayer = flatLayer
        self.objectLayer = objectLayer
        self.effectsLayer = effectsLayer
    }

    // MARK: Sync with the game state

    func sync(ranch: Ranch, now: TimeInterval, inventory: Inventory) {
        for pen in PenCatalog.all {
            let state = ranch[pen.id]
            let look = PenLook(repaired: state.isRepaired, water: state.hasWater(at: now))
            if let existing = pens[pen.id] {
                if existing.look != look { rebuild(pen, look) }
            } else {
                rebuild(pen, look)
            }
            syncAnimals(pen, state, inventory: inventory)
        }
    }

    func removeAll() {
        for pen in pens.values { for part in pen.parts { part.removeFromParent() } }
        pens.removeAll()
        for group in animals.values {
            for nodes in group.values {
                nodes.sprite.removeFromParent()
                nodes.shadow.removeFromParent()
            }
        }
        animals.removeAll()
    }

    /// Where an animal is being drawn (for effects), in tile units.
    func position(ofAnimal id: Int, in penID: String) -> Vec2? {
        animals[penID]?[id]?.position
    }

    // MARK: Pens

    private func rebuild(_ pen: PenDefinition, _ look: PenLook) {
        if let old = pens[pen.id] {
            if old.look.repaired == look.repaired {
                // Only the water changed.
                old.trough.texture = assets.texture(look.water ? "prop_water_trough" : "prop_water_trough_empty")
                old.look = look
                return
            }
            for part in old.parts { part.removeFromParent() }
        }
        let trough = sprite(look.water ? "prop_water_trough" : "prop_water_trough_empty", at: pen.trough)
        let nodes = PenNodes(trough: trough, look: look)
        nodes.parts.append(trough)
        if let shadow = shadow(for: "prop_water_trough", at: pen.trough) { nodes.parts.append(shadow) }

        if let shelter = pen.shelterKind {
            nodes.parts.append(sprite(shelter, at: pen.shelterPosition))
            if let shadow = shadow(for: shelter, at: pen.shelterPosition) { nodes.parts.append(shadow) }
        }
        if !look.repaired {
            nodes.parts.append(sprite("prop_sign_repair", at: Vec2(pen.area.center.x + 0.9, pen.area.minY - 0.35)))
        }
        nodes.parts += fences(pen, repaired: look.repaired)
        pens[pen.id] = nodes
    }

    private func fences(_ pen: PenDefinition, repaired: Bool) -> [SKNode] {
        var parts: [SKNode] = []
        let area = pen.area
        var index = 0
        /// Run-down pens: some rails broken, a few missing.
        func kind(_ base: String) -> String? {
            index += 1
            guard !repaired else { return base }
            if index % 5 == 2 { return nil }
            return base.hasSuffix("_h") && index % 3 == 0 ? base + "_broken" : base
        }
        let shelterSpan: ClosedRange<Double>? = pen.shelterKind.flatMap { AssetManifest.spec(named: $0) }.map { spec in
            (pen.shelterPosition.x - spec.tilesWide * 0.45)...(pen.shelterPosition.x + spec.tilesWide * 0.45)
        }
        let gateX = area.center.x
        var x = area.minX + 0.5
        while x < area.maxX {
            // Front fence with a gap for the gate; back fence stops at the shelter.
            if abs(x - gateX) > 0.6, let k = kind("prop_fence_wood_h") { parts.append(sprite(k, at: Vec2(x, area.minY))) }
            if shelterSpan?.contains(x) != true, let k = kind("prop_fence_wood_h") { parts.append(sprite(k, at: Vec2(x, area.maxY))) }
            x += 1
        }
        var y = area.minY
        while y < area.maxY - 0.2 {
            if let k = kind("prop_fence_wood_v") { parts.append(sprite(k, at: Vec2(area.minX, y))) }
            if let k = kind("prop_fence_wood_v") { parts.append(sprite(k, at: Vec2(area.maxX, y))) }
            y += 1
        }
        for corner in [Vec2(area.minX, area.minY), Vec2(area.maxX, area.minY), Vec2(area.minX, area.maxY), Vec2(area.maxX, area.maxY)] {
            parts.append(sprite("prop_fence_wood_post", at: corner))
        }
        return parts
    }

    private func sprite(_ name: String, at position: Vec2) -> SKSpriteNode {
        let node = SKSpriteNode(texture: assets.texture(name))
        if let spec = AssetManifest.spec(named: name) {
            node.size = CGSize(width: CGFloat(spec.tilesWide) * World.tileSize, height: CGFloat(spec.tilesHigh) * World.tileSize)
            node.anchorPoint = CGPoint(x: 0.5, y: CGFloat(spec.anchorY))
        }
        node.position = World.point(position)
        node.zPosition = World.depth(forY: node.position.y)
        objectLayer.addChild(node)
        return node
    }

    private func shadow(for name: String, at position: Vec2) -> SKSpriteNode? {
        guard let spec = AssetManifest.spec(named: name), spec.shadowWidth > 0 else { return nil }
        let node = SKSpriteNode(texture: assets.texture("fx_shadow_soft"))
        let width = CGFloat(spec.shadowWidth) * World.tileSize
        node.size = CGSize(width: width, height: width * 0.42)
        let point = World.point(position)
        node.position = CGPoint(x: point.x + width * 0.08, y: point.y - width * 0.03)
        node.alpha = 0.3
        node.zPosition = 1
        flatLayer.addChild(node)
        return node
    }

    // MARK: Animals

    private func syncAnimals(_ pen: PenDefinition, _ state: PenState, inventory: Inventory) {
        var group = animals[pen.id] ?? [:]
        let present = Set(state.animals.map(\.id))
        for (id, nodes) in group where !present.contains(id) {
            nodes.sprite.removeFromParent()
            nodes.shadow.removeFromParent()
            group[id] = nil
        }
        for animal in state.animals {
            guard let species = animal.species else { continue }
            let look = AnimalLook(art: animal.isAdult ? species.adultArt : species.youngArt, bubble: bubble(for: animal, species, inventory))
            if let nodes = group[animal.id] {
                if nodes.look != look { apply(look, to: nodes, grew: nodes.look.art != look.art) }
            } else {
                group[animal.id] = makeAnimal(animal.id, look, in: pen)
            }
        }
        animals[pen.id] = group
    }

    private func bubble(for animal: AnimalState, _ species: AnimalSpecies, _ inventory: Inventory) -> String? {
        if animal.hasProduct { return "item_\(species.productItemID)" }
        if animal.isHungry { return "item_\(species.feeds.first { inventory.count($0) > 0 } ?? species.feeds[0])" }
        return nil
    }

    private func makeAnimal(_ id: Int, _ look: AnimalLook, in pen: PenDefinition) -> AnimalNodes {
        let start = randomSpot(in: pen)
        let sprite = SKSpriteNode(texture: nil)
        objectLayer.addChild(sprite)
        let shadow = SKSpriteNode(texture: assets.texture("fx_shadow_soft"))
        shadow.alpha = 0.28
        shadow.zPosition = 1
        flatLayer.addChild(shadow)
        let nodes = AnimalNodes(id: id, sprite: sprite, shadow: shadow, look: AnimalLook(art: "", bubble: nil),
                                position: start, timeLeft: rng.next(in: 0.5...3))
        apply(look, to: nodes, grew: false)
        place(nodes)
        return nodes
    }

    private func apply(_ look: AnimalLook, to nodes: AnimalNodes, grew: Bool) {
        if nodes.look.art != look.art {
            let name = "animal_\(look.art)_idle"
            if let spec = AssetManifest.spec(named: name) {
                nodes.sprite.size = CGSize(width: CGFloat(spec.tilesWide) * World.tileSize, height: CGFloat(spec.tilesHigh) * World.tileSize)
                nodes.sprite.anchorPoint = CGPoint(x: 0.5, y: CGFloat(spec.anchorY))
                let width = CGFloat(spec.shadowWidth) * World.tileSize
                nodes.shadow.size = CGSize(width: width, height: width * 0.4)
            }
            nodes.shownPose = ""
            if grew {
                nodes.sprite.setScale(0.8)
                nodes.sprite.run(.scale(to: 1, duration: 0.35))
            }
        }
        nodes.bubble?.removeFromParent()
        nodes.bubble = nil
        if let icon = look.bubble {
            let bubble = SKSpriteNode(texture: assets.texture("fx_bubble"))
            bubble.size = CGSize(width: World.tileSize * 0.62, height: World.tileSize * 0.62)
            bubble.zPosition = 50
            let item = SKSpriteNode(texture: assets.texture(icon))
            item.size = CGSize(width: bubble.size.width * 0.6, height: bubble.size.height * 0.6)
            item.position = CGPoint(x: 0, y: bubble.size.height * 0.06)
            bubble.addChild(item)
            bubble.run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 0.6), .moveBy(x: 0, y: -5, duration: 0.6)])))
            nodes.sprite.addChild(bubble)
            nodes.bubble = bubble
        }
        nodes.look = look
        positionBubble(nodes)
    }

    private func positionBubble(_ nodes: AnimalNodes) {
        guard let bubble = nodes.bubble else { return }
        let height = nodes.sprite.size.height * (1 - nodes.sprite.anchorPoint.y)
        bubble.position = CGPoint(x: 0, y: height + bubble.size.height * 0.45)
        // Keep the bubble readable when the animal is mirrored.
        bubble.xScale = nodes.sprite.xScale < 0 ? -1 : 1
    }

    // MARK: Wandering (every frame)

    func update(dt: TimeInterval) {
        let sleepy = nightLevel > 0.55
        for (penID, group) in animals {
            guard let pen = PenCatalog.pen(penID) else { continue }
            for nodes in group.values {
                advance(nodes, in: pen, dt: dt, sleepy: sleepy)
            }
        }
    }

    private func advance(_ nodes: AnimalNodes, in pen: PenDefinition, dt: TimeInterval, sleepy: Bool) {
        if sleepy, nodes.activity != .sleep {
            nodes.activity = .sleep
            nodes.timeLeft = 5
        }
        nodes.timeLeft -= dt
        switch nodes.activity {
        case .walk:
            let speed = walkSpeed(nodes.look.art)
            let delta = nodes.target - nodes.position
            let distance = delta.length
            if distance < 0.05 || nodes.timeLeft <= 0 {
                nodes.activity = rng.chance(0.55) ? .eat : .idle
                nodes.timeLeft = rng.next(in: 1.5...5)
            } else {
                let step = min(distance, speed * dt)
                nodes.position = nodes.position + delta * (step / distance)
                if abs(delta.x) > 0.02 { nodes.sprite.xScale = delta.x > 0 ? -1 : 1 }
                nodes.stepTimer += dt
                if nodes.stepTimer > 0.18 {
                    nodes.stepTimer = 0
                    nodes.stepFrame.toggle()
                }
                place(nodes)
            }
        case .idle, .eat:
            if nodes.timeLeft <= 0 {
                nodes.activity = .walk
                nodes.target = randomSpot(in: pen)
                nodes.timeLeft = 8
            }
        case .sleep:
            if !sleepy && nodes.timeLeft <= 0 {
                nodes.activity = .idle
                nodes.timeLeft = rng.next(in: 0.5...2)
            }
        }
        let pose: String = switch nodes.activity {
        case .walk: nodes.stepFrame ? "walk1" : "walk2"
        case .eat: "eat"
        case .sleep: "sleep"
        case .idle: "idle"
        }
        if pose != nodes.shownPose {
            nodes.shownPose = pose
            nodes.sprite.texture = assets.texture("animal_\(nodes.look.art)_\(pose)")
            positionBubble(nodes)
        }
    }

    private func place(_ nodes: AnimalNodes) {
        let point = World.point(nodes.position)
        nodes.sprite.position = point
        nodes.sprite.zPosition = World.depth(forY: point.y)
        nodes.shadow.position = CGPoint(x: point.x + 3, y: point.y - 2)
        positionBubble(nodes)
    }

    private func walkSpeed(_ art: String) -> Double {
        switch art {
        case "chick", "piglet", "lamb": 0.7
        case "chicken": 0.6
        case "cow", "calf": 0.35
        default: 0.45
        }
    }

    private func randomSpot(in pen: PenDefinition) -> Vec2 {
        let inner = pen.area.insetBy(0.6)
        return Vec2(rng.next(in: inner.minX...inner.maxX), rng.next(in: inner.minY...(inner.maxY - 0.3)))
    }

    // MARK: Effects

    /// Hearts over animals that were just fed.
    func hearts(in penID: String) {
        guard let group = animals[penID] else { return }
        for nodes in group.values where nodes.look.bubble == nil {
            let heart = SKSpriteNode(texture: assets.texture("fx_heart"))
            heart.size = CGSize(width: 24, height: 24)
            let point = World.point(nodes.position)
            heart.position = CGPoint(x: point.x, y: point.y + nodes.sprite.size.height * 0.9)
            heart.zPosition = 30
            heart.alpha = 0
            effectsLayer.addChild(heart)
            heart.run(.sequence([
                .wait(forDuration: rng.next(in: 0...0.3)),
                .group([.fadeIn(withDuration: 0.15), .moveBy(x: 0, y: 34, duration: 0.9), .scale(to: 1.3, duration: 0.9)]),
                .fadeOut(withDuration: 0.3),
                .removeFromParent(),
            ]))
        }
    }

    /// Products float up from the animals that gave them.
    func collected(in penID: String, items: [String: Int]) {
        guard let group = animals[penID], let pen = PenCatalog.pen(penID) else { return }
        let center = World.point(pen.area.center)
        var delay = 0.0
        for (item, amount) in items.sorted(by: { $0.key < $1.key }) {
            TreeEffects.badge(icon: "item_\(item)", amount: amount, at: CGPoint(x: center.x, y: center.y + 40), delay: delay,
                              in: effectsLayer, assets: assets)
            delay += 0.25
        }
        for nodes in group.values {
            let puff = SKSpriteNode(texture: assets.texture("fx_sparkle"))
            puff.size = CGSize(width: 22, height: 22)
            let point = World.point(nodes.position)
            puff.position = CGPoint(x: point.x, y: point.y + nodes.sprite.size.height)
            puff.zPosition = 30
            effectsLayer.addChild(puff)
            puff.run(.sequence([.group([.scale(to: 1.8, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
        }
    }

    func watered(_ penID: String) {
        guard let pen = PenCatalog.pen(penID) else { return }
        FieldEffects.watered(at: TileCoord(containing: pen.trough), in: effectsLayer, assets: assets)
    }

    func repaired(_ penID: String) {
        guard let pen = PenCatalog.pen(penID) else { return }
        var x = pen.area.minX
        while x <= pen.area.maxX {
            FieldEffects.plowed(at: TileCoord(containing: Vec2(x, pen.area.minY)), in: effectsLayer, assets: assets)
            x += 2
        }
    }
}
