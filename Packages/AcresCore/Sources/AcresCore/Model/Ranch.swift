import Foundation

/// One animal on the farm. Everything visible (grown up, hungry, has a
/// product) is derived from the stored inputs.
public struct AnimalState: Codable, Equatable, Sendable, Identifiable {
    public var id: Int
    public var speciesID: String
    public var name: String
    /// Real seconds since it arrived (young animals grow up at `growUpSeconds`).
    public var age: TimeInterval
    /// Progress toward the next product; nil while it waits to be fed.
    public var production: TimeInterval?
    /// 0…1. Regular meals with water in the trough make animals happy, and
    /// happy animals sometimes give a bonus product.
    public var happiness: Double

    public init(id: Int, speciesID: String, name: String, age: TimeInterval = 0,
                production: TimeInterval? = nil, happiness: Double = 0.5) {
        self.id = id
        self.speciesID = speciesID
        self.name = name
        self.age = age
        self.production = production
        self.happiness = happiness
    }

    public var species: AnimalSpecies? { AnimalCatalog.species(speciesID) }

    public var isAdult: Bool {
        guard let species else { return true }
        return age >= species.growUpSeconds
    }

    /// Grown up and waiting for a meal.
    public var isHungry: Bool { isAdult && production == nil }

    /// A product is waiting to be collected.
    public var hasProduct: Bool {
        guard let production, let species else { return false }
        return production >= species.produceSeconds
    }
}

/// One pen and the animals in it.
public struct PenState: Codable, Equatable, Sendable {
    public var isRepaired: Bool
    /// The trough holds water until this `worldTime`.
    public var waterUntil: TimeInterval
    /// Sorted by `id`.
    public var animals: [AnimalState]

    public init(isRepaired: Bool = false, waterUntil: TimeInterval = 0, animals: [AnimalState] = []) {
        self.isRepaired = isRepaired
        self.waterUntil = waterUntil
        self.animals = animals
    }

    public func hasWater(at time: TimeInterval) -> Bool { time < waterUntil }
}

/// All pens and animals. Pens that were never touched are absent.
public struct Ranch: Codable, Equatable, Sendable {
    public var pens: [String: PenState]
    public var nextAnimalID: Int

    public init(pens: [String: PenState] = [:], nextAnimalID: Int = 1) {
        self.pens = pens
        self.nextAnimalID = nextAnimalID
    }

    public subscript(penID: String) -> PenState {
        get { pens[penID] ?? PenState() }
        set { pens[penID] = newValue }
    }

    /// Every animal, pen by pen (sorted), for summaries.
    public var allAnimals: [AnimalState] {
        pens.keys.sorted().flatMap { pens[$0]!.animals }
    }

    public var isEmpty: Bool { pens.values.allSatisfy { $0.animals.isEmpty } }
}
