import Foundation

/// What a tap on a pen does.
public enum PenAction: Equatable, Sendable {
    case repair
    case collect
    case water
    case feed
}

public enum RanchFailure: Equatable, Sendable {
    case notYourLand
    case truckNotHere
    case locked(level: Int)
    case notEnoughMoney
    case notRepaired
    case alreadyRepaired
    case noAnimals
    case nothingToCollect
    case storageFull
    case alreadyWatered
    case nobodyHungry
    /// None of the foods this species eats is in storage.
    case noFeed(speciesID: String)
    case penFull
    case unknown
}

public enum RanchOutcome: Equatable, Sendable {
    case repaired(penID: String)
    /// Products collected (item → amount), total XP.
    case collected(items: [String: Int], xp: Int)
    case watered
    /// Animals fed, and what they ate (item → amount).
    case fed(animals: Int, eaten: [String: Int])
    case failed(RanchFailure)

    public var succeeded: Bool {
        if case .failed = self { return false }
        return true
    }
}

public struct RanchResult: Equatable, Sendable {
    public var outcome: RanchOutcome
    public var events: [SimEvent]
}

/// The rules of keeping animals. Pure functions over `GameState`.
///
/// One tap on a pen does the one sensible thing for the whole pen, in this
/// order: repair it (once), collect what's ready, fill the trough, feed the
/// hungry. Two or three taps look after a whole pen.
public struct Ranching: Sendable {
    public let balance: Balance

    public init(balance: Balance) {
        self.balance = balance
    }

    // MARK: Rules

    /// Own the land and park the truck there, like farming.
    public func accessProblem(_ pen: PenDefinition, in state: GameState) -> RanchFailure? {
        let tile = TileCoord(containing: pen.area.center)
        guard let property = PropertyCatalog.property(containing: tile),
              state.ownedProperties.contains(property.id) else { return .notYourLand }
        guard property.area.insetBy(-3).contains(state.truck.position) else { return .truckNotHere }
        return nil
    }

    public func suggestedAction(for pen: PenDefinition, in state: GameState) -> PenAction? {
        let penState = state.ranch[pen.id]
        guard penState.isRepaired else { return .repair }
        if penState.animals.contains(where: \.hasProduct) { return .collect }
        guard !penState.animals.isEmpty else { return nil }
        if !penState.hasWater(at: state.worldTime) { return .water }
        if penState.animals.contains(where: \.isHungry) { return .feed }
        return nil
    }

    public func perform(_ action: PenAction, on pen: PenDefinition, in state: inout GameState) -> RanchResult {
        if let problem = accessProblem(pen, in: state) { return fail(problem) }
        switch action {
        case .repair: return repair(pen, &state)
        case .collect: return collect(pen, &state)
        case .water: return water(pen, &state)
        case .feed: return feed(pen, &state)
        }
    }

    /// The food an animal of this species would eat now, if any.
    public func food(for species: AnimalSpecies, in inventory: Inventory) -> String? {
        species.feeds.first { inventory.count($0) > 0 }
    }

    // MARK: Actions

    private func fail(_ failure: RanchFailure) -> RanchResult {
        RanchResult(outcome: .failed(failure), events: [])
    }

    private func repair(_ pen: PenDefinition, _ state: inout GameState) -> RanchResult {
        var penState = state.ranch[pen.id]
        guard !penState.isRepaired else { return fail(.alreadyRepaired) }
        guard state.progress.level >= pen.unlockLevel else { return fail(.locked(level: pen.unlockLevel)) }
        guard state.money >= pen.repairCost else { return fail(.notEnoughMoney) }
        state.money -= pen.repairCost
        penState.isRepaired = true
        // Fresh water comes with the repair.
        penState.waterUntil = state.worldTime + balance.troughWaterDuration
        state.ranch[pen.id] = penState
        return RanchResult(outcome: .repaired(penID: pen.id), events: [])
    }

    private func collect(_ pen: PenDefinition, _ state: inout GameState) -> RanchResult {
        var penState = state.ranch[pen.id]
        guard penState.isRepaired else { return fail(.notRepaired) }
        var collected: [String: Int] = [:]
        var xp = 0
        var storageFull = false
        for index in penState.animals.indices where penState.animals[index].hasProduct {
            var animal = penState.animals[index]
            guard let species = animal.species else { continue }
            // Roll on a copy: a product left behind for lack of space keeps its luck.
            var rng = state.rng
            let amount = 1 + (rng.nextUnit() < Self.bonusChance(happiness: animal.happiness) ? 1 : 0)
            guard state.inventory.storageUsed + amount <= balance.storageCapacity else {
                storageFull = true
                break
            }
            state.rng = rng
            state.inventory.add(species.productItemID, amount)
            collected[species.productItemID, default: 0] += amount
            xp += species.xp
            animal.production = nil  // hungry again
            penState.animals[index] = animal
        }
        guard !collected.isEmpty else { return fail(storageFull ? .storageFull : .nothingToCollect) }
        state.ranch[pen.id] = penState
        let events = Progression.addXP(xp, to: &state, balance: balance)
        return RanchResult(outcome: .collected(items: collected, xp: xp), events: events)
    }

    private func water(_ pen: PenDefinition, _ state: inout GameState) -> RanchResult {
        var penState = state.ranch[pen.id]
        guard penState.isRepaired else { return fail(.notRepaired) }
        guard !penState.hasWater(at: state.worldTime) else { return fail(.alreadyWatered) }
        penState.waterUntil = state.worldTime + balance.troughWaterDuration
        state.ranch[pen.id] = penState
        return RanchResult(outcome: .watered, events: [])
    }

    private func feed(_ pen: PenDefinition, _ state: inout GameState) -> RanchResult {
        var penState = state.ranch[pen.id]
        guard penState.isRepaired else { return fail(.notRepaired) }
        guard penState.animals.contains(where: \.isHungry) else { return fail(.nobodyHungry) }
        let hasWater = penState.hasWater(at: state.worldTime)
        var eaten: [String: Int] = [:]
        var fed = 0
        for index in penState.animals.indices where penState.animals[index].isHungry {
            var animal = penState.animals[index]
            guard let species = animal.species, let food = food(for: species, in: state.inventory) else { continue }
            state.inventory.remove(food, 1)
            eaten[food, default: 0] += 1
            fed += 1
            animal.production = 0
            animal.happiness = min(1, animal.happiness + balance.happinessPerFeeding * (hasWater ? 1 : 0.5))
            penState.animals[index] = animal
        }
        guard fed > 0 else { return fail(.noFeed(speciesID: pen.speciesID)) }
        state.ranch[pen.id] = penState
        return RanchResult(outcome: .fed(animals: fed, eaten: eaten), events: [])
    }

    // MARK: Helpers

    /// Chance of a second product: none below ⅓ happiness, certain at full.
    public static func bonusChance(happiness: Double) -> Double {
        min(1, max(0, happiness * 1.5 - 0.5))
    }

    /// Adds a newly bought young animal to its pen (the shop checks the rules).
    /// Names come from the species' list; repeats get a number.
    static func addYoungAnimal(_ species: AnimalSpecies, to penID: String, in state: inout GameState, balance: Balance) -> AnimalState {
        var pen = state.ranch[penID]
        let taken = Set(state.ranch.allAnimals.map(\.name))
        let start = species.names.isEmpty ? 0 : Int(state.rng.nextUnit() * Double(species.names.count)) % species.names.count
        var name = species.youngName
        search: for round in 1...99 {
            for offset in 0..<species.names.count {
                let base = species.names[(start + offset) % species.names.count]
                let candidate = round == 1 ? base : "\(base) \(round)"
                if !taken.contains(candidate) {
                    name = candidate
                    break search
                }
            }
        }
        let animal = AnimalState(id: state.ranch.nextAnimalID, speciesID: species.id, name: name,
                                 happiness: balance.newAnimalHappiness)
        state.ranch.nextAnimalID += 1
        pen.animals.append(animal)
        state.ranch[penID] = pen
        return animal
    }
}
