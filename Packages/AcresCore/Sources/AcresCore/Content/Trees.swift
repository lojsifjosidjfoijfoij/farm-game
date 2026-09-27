import Foundation

/// Everything the game knows about one kind of tree.
public struct TreeSpecies: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    /// Real seconds from sapling to a full-grown tree.
    public let growSeconds: TimeInterval
    /// Logs from chopping a full-grown tree.
    public let logs: ClosedRange<Int>
    public let chopXP: Int
    /// Price of a sapling at the seed shop.
    public let saplingCost: Int
    public let unlockLevel: Int
    /// Fruit trees: what they bear, how often, how much.
    public let fruitItemID: String?
    public let fruitSeconds: TimeInterval
    public let fruitYield: ClosedRange<Int>
    public let fruitXP: Int

    public init(
        id: String, name: String, growSeconds: TimeInterval, logs: ClosedRange<Int>, chopXP: Int,
        saplingCost: Int, unlockLevel: Int, fruitItemID: String? = nil, fruitSeconds: TimeInterval = 0,
        fruitYield: ClosedRange<Int> = 0...0, fruitXP: Int = 0
    ) {
        self.id = id
        self.name = name
        self.growSeconds = growSeconds
        self.logs = logs
        self.chopXP = chopXP
        self.saplingCost = saplingCost
        self.unlockLevel = unlockLevel
        self.fruitItemID = fruitItemID
        self.fruitSeconds = fruitSeconds
        self.fruitYield = fruitYield
        self.fruitXP = fruitXP
    }

    public var saplingItemID: String { "sapling_\(id)" }
    public var isFruitTree: Bool { fruitItemID != nil }

    /// Visible growth stage for an amount of growth.
    public func stage(forGrowth growth: TimeInterval) -> TreeStage {
        if growth >= growSeconds { return .mature }
        return growth < growSeconds * 0.4 ? .sapling : .young
    }
}

public enum TreeStage: String, Sendable, Equatable {
    case sapling
    case young
    case mature
    case stump
}

/// All trees. Wild trees on the map are full-grown birches, oaks and pines;
/// saplings of every kind are sold at the seed shop.
public enum TreeCatalog {
    public static let all: [TreeSpecies] = [
        TreeSpecies(id: "birch", name: "Birch", growSeconds: GameTime.days(3), logs: 2...3, chopXP: 2,
                    saplingCost: 15, unlockLevel: 2),
        TreeSpecies(id: "pine", name: "Pine", growSeconds: GameTime.days(5), logs: 3...4, chopXP: 3,
                    saplingCost: 25, unlockLevel: 3),
        TreeSpecies(id: "oak", name: "Oak", growSeconds: GameTime.days(8), logs: 4...6, chopXP: 5,
                    saplingCost: 40, unlockLevel: 5),
        TreeSpecies(id: "apple", name: "Apple tree", growSeconds: GameTime.days(6), logs: 2...2, chopXP: 2,
                    saplingCost: 90, unlockLevel: 3,
                    fruitItemID: "apple", fruitSeconds: GameTime.days(2), fruitYield: 3...5, fruitXP: 3),
        TreeSpecies(id: "cherry", name: "Cherry tree", growSeconds: GameTime.days(9), logs: 2...2, chopXP: 2,
                    saplingCost: 150, unlockLevel: 6,
                    fruitItemID: "cherry", fruitSeconds: GameTime.days(3), fruitYield: 4...6, fruitXP: 5),
    ]

    private static let index: [String: TreeSpecies] = {
        var result: [String: TreeSpecies] = [:]
        for species in all { result[species.id] = species }
        return result
    }()

    public static func species(_ id: String) -> TreeSpecies? { index[id] }

    /// The species of a wild map tree (`tree_oak` → oak); nil for other objects.
    public static func species(forMapKind kind: String) -> TreeSpecies? {
        guard kind.hasPrefix("tree_") else { return nil }
        return species(String(kind.dropFirst(5)))
    }

    /// Map object kinds that are trees (or old stumps) the player can clear.
    public static func isMapTree(_ kind: String) -> Bool {
        kind == "tree_stump" || species(forMapKind: kind) != nil
    }
}
