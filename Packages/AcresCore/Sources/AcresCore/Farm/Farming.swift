import Foundation

/// Something the player does to a tile.
public enum FarmAction: Equatable, Sendable {
    case plow
    case plant(cropID: String)
    case water
    case harvest

    public enum Kind: Equatable, Sendable { case plow, plant, water, harvest }

    public var kind: Kind {
        switch self {
        case .plow: .plow
        case .plant: .plant
        case .water: .water
        case .harvest: .harvest
        }
    }
}

/// Why an action could not happen. The UI turns these into friendly messages.
public enum FarmFailure: Equatable, Sendable {
    case notYourLand
    /// The farmer has to walk over first (or get out of the truck).
    case tooFar
    /// Out of energy: time to sleep.
    case tooTired
    case cannotPlowHere
    case alreadyPlowed
    case notPlowed
    case alreadyPlanted
    case unknownCrop
    case noSeeds(cropID: String)
    case outOfSeason(cropID: String, season: Season)
    case nothingToWater
    case alreadyWet
    case notReady
    case storageFull
}

/// What happened, for feedback (particles, sounds, haptics).
public enum FarmOutcome: Equatable, Sendable {
    case plowed
    case planted(cropID: String)
    case watered
    case harvested(cropID: String, amount: Int, xp: Int)
    case failed(FarmFailure)

    public var succeeded: Bool {
        if case .failed = self { return false }
        return true
    }
}

/// The result of performing an action: the outcome plus any events it caused
/// (e.g. a level-up).
public struct FarmResult: Equatable, Sendable {
    public var outcome: FarmOutcome
    public var events: [SimEvent]
}

/// The rules of farming. Pure functions over `GameState`; the map supplies
/// terrain and obstacles.
public struct Farming: Sendable {
    public let map: WorldMap
    public let balance: Balance

    public init(map: WorldMap, balance: Balance) {
        self.map = map
        self.balance = balance
    }

    // MARK: Rules

    /// Can the farmer work this tile? They must own the land and stand within
    /// reach, on foot. Planning (which job a tap means) skips the reach check:
    /// the farmer walks over first.
    public func accessProblem(at tile: TileCoord, in state: GameState, checkReach: Bool = true) -> FarmFailure? {
        guard let property = PropertyCatalog.property(containing: tile),
              state.ownedProperties.contains(property.id) else { return .notYourLand }
        if checkReach {
            guard !state.farmer.inTruck,
                  state.farmer.position.distance(to: tile.center) <= balance.workReach else { return .tooFar }
        }
        return nil
    }

    /// Why this tile can't be plowed, or nil if it can.
    public func plowProblem(at tile: TileCoord, in state: GameState, checkReach: Bool = true) -> FarmFailure? {
        if let problem = accessProblem(at: tile, in: state, checkReach: checkReach) { return problem }
        if state.plots[tile] != nil { return .alreadyPlowed }
        if Obstacles(map: map, state: state).isBlocked(tile) { return .cannotPlowHere }
        switch map.terrain(at: tile) {
        case .grass, .dirt: break
        case .gravel, .asphalt: return .cannotPlowHere
        }
        if Self.truckFootprint(state.truck).contains(tile.center) { return .cannotPlowHere }
        if state.woodland[tile] != nil { return .cannotPlowHere }
        return nil
    }

    /// The single most sensible action for a tap on this tile, or nil if
    /// there is nothing to do (e.g. a crop that is growing in wet soil).
    /// `seed` is the crop the player would plant on empty soil.
    public func suggestedAction(at tile: TileCoord, in state: GameState, seed: String?, checkReach: Bool = true) -> FarmAction? {
        guard accessProblem(at: tile, in: state, checkReach: checkReach) == nil else { return nil }
        guard let plot = state.plots[tile] else {
            return plowProblem(at: tile, in: state, checkReach: checkReach) == nil ? .plow : nil
        }
        guard let crop = plot.crop else {
            return seed.map { .plant(cropID: $0) }
        }
        if crop.isReady { return .harvest }
        if !plot.isWet(at: state.worldTime) { return .water }
        return nil
    }

    // MARK: Actions

    public func perform(_ action: FarmAction, at tile: TileCoord, in state: inout GameState) -> FarmResult {
        let cost = balance.energyCost.cost(of: action.kind)
        if accessProblem(at: tile, in: state) == nil, state.farmer.energy < cost { return fail(.tooTired) }
        let result: FarmResult
        switch action {
        case .plow: result = plow(tile, &state)
        case .plant(let cropID): result = plant(cropID, tile, &state)
        case .water: result = water(tile, &state)
        case .harvest: result = harvest(tile, &state)
        }
        if result.outcome.succeeded {
            state.farmer.energy = max(0, state.farmer.energy - cost)
            switch result.outcome {
            case .plowed: state.goals.add(GoalCounter.plowed)
            case .planted: state.goals.add(GoalCounter.planted)
            case .watered: state.goals.add(GoalCounter.watered)
            case .harvested(_, let amount, _): state.goals.add(GoalCounter.harvested, amount)
            case .failed: break
            }
        }
        return result
    }

    private func fail(_ failure: FarmFailure) -> FarmResult {
        FarmResult(outcome: .failed(failure), events: [])
    }

    private func plow(_ tile: TileCoord, _ state: inout GameState) -> FarmResult {
        if let problem = plowProblem(at: tile, in: state) { return fail(problem) }
        state.plots[tile] = Plot(tile: tile)
        return FarmResult(outcome: .plowed, events: [])
    }

    private func plant(_ cropID: String, _ tile: TileCoord, _ state: inout GameState) -> FarmResult {
        if let problem = accessProblem(at: tile, in: state) { return fail(problem) }
        guard var plot = state.plots[tile] else { return fail(.notPlowed) }
        guard plot.crop == nil else { return fail(.alreadyPlanted) }
        guard let def = CropCatalog.crop(cropID) else { return fail(.unknownCrop) }
        let season = state.clock.date(daysPerSeason: balance.daysPerSeason).season
        guard def.canBePlanted(in: season) else { return fail(.outOfSeason(cropID: cropID, season: season)) }
        guard state.inventory.remove(def.seedItemID, 1) else { return fail(.noSeeds(cropID: cropID)) }
        plot.crop = PlantedCrop(cropID: cropID, plantedAt: state.worldTime)
        state.plots[tile] = plot
        return FarmResult(outcome: .planted(cropID: cropID), events: [])
    }

    private func water(_ tile: TileCoord, _ state: inout GameState) -> FarmResult {
        if let problem = accessProblem(at: tile, in: state) { return fail(problem) }
        guard var plot = state.plots[tile] else { return fail(.notPlowed) }
        guard let crop = plot.crop, !crop.isReady else { return fail(.nothingToWater) }
        guard !plot.isWet(at: state.worldTime) else { return fail(.alreadyWet) }
        plot.wetUntil = state.worldTime + balance.soilWetDuration
        state.plots[tile] = plot
        return FarmResult(outcome: .watered, events: [])
    }

    private func harvest(_ tile: TileCoord, _ state: inout GameState) -> FarmResult {
        if let problem = accessProblem(at: tile, in: state) { return fail(problem) }
        guard var plot = state.plots[tile], var crop = plot.crop else { return fail(.notReady) }
        guard let def = crop.definition, crop.isReady else { return fail(.notReady) }

        // Roll the yield on a copy of the RNG: a harvest refused for lack of
        // space must not change the outcome of the next attempt.
        var rng = state.rng
        let amount = def.yield.lowerBound + Int(rng.nextUnit() * Double(def.yield.count)) % def.yield.count
        guard state.inventory.storageUsed + amount <= balance.storageCapacity else { return fail(.storageFull) }
        state.rng = rng

        state.inventory.add(def.produceItemID, amount)
        if let regrow = def.regrowSeconds {
            crop.growth = max(0, def.growthSeconds - regrow)
            crop.wateredGrowth = 0
            crop.harvests += 1
            plot.crop = crop
        } else {
            plot.crop = nil
        }
        state.plots[tile] = plot
        let events = Progression.addXP(def.xp, to: &state, balance: balance)
        return FarmResult(outcome: .harvested(cropID: def.id, amount: amount, xp: def.xp), events: events)
    }

    // MARK: Helpers

    /// Ground covered by the parked truck (can't plow under it).
    static func truckFootprint(_ truck: TruckState) -> TileRect {
        TileRect(minX: truck.position.x - 1.2, minY: truck.position.y - 0.6,
                 maxX: truck.position.x + 1.2, maxY: truck.position.y + 0.6)
    }

    /// Seed items in the pouch that can be planted this season, most plentiful first.
    public func plantableSeeds(in state: GameState) -> [CropDefinition] {
        let season = state.clock.date(daysPerSeason: balance.daysPerSeason).season
        return CropCatalog.all
            .filter { $0.canBePlanted(in: season) && state.inventory.count($0.seedItemID) > 0 }
    }
}
