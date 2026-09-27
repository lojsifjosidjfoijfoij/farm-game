import SpriteKit
import AcresCore

/// Your shop in the world: the "for rent" or "open" sign out front, and
/// villagers who walk in to buy something (one per sale, a few at a time).
/// Purely visual: the sales themselves happen in the simulation.
@MainActor
final class StoreRenderer {
    private let assets: AssetCatalog
    private let objectLayer: SKNode
    private let flatLayer: SKNode
    private let sign = SKSpriteNode(texture: nil)
    private var shownSign = ""
    private var walkers: [Walker] = []
    private var seenDay = -1
    private var seenItems = 0
    private var waiting = 0
    private var spawnTimer: TimeInterval = 0
    private var rng = SeededRandom(seed: 0x5709E)

    private let store = StoreDefinition.corner
    private static let signSpot = Vec2(70.95, 27.3)
    private static let walkSpeed = 1.5  // tiles per second
    private static let maxWalkers = 4

    private final class Walker {
        let sprite: SKSpriteNode
        let shadow: SKSpriteNode
        let look: Int
        var route: [Vec2]
        var position: Vec2
        /// Seconds left inside the shop (nil = walking).
        var shopping: TimeInterval?
        var enteredShop = false
        var stepClock: TimeInterval = 0
        var done = false

        init(sprite: SKSpriteNode, shadow: SKSpriteNode, look: Int, route: [Vec2]) {
            self.sprite = sprite
            self.shadow = shadow
            self.look = look
            self.route = route
            self.position = route[0]
        }
    }

    init(assets: AssetCatalog, objectLayer: SKNode, flatLayer: SKNode) {
        self.assets = assets
        self.objectLayer = objectLayer
        self.flatLayer = flatLayer
        let spec = AssetManifest.spec(named: "prop_for_rent_sign")
        sign.anchorPoint = CGPoint(x: 0.5, y: CGFloat(spec?.anchorY ?? 0.05))
        let point = World.point(Self.signSpot)
        sign.position = point
        sign.zPosition = World.depth(forY: point.y)
        sign.isHidden = true
        objectLayer.addChild(sign)
    }

    func update(store state: StoreState, hour: Int, dt: TimeInterval) {
        let open = state.isRented && store.isOpen(atHour: hour)
        let signName = !state.isRented ? "prop_for_rent_sign" : (open ? "prop_open_sign" : "")
        if signName != shownSign {
            shownSign = signName
            sign.isHidden = signName.isEmpty
            if !signName.isEmpty {
                sign.texture = assets.texture(signName)
                sign.size = assets.worldSize(signName) ?? CGSize(width: World.tileSize, height: World.tileSize)
            }
        }

        // Every sale sends a customer (a new day starts the count again).
        if state.today.day != seenDay {
            seenDay = state.today.day
            seenItems = state.today.items
        } else if state.today.items > seenItems {
            waiting = min(waiting + state.today.items - seenItems, 6)
            seenItems = state.today.items
        }
        spawnTimer -= dt
        if waiting > 0, spawnTimer <= 0, walkers.count < Self.maxWalkers {
            spawnWalker()
            waiting -= 1
            spawnTimer = 1.1 + rng.nextUnit() * 1.2
        }

        for walker in walkers { move(walker, dt: dt) }
        for walker in walkers where walker.done {
            walker.sprite.removeFromParent()
            walker.shadow.removeFromParent()
        }
        walkers.removeAll { $0.done }
    }

    // MARK: Walkers

    private func spawnWalker() {
        let look = Int(rng.nextUnit() * Double(AssetManifest.villagerCount)) % AssetManifest.villagerCount + 1
        // Along the street from one side, in through the door, out to the other side.
        let fromLeft = rng.nextUnit() < 0.5
        let side: Double = fromLeft ? -1 : 1
        let door = store.door
        let streetY = 23.4 + rng.nextUnit() * 1.2
        let route = [
            Vec2(door.x + side * (7 + rng.nextUnit() * 3), streetY),
            Vec2(door.x + side * 0.8, streetY + 0.4),
            Vec2(door.x + (rng.nextUnit() - 0.5) * 0.4, door.y - 0.3),
            Vec2(door.x - side * 0.8, streetY + 0.3),
            Vec2(door.x - side * (7 + rng.nextUnit() * 3), streetY - 0.2),
        ]
        let name = "character_villager\(look)_down_idle"
        let spec = AssetManifest.spec(named: name)
        let sprite = SKSpriteNode(texture: assets.texture(name))
        sprite.size = assets.worldSize(name) ?? CGSize(width: World.tileSize * 0.9, height: World.tileSize * 1.5)
        sprite.anchorPoint = CGPoint(x: 0.5, y: CGFloat(spec?.anchorY ?? 0.05))
        sprite.alpha = 0
        objectLayer.addChild(sprite)
        let shadow = SKSpriteNode(texture: assets.texture("fx_shadow_soft"))
        shadow.size = CGSize(width: World.tileSize * 0.58, height: World.tileSize * 0.24)
        shadow.alpha = 0
        shadow.zPosition = 1
        flatLayer.addChild(shadow)
        let walker = Walker(sprite: sprite, shadow: shadow, look: look, route: route)
        walkers.append(walker)
        place(walker, facing: route[1] - route[0], walking: true)
    }

    private func move(_ walker: Walker, dt: TimeInterval) {
        if var left = walker.shopping {
            left -= dt
            walker.shopping = left > 0 ? left : nil
            let alpha = left > 0.4 ? 0 : 1 - max(0, left) / 0.4  // steps back out of the door
            walker.sprite.alpha = alpha
            walker.shadow.alpha = alpha * 0.3
            if left <= 0 { place(walker, facing: Vec2(0, -1), walking: false) }
            return
        }
        guard walker.route.count > 1 else {
            walker.done = true
            return
        }
        let target = walker.route[1]
        let offset = target - walker.position
        let distance = offset.length
        let step = Self.walkSpeed * dt
        if distance <= step {
            walker.position = target
            walker.route.removeFirst()
            // The third point is the door: pop inside for a moment.
            if walker.route.count == 3 && !walker.enteredShop {
                walker.enteredShop = true
                walker.shopping = 2 + rng.nextUnit() * 2.5
            }
        } else {
            walker.position = Vec2(walker.position.x + offset.x / distance * step, walker.position.y + offset.y / distance * step)
        }
        walker.stepClock += dt
        // Fade in at the start of the walk, out at the end and at the door.
        let fromStart = walker.route.count >= 4 ? min(1, walker.stepClock / 0.5) : 1
        let toEnd = walker.route.count == 2 ? min(1, distance / 1.2) : 1
        let toDoor = walker.route.count == 4 && !walker.enteredShop ? min(1, distance / 0.6) : 1
        let alpha = min(fromStart, toEnd, toDoor)
        walker.sprite.alpha = alpha
        walker.shadow.alpha = alpha * 0.3
        place(walker, facing: offset, walking: true)
    }

    private func place(_ walker: Walker, facing direction: Vec2, walking: Bool) {
        let point = World.point(walker.position)
        walker.sprite.position = point
        walker.sprite.zPosition = World.depth(forY: point.y) + 0.1
        walker.shadow.position = CGPoint(x: point.x + 2, y: point.y - 1)
        let facing: String
        if abs(direction.y) > abs(direction.x) * 1.2 {
            facing = direction.y > 0 ? "up" : "down"
            walker.sprite.xScale = 1
        } else {
            facing = "side"
            walker.sprite.xScale = direction.x > 0 ? -1 : 1
        }
        let pose = walking ? (Int(walker.stepClock / 0.18) % 2 == 0 ? "walk1" : "walk2") : "idle"
        walker.sprite.texture = assets.texture("character_villager\(walker.look)_\(facing)_\(pose)")
    }
}
