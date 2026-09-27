import Foundation

/// What's solid right now: the map's buildings, rocks and pens, plus trees as
/// the player has changed them (chopped trees leave stumps, cleared ones are
/// gone, planted ones take up their tile).
///
/// Used by farming (can't plow here), driving (collisions) and the route
/// planner. Cheap to create: it only borrows the map and the woodland.
public struct Obstacles: Sendable {
    public let map: WorldMap
    public let woodland: Woodland

    public init(map: WorldMap, woodland: Woodland) {
        self.map = map
        self.woodland = woodland
    }

    public init(map: WorldMap, state: GameState) {
        self.init(map: map, woodland: state.woodland)
    }

    public func isBlocked(_ tile: TileCoord) -> Bool {
        if map.solidTiles.contains(tile) { return true }
        if woodland.trees[tile] != nil { return true }
        guard let feet = map.treeCover[tile] else { return false }
        return feet.contains { !woodland.hiddenMapTrees.contains($0) }
    }
}
