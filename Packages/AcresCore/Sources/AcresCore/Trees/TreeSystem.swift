import Foundation

/// Grows planted trees, sprouts stumps again and ripens fruit. Runs on real
/// time, online and offline. Wild trees that were never touched are always
/// full-grown and need no simulation.
///
/// Exact for any step size: each tree walks through its phases (stump →
/// sapling → full-grown → fruit) carrying the leftover time along.
public struct TreeSystem: SimulationSystem {
    public init() {}

    public var handlesAnyStepSize: Bool { true }

    public func step(_ state: inout GameState, _ context: inout StepContext) {
        guard !state.woodland.trees.isEmpty else { return }
        let dt = context.dt
        let regrow = context.balance.stumpRegrowSeconds
        var grown: [TileCoord] = []
        var fruited: [TileCoord] = []

        state.woodland.updateEach { tree in
            guard let species = tree.species else { return }
            var remaining = dt
            if let age = tree.stumpAge {
                let left = regrow - age
                if remaining < left {
                    tree.stumpAge = age + remaining
                    return
                }
                // Sprouts again as a sapling of the same kind.
                remaining -= max(0, left)
                tree.stumpAge = nil
                tree.growth = 0
                tree.fruit = 0
            }
            if tree.growth < species.growSeconds {
                let needed = species.growSeconds - tree.growth
                if remaining < needed {
                    tree.growth += remaining
                    return
                }
                tree.growth = species.growSeconds
                remaining -= needed
                grown.append(tree.tile)
            }
            if species.isFruitTree && tree.fruit < species.fruitSeconds {
                tree.fruit = min(species.fruitSeconds, tree.fruit + remaining)
                if tree.fruit >= species.fruitSeconds { fruited.append(tree.tile) }
            }
        }

        // Dictionary order is random per launch; sort so events are deterministic.
        let order: (TileCoord, TileCoord) -> Bool = { $0.y != $1.y ? $0.y > $1.y : $0.x < $1.x }
        context.events += grown.sorted(by: order).map { SimEvent.treeGrown($0) }
        context.events += fruited.sorted(by: order).map { SimEvent.fruitReady($0) }
    }
}
