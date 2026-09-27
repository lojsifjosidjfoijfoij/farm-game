import Foundation

/// A tree the player has planted or changed (chopped, regrowing). Wild map
/// trees that were never touched have no record: they're simply full-grown.
public struct TreeState: Codable, Equatable, Sendable {
    /// The tile its trunk stands on (its key in `Woodland`).
    public var tile: TileCoord
    public var speciesID: String
    /// Seconds of growth toward full size (capped at the species' `growSeconds`).
    public var growth: TimeInterval
    /// Non-nil while it's a stump: seconds since it was chopped. It sprouts
    /// again as a sapling after `Balance.stumpRegrowSeconds`.
    public var stumpAge: TimeInterval?
    /// Fruit trees: progress toward the next fruit (full-grown trees only).
    public var fruit: TimeInterval

    public init(tile: TileCoord, speciesID: String, growth: TimeInterval = 0,
                stumpAge: TimeInterval? = nil, fruit: TimeInterval = 0) {
        self.tile = tile
        self.speciesID = speciesID
        self.growth = growth
        self.stumpAge = stumpAge
        self.fruit = fruit
    }

    public var species: TreeSpecies? { TreeCatalog.species(speciesID) }

    public var stage: TreeStage {
        if stumpAge != nil { return .stump }
        return species?.stage(forGrowth: growth) ?? .mature
    }

    public var hasFruit: Bool {
        guard stage == .mature, let species, species.isFruitTree else { return false }
        return fruit >= species.fruitSeconds
    }
}

/// The player's changes to the trees of the world.
public struct Woodland: Equatable, Sendable {
    /// Planted, chopped and regrowing trees by trunk tile.
    public private(set) var trees: [TileCoord: TreeState]
    /// Tiles whose wild map trees (or old stumps) are no longer shown: they
    /// were chopped (a record took over) or cleared away for good.
    public var hiddenMapTrees: Set<TileCoord>

    public init(trees: [TreeState] = [], hiddenMapTrees: Set<TileCoord> = []) {
        var byTile: [TileCoord: TreeState] = [:]
        for tree in trees { byTile[tree.tile] = tree }
        self.trees = byTile
        self.hiddenMapTrees = hiddenMapTrees
    }

    public subscript(tile: TileCoord) -> TreeState? {
        get { trees[tile] }
        set {
            if var tree = newValue {
                tree.tile = tile
                trees[tile] = tree
            } else {
                trees[tile] = nil
            }
        }
    }

    public var isEmpty: Bool { trees.isEmpty && hiddenMapTrees.isEmpty }

    /// Records sorted north-to-south, west-to-east (deterministic order).
    public var sorted: [TreeState] {
        trees.values.sorted { a, b in a.tile.y != b.tile.y ? a.tile.y > b.tile.y : a.tile.x < b.tile.x }
    }

    /// Mutates every record in place (fast path for the tree system).
    public mutating func updateEach(_ body: (inout TreeState) -> Void) {
        var index = trees.values.startIndex
        while index != trees.values.endIndex {
            body(&trees.values[index])
            index = trees.values.index(after: index)
        }
    }
}

extension Woodland: Codable {
    private enum CodingKeys: String, CodingKey { case trees, hiddenMapTrees }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(trees: try container.decode([TreeState].self, forKey: .trees),
                  hiddenMapTrees: Set(try container.decode([TileCoord].self, forKey: .hiddenMapTrees)))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sorted, forKey: .trees)
        try container.encode(hiddenMapTrees.sorted { $0.y != $1.y ? $0.y > $1.y : $0.x < $1.x }, forKey: .hiddenMapTrees)
    }
}
