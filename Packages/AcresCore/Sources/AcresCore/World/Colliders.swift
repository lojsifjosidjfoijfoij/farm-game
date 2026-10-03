import Foundation

/// A solid shape the truck bumps into: close to what you see (a tree's trunk,
/// a rock, a building's walls, a fence's rails), not whole tiles.
public struct Collider: Sendable, Equatable {
    public let rect: TileRect
    /// A wild tree's or stump's trunk tile: once the player chops or clears
    /// it (`Woodland.hiddenMapTrees`), it's gone.
    public let treeFoot: TileCoord?

    public init(rect: TileRect, treeFoot: TileCoord? = nil) {
        self.rect = rect
        self.treeFoot = treeFoot
    }
}

extension ObjectFootprint {
    /// What the truck bumps into, or nil if it drives over it. Trees and
    /// props are just their trunk or base; fences are their rails.
    public static func collider(for object: MapObject) -> TileRect? {
        let p = object.position
        let kind = object.kind
        if isClearable(kind) { return nil }
        func box(_ halfWidth: Double, _ front: Double, _ back: Double) -> TileRect {
            TileRect(minX: p.x - halfWidth, minY: p.y - front, maxX: p.x + halfWidth, maxY: p.y + back)
        }
        // Fences: one tile of rails, along the tile edge it stands on.
        if kind.hasPrefix("prop_fence") {
            if kind.hasSuffix("_post") { return box(0.08, 0.08, 0.08) }
            if kind.hasSuffix("_v") { return TileRect(minX: p.x - 0.07, minY: p.y, maxX: p.x + 0.07, maxY: p.y + 1) }
            return box(0.5, 0.07, 0.07)
        }
        if kind.hasPrefix("tree_") { return box(0.16, 0.1, 0.18) }
        switch kind {
        case "nature_rock_large": return box(0.4, 0.15, 0.3)
        case "nature_reeds", "nature_lily_pads": return nil
        case "prop_lamp_post", "prop_signpost", "prop_mailbox", "prop_sign_for_sale", "prop_sign_sold", "prop_gas_pump",
             "prop_fair_lantern", "prop_project_sign":
            return box(0.12, 0.1, 0.12)
        case "prop_bench": return box(0.55, 0.05, 0.3)
        case "prop_bunting", "prop_rowboat": return nil
        default: break
        }
        if kind.hasPrefix("nature_bush") { return box(0.24, 0.1, 0.2) }
        if kind.hasPrefix("building_") || kind.hasPrefix("nature_") || kind == "prop_well" || kind == "prop_log_pile" {
            return rect(for: object)  // walls and water: their whole footprint
        }
        // Other props (crates, hay bales, planters, stalls' goods): their base.
        let half = min(0.55, (AssetManifest.spec(named: kind)?.tilesWide ?? 0.6) * 0.32)
        return box(half, 0.1, 0.25)
    }
}

/// What the truck can't drive through, shape by shape: the map's colliders
/// (minus the trees the player has cleared), trees the player planted, the
/// farm's and the village's buildings, and brush over land not yet the farm's.
public struct DrivingObstacles: Sendable {
    public let map: WorldMap
    public let woodland: Woodland
    /// Footprints of buildings put up since the map was drawn.
    public let built: [TileRect]
    public let wild: WildLand

    public init(map: WorldMap, woodland: Woodland = Woodland(), built: [TileRect] = [], wild: WildLand = .none) {
        self.map = map
        self.woodland = woodland
        self.built = built
        self.wild = wild
    }

    public init(map: WorldMap, state: GameState) {
        self.init(map: map, woodland: state.woodland, built: Obstacles.builtRects(state), wild: WildLand(state: state))
    }

    /// A planted tree's trunk.
    static func trunk(at tile: TileCoord) -> TileRect {
        let c = tile.center
        return TileRect(minX: c.x - 0.16, minY: c.y - 0.1, maxX: c.x + 0.16, maxY: c.y + 0.18)
    }

    /// True if a circle at `p` touches anything solid or the map's edge.
    public func blocks(_ p: Vec2, radius r: Double) -> Bool {
        if p.x - r < 0 || p.y - r < 0 || p.x + r > Double(map.width) || p.y + r > Double(map.height) { return true }
        func hits(_ rect: TileRect) -> Bool {
            let cx = min(max(p.x, rect.minX), rect.maxX)
            let cy = min(max(p.y, rect.minY), rect.maxY)
            let dx = p.x - cx, dy = p.y - cy
            return dx * dx + dy * dy < r * r
        }
        let x0 = Int((p.x - r).rounded(.down)), x1 = Int((p.x + r).rounded(.down))
        let y0 = Int((p.y - r).rounded(.down)), y1 = Int((p.y + r).rounded(.down))
        for ty in y0...y1 {
            for tx in x0...x1 {
                let tile = TileCoord(tx, ty)
                if wild.contains(tile), hits(TileRect(x: Double(tx), y: Double(ty), width: 1, height: 1)) { return true }
                if woodland.trees[tile] != nil, hits(Self.trunk(at: tile)) { return true }
                for index in map.colliderIndex(at: tile) {
                    let collider = map.colliders[index]
                    if let foot = collider.treeFoot, woodland.hiddenMapTrees.contains(foot) { continue }
                    if hits(collider.rect) { return true }
                }
            }
        }
        return built.contains(where: hits)
    }

    /// True if a circle can travel in a straight line from `a` to `b` without
    /// touching anything (checked every quarter tile).
    public func isClear(from a: Vec2, to b: Vec2, radius r: Double) -> Bool {
        let steps = max(1, Int((a.distance(to: b) / 0.25).rounded(.up)))
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            if blocks(a + (b - a) * t, radius: r) { return false }
        }
        return true
    }
}

extension Obstacles {
    /// Footprints of the farm's and the village's buildings (for the truck).
    public static func builtRects(_ state: GameState) -> [TileRect] {
        let estate = EstateLayout.standing(state.estate).map { MapObject(kind: $0.kind, position: $0.position) }
        let village = VillageLayout.standing(state).filter { VillageLayout.blocks($0.kind) }
        return (estate + village).compactMap { ObjectFootprint.collider(for: $0) }
    }
}
