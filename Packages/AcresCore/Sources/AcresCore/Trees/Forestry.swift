import Foundation

public enum TreeAction: Equatable, Sendable {
    case chop
    case clearStump
    case pickFruit
    case plant(speciesID: String)
}

public enum TreeFailure: Equatable, Sendable {
    case notYourLand
    case tooFar
    case tooTired
    case noTree
    case notGrown
    case noFruit
    case notPlowed
    case occupied
    case noSaplings(speciesID: String)
    case storageFull
    case unknown
}

public enum TreeOutcome: Equatable, Sendable {
    case chopped(speciesID: String, logs: Int, xp: Int)
    case stumpCleared(xp: Int)
    case picked(itemID: String, amount: Int, xp: Int)
    case planted(speciesID: String)
    case failed(TreeFailure)

    public var succeeded: Bool {
        if case .failed = self { return false }
        return true
    }
}

public struct TreeResult: Equatable, Sendable {
    public var outcome: TreeOutcome
    public var events: [SimEvent]
}

/// A tree as the player sees it: a wild map tree or a record.
public struct TreeInfo: Equatable, Sendable {
    public let tile: TileCoord
    /// Where the trunk stands (tile units).
    public let position: Vec2
    /// nil for old wild stumps whose kind nobody remembers.
    public let speciesID: String?
    public let stage: TreeStage
    public let isWild: Bool
    public let record: TreeState?

    public var species: TreeSpecies? { speciesID.flatMap { TreeCatalog.species($0) } }
    public var hasFruit: Bool { record?.hasFruit ?? false }

    /// The picture used for it (sizes for hit testing come from the manifest).
    public var assetName: String {
        guard let speciesID else { return "tree_stump" }
        switch stage {
        case .sapling: return "tree_\(speciesID)_sapling"
        case .young: return "tree_\(speciesID)_young"
        case .mature: return "tree_\(speciesID)_summer"
        case .stump: return "tree_stump"
        }
    }
}

/// The rules of trees: chop full-grown ones for logs, clear stumps, pick
/// fruit and plant saplings on plowed soil. Pure functions over `GameState`.
public struct Forestry: Sendable {
    public let map: WorldMap
    public let balance: Balance

    public init(map: WorldMap, balance: Balance) {
        self.map = map
        self.balance = balance
    }

    // MARK: Looking

    /// The tree standing on a tile (by trunk), if any.
    public func tree(at tile: TileCoord, in state: GameState) -> TreeInfo? {
        if let record = state.woodland[tile] {
            return TreeInfo(tile: tile, position: position(of: tile), speciesID: record.speciesID,
                            stage: record.stage, isWild: false, record: record)
        }
        guard !state.woodland.hiddenMapTrees.contains(tile),
              let object = map.treesByFoot[tile]?.first else { return nil }
        let species = TreeCatalog.species(forMapKind: object.kind)
        return TreeInfo(tile: tile, position: object.position, speciesID: species?.id,
                        stage: species == nil ? .stump : .mature, isWild: true, record: nil)
    }

    /// Where a tree on this tile stands: where the wild tree stood, or the tile center.
    public func position(of tile: TileCoord) -> Vec2 {
        map.treesByFoot[tile]?.first?.position ?? tile.center
    }

    /// The tree whose picture covers a point (the front-most one), for taps.
    /// Only the trunk and the middle of the crown count, so taps near the
    /// edges still reach the ground behind.
    public func treeTile(at point: Vec2, in state: GameState) -> TileCoord? {
        var best: (tile: TileCoord, footY: Double)?
        let px = Int(point.x.rounded(.down)), py = Int(point.y.rounded(.down))
        for y in (py - 5)...(py + 1) {
            for x in (px - 2)...(px + 2) {
                let tile = TileCoord(x, y)
                guard let info = tree(at: tile, in: state), let spec = AssetManifest.spec(named: info.assetName) else { continue }
                let halfWidth = max(0.4, spec.tilesWide * 0.36)
                let bottom = info.position.y - spec.tilesHigh * spec.anchorY
                let top = bottom + spec.tilesHigh * 0.92
                guard abs(point.x - info.position.x) <= halfWidth, point.y >= bottom, point.y <= top else { continue }
                if best == nil || info.position.y < best!.footY { best = (tile, info.position.y) }
            }
        }
        return best?.tile
    }

    // MARK: Rules

    public func accessProblem(at tile: TileCoord, in state: GameState, checkReach: Bool = true) -> TreeFailure? {
        guard let property = PropertyCatalog.property(containing: tile),
              state.ownedProperties.contains(property.id) else { return .notYourLand }
        if checkReach {
            guard !state.farmer.inTruck,
                  state.farmer.position.distance(to: position(of: tile)) <= balance.workReach + 0.3 else { return .tooFar }
        }
        return nil
    }

    /// Where the farmer stands to work a tree: just in front of the trunk.
    public func workSpot(for tile: TileCoord, in state: GameState) -> Vec2 {
        let trunk = position(of: tile)
        return Vec2(trunk.x, trunk.y - 0.9)
    }

    /// What a tap on a tree does: chop full-grown wood trees, clear stumps,
    /// pick ripe fruit. Fruit trees are never chopped by a tap (the info card
    /// offers it), and growing trees are left alone.
    public func suggestedAction(at tile: TileCoord, in state: GameState, checkReach: Bool = true) -> TreeAction? {
        guard accessProblem(at: tile, in: state, checkReach: checkReach) == nil, let info = tree(at: tile, in: state) else { return nil }
        switch info.stage {
        case .stump: return .clearStump
        case .sapling, .young: return nil
        case .mature:
            guard let species = info.species else { return nil }
            if species.isFruitTree { return info.hasFruit ? .pickFruit : nil }
            return .chop
        }
    }

    // MARK: Actions

    public func perform(_ action: TreeAction, at tile: TileCoord, in state: inout GameState) -> TreeResult {
        // Planting happens on plowed soil, reached like any field tile.
        if case .plant = action {
            guard PropertyCatalog.property(containing: tile).map({ state.ownedProperties.contains($0.id) }) == true else {
                return fail(.notYourLand)
            }
            guard !state.farmer.inTruck, state.farmer.position.distance(to: tile.center) <= balance.workReach else { return fail(.tooFar) }
        } else if let problem = accessProblem(at: tile, in: state) {
            return fail(problem)
        }
        let cost: Double = switch action {
        case .chop: balance.energyCost.chop
        case .clearStump: balance.energyCost.clearStump
        case .pickFruit: balance.energyCost.pickFruit
        case .plant: balance.energyCost.plantTree
        }
        guard state.farmer.energy >= cost else { return fail(.tooTired) }
        let result: TreeResult
        switch action {
        case .chop: result = chop(tile, &state)
        case .clearStump: result = clearStump(tile, &state)
        case .pickFruit: result = pickFruit(tile, &state)
        case .plant(let speciesID): result = plant(speciesID, tile, &state)
        }
        if result.outcome.succeeded {
            state.farmer.energy = max(0, state.farmer.energy - cost)
            switch result.outcome {
            case .chopped: state.goals.add(GoalCounter.treesChopped)
            case .picked(let item, let amount, _): state.goals.add(GoalCounter.collected(item), amount)
            case .planted(let id) where TreeCatalog.species(id)?.isFruitTree == true: state.goals.add(GoalCounter.fruitTreesPlanted)
            default: break
            }
        }
        return result
    }

    private func fail(_ failure: TreeFailure) -> TreeResult {
        TreeResult(outcome: .failed(failure), events: [])
    }

    private func chop(_ tile: TileCoord, _ state: inout GameState) -> TreeResult {
        guard let info = tree(at: tile, in: state) else { return fail(.noTree) }
        guard info.stage == .mature, let species = info.species else { return fail(.notGrown) }
        var rng = state.rng
        let logs = roll(species.logs, &rng)
        guard state.inventory.storageUsed + logs <= state.storageCapacity(balance) else { return fail(.storageFull) }
        state.rng = rng
        state.inventory.add("log", logs)
        if info.isWild { state.woodland.hiddenMapTrees.insert(tile) }
        // A stump stays behind; left alone, it sprouts again.
        state.woodland[tile] = TreeState(tile: tile, speciesID: species.id, growth: species.growSeconds, stumpAge: 0)
        let events = Progression.addXP(species.chopXP, to: &state, balance: balance)
        return TreeResult(outcome: .chopped(speciesID: species.id, logs: logs, xp: species.chopXP), events: events)
    }

    private func clearStump(_ tile: TileCoord, _ state: inout GameState) -> TreeResult {
        guard let info = tree(at: tile, in: state), info.stage == .stump else { return fail(.noTree) }
        state.woodland[tile] = nil
        if info.isWild || map.treesByFoot[tile] != nil { state.woodland.hiddenMapTrees.insert(tile) }
        let xp = balance.stumpRemovalXP
        let events = Progression.addXP(xp, to: &state, balance: balance)
        return TreeResult(outcome: .stumpCleared(xp: xp), events: events)
    }

    private func pickFruit(_ tile: TileCoord, _ state: inout GameState) -> TreeResult {
        guard var record = state.woodland[tile], let species = record.species,
              let fruitID = species.fruitItemID else { return fail(.noTree) }
        guard record.hasFruit else { return fail(.noFruit) }
        var rng = state.rng
        let amount = roll(species.fruitYield, &rng)
        guard state.inventory.storageUsed + amount <= state.storageCapacity(balance) else { return fail(.storageFull) }
        state.rng = rng
        state.inventory.add(fruitID, amount)
        record.fruit = 0
        state.woodland[tile] = record
        let events = Progression.addXP(species.fruitXP, to: &state, balance: balance)
        return TreeResult(outcome: .picked(itemID: fruitID, amount: amount, xp: species.fruitXP), events: events)
    }

    /// Saplings go into plowed, empty soil; the plot becomes the tree's spot.
    private func plant(_ speciesID: String, _ tile: TileCoord, _ state: inout GameState) -> TreeResult {
        guard let species = TreeCatalog.species(speciesID) else { return fail(.unknown) }
        guard let plot = state.plots[tile] else { return fail(.notPlowed) }
        guard plot.crop == nil, state.woodland[tile] == nil else { return fail(.occupied) }
        guard state.inventory.remove(species.saplingItemID, 1) else { return fail(.noSaplings(speciesID: speciesID)) }
        state.plots[tile] = nil
        state.woodland[tile] = TreeState(tile: tile, speciesID: speciesID)
        return TreeResult(outcome: .planted(speciesID: speciesID), events: [])
    }

    private func roll(_ range: ClosedRange<Int>, _ rng: inout SeededRandom) -> Int {
        range.lowerBound + Int(rng.nextUnit() * Double(range.count)) % range.count
    }
}
