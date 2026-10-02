import Foundation

/// What's solid right now: the map's buildings, rocks and pens, plus trees as
/// the player has changed them (chopped trees leave stumps, cleared ones are
/// gone, planted ones take up their tile), and brush over land the farm
/// can't use yet (`WildLand`).
///
/// Used by farming (can't plow here), driving (collisions) and the route
/// planner. Cheap to create: it only borrows the map and the woodland.
public struct Obstacles: Sendable {
    public let map: WorldMap
    public let woodland: Woodland
    /// Tiles under the player's own buildings (storage shed, silos) and the
    /// village projects.
    public let built: Set<TileCoord>
    public let wild: WildLand

    public init(map: WorldMap, woodland: Woodland, built: Set<TileCoord> = [], wild: WildLand = .none) {
        self.map = map
        self.woodland = woodland
        self.built = built
        self.wild = wild
    }

    public init(map: WorldMap, state: GameState) {
        self.init(map: map, woodland: state.woodland, built: Self.built(state), wild: WildLand(state: state))
    }

    /// What the farm and the village have built since the map was drawn.
    public static func built(_ state: GameState) -> Set<TileCoord> {
        EstateLayout.blockedTiles(state.estate).union(VillageLayout.blockedTiles(state))
    }

    public func isBlocked(_ tile: TileCoord) -> Bool {
        if map.solidTiles.contains(tile) { return true }
        if built.contains(tile) { return true }
        if wild.contains(tile) { return true }
        if woodland.trees[tile] != nil { return true }
        guard let feet = map.treeCover[tile] else { return false }
        return feet.contains { !woodland.hiddenMapTrees.contains($0) }
    }
}
