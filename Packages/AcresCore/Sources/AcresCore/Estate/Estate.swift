import Foundation

// MARK: - Content

/// Something you buy and place on the farm.
public struct MachineDefinition: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let plural: String
    public let icon: String
    public let price: Int
    public let unlockLevel: Int
    /// Tiles covered around it (1 = the 3 × 3 square).
    public let radius: Int
    public let blurb: String
}

public enum MachineCatalog {
    public static let all: [MachineDefinition] = [
        MachineDefinition(id: "sprinkler", name: "Sprinkler", plural: "sprinklers", icon: "item_sprinkler", price: 450,
                          unlockLevel: 3, radius: 1, blurb: "Keeps the 8 tiles around it watered, day and night."),
        MachineDefinition(id: "sprinkler_pro", name: "Big sprinkler", plural: "big sprinklers", icon: "item_sprinkler_pro",
                          price: 1_500, unlockLevel: 7, radius: 2, blurb: "Waters a 5 × 5 square around it."),
    ]

    public static func machine(_ id: String) -> MachineDefinition? { all.first { $0.id == id } }
}

/// Buildings that come with storage upgrades, south of the farm fence by the
/// road (outside the fields, so they never stand on farmland).
public enum EstateLayout {
    public struct Building: Sendable, Equatable {
        public let kind: String
        /// Foot point (tile units), like map objects.
        public let position: Vec2
        /// Storage level from which it stands.
        public let fromLevel: Int
    }

    public static let buildings: [Building] = [
        Building(kind: "building_storage_shed", position: Vec2(33, 24.4), fromLevel: 1),
        Building(kind: "building_silo", position: Vec2(37.2, 24.4), fromLevel: 2),
        Building(kind: "building_silo", position: Vec2(40.2, 24.4), fromLevel: 3),
    ]

    public static func standing(_ estate: EstateState) -> [Building] {
        buildings.filter { estate.storageLevel >= $0.fromLevel }
    }

    /// Tiles the player's buildings take up (for obstacles).
    public static func blockedTiles(_ estate: EstateState) -> Set<TileCoord> {
        var tiles = Set<TileCoord>()
        for building in standing(estate) {
            let object = MapObject(kind: building.kind, position: building.position)
            guard let rect = ObjectFootprint.rect(for: object) else { continue }
            for y in Int(rect.minY.rounded(.down))...Int((rect.maxY - 0.001).rounded(.down)) {
                for x in Int(rect.minX.rounded(.down))...Int((rect.maxX - 0.001).rounded(.down)) {
                    let tile = TileCoord(x, y)
                    if rect.intersects(TileRect(minX: Double(x), minY: Double(y), maxX: Double(x + 1), maxY: Double(y + 1))) {
                        tiles.insert(tile)
                    }
                }
            }
        }
        return tiles
    }
}

// MARK: - State

/// A sprinkler standing in the fields.
public struct Sprinkler: Codable, Equatable, Sendable {
    public var tile: TileCoord
    /// Its item ID (which kind).
    public var kind: String

    public init(tile: TileCoord, kind: String) {
        self.tile = tile
        self.kind = kind
    }

    public var radius: Int { MachineCatalog.machine(kind)?.radius ?? 1 }

    public func covers(_ other: TileCoord) -> Bool {
        abs(other.x - tile.x) <= radius && abs(other.y - tile.y) <= radius && other != tile
    }
}

/// What a farmhand looks after.
public enum WorkerJob: String, Codable, CaseIterable, Sendable {
    /// Waters thirsty crops and harvests ripe ones into storage.
    case fields
    /// Collects eggs, milk and more, fills troughs and feeds hungry animals.
    case animals

    public var title: String {
        switch self {
        case .fields: "Field hand"
        case .animals: "Animal keeper"
        }
    }
}

/// What a farmhand just did (the scene animates it).
public enum WorkerTask: String, Codable, Sendable {
    case water, harvest, collect, fillTrough, feed
}

/// A hired farmhand.
public struct Worker: Codable, Equatable, Sendable, Identifiable {
    public var id: Int
    public var name: String
    /// Which farmhand outfit (1-based).
    public var look: Int
    public var job: WorkerJob
    /// Where they are: the spot of their last job (tile units).
    public var position: Vec2
    /// Work built up toward the next task.
    public var progress: Double
    /// Tasks done since hired (the scene notices new ones).
    public var tasksDone: Int
    public var lastTask: WorkerTask?

    public init(id: Int, name: String, look: Int, job: WorkerJob, position: Vec2, progress: Double = 0,
                tasksDone: Int = 0, lastTask: WorkerTask? = nil) {
        self.id = id
        self.name = name
        self.look = look
        self.job = job
        self.position = position
        self.progress = progress
        self.tasksDone = tasksDone
        self.lastTask = lastTask
    }
}

/// The farm's own growth: storage and truck upgrades, machines, farmhands.
public struct EstateState: Codable, Equatable, Sendable {
    public var storageLevel: Int
    public var truckBedLevel: Int
    public var sprinklers: [Sprinkler]
    public var workers: [Worker]
    public var nextWorkerID: Int

    public init(storageLevel: Int = 0, truckBedLevel: Int = 0, sprinklers: [Sprinkler] = [], workers: [Worker] = [],
                nextWorkerID: Int = 1) {
        self.storageLevel = storageLevel
        self.truckBedLevel = truckBedLevel
        self.sprinklers = sprinklers
        self.workers = workers
        self.nextWorkerID = nextWorkerID
    }

    public func sprinkler(at tile: TileCoord) -> Sprinkler? { sprinklers.first { $0.tile == tile } }
}

extension GameState {
    /// Farm storage with the upgrades bought so far.
    /// (Level 0 is the base `storageCapacity`.)
    public func storageCapacity(_ balance: Balance) -> Int {
        let levels = balance.storageLevels
        guard estate.storageLevel > 0, !levels.isEmpty else { return balance.storageCapacity }
        return levels[min(estate.storageLevel, levels.count - 1)]
    }

    /// Truck bed size with the upgrades bought so far. (Level 0 is the base
    /// `truckCargoCapacity`.)
    public func truckCapacity(_ balance: Balance) -> Int {
        let levels = balance.truckBedLevels
        guard estate.truckBedLevel > 0, !levels.isEmpty else { return balance.truckCargoCapacity }
        return levels[min(estate.truckBedLevel, levels.count - 1)]
    }
}

// MARK: - Rules

public enum EstateFailure: Error, Equatable, Sendable {
    case unknown
    case alreadyOwned
    case locked(level: Int)
    case notEnoughMoney
    case maxLevel
    case notYourLand
    case cannotPlaceHere
    case tooFar
    case noneInPouch
    case noSprinkler
    case tooManyWorkers
    case noSuchWorker
}

/// Buying land, upgrades and machines, placing sprinklers, hiring
/// farmhands. Pure functions over `GameState`.
public struct EstateRules: Sendable {
    public let map: WorldMap
    public let balance: Balance

    public init(map: WorldMap, balance: Balance) {
        self.map = map
        self.balance = balance
    }

    private func pay(_ cost: Int, _ category: String, _ state: inout GameState) throws(EstateFailure) {
        guard state.money >= cost else { throw .notEnoughMoney }
        state.money -= cost
        state.finance.spend(cost, category)
    }

    // MARK: Land

    /// Buys a parcel; returns the price. (It's taxed every Monday like the farm.)
    public func buyLand(_ id: String, state: inout GameState) throws(EstateFailure) -> Int {
        guard let property = PropertyCatalog.property(id), let price = property.price else { throw .unknown }
        guard !state.ownedProperties.contains(id) else { throw .alreadyOwned }
        guard state.progress.level >= property.unlockLevel else { throw .locked(level: property.unlockLevel) }
        try pay(price, LedgerCategory.land, &state)
        state.ownedProperties.append(id)
        state.ownedProperties.sort()
        state.goals.add(GoalCounter.landBought)
        return price
    }

    // MARK: Upgrades

    /// The next storage upgrade: (capacity after, cost, level needed), or nil at the top.
    public func nextStorageUpgrade(_ state: GameState) -> (capacity: Int, cost: Int, level: Int)? {
        let next = state.estate.storageLevel + 1
        guard next < balance.storageLevels.count, next - 1 < balance.storageUpgradeCosts.count else { return nil }
        return (balance.storageLevels[next], balance.storageUpgradeCosts[next - 1], balance.storageUpgradeLevels[next - 1])
    }

    public func upgradeStorage(state: inout GameState) throws(EstateFailure) -> Int {
        guard let upgrade = nextStorageUpgrade(state) else { throw .maxLevel }
        guard state.progress.level >= upgrade.level else { throw .locked(level: upgrade.level) }
        try pay(upgrade.cost, LedgerCategory.buildings, &state)
        state.estate.storageLevel += 1
        state.goals.add(GoalCounter.storageUpgrades)
        return upgrade.cost
    }

    public func nextTruckBedUpgrade(_ state: GameState) -> (capacity: Int, cost: Int, level: Int)? {
        let next = state.estate.truckBedLevel + 1
        guard next < balance.truckBedLevels.count, next - 1 < balance.truckBedUpgradeCosts.count else { return nil }
        return (balance.truckBedLevels[next], balance.truckBedUpgradeCosts[next - 1], balance.truckBedUpgradeLevels[next - 1])
    }

    public func upgradeTruckBed(state: inout GameState) throws(EstateFailure) -> Int {
        guard let upgrade = nextTruckBedUpgrade(state) else { throw .maxLevel }
        guard state.progress.level >= upgrade.level else { throw .locked(level: upgrade.level) }
        try pay(upgrade.cost, LedgerCategory.buildings, &state)
        state.estate.truckBedLevel += 1
        return upgrade.cost
    }

    // MARK: Machines

    /// Buys a machine; it's delivered to the farm (the pouch).
    public func buyMachine(_ id: String, state: inout GameState) throws(EstateFailure) -> Int {
        guard let machine = MachineCatalog.machine(id) else { throw .unknown }
        guard state.progress.level >= machine.unlockLevel else { throw .locked(level: machine.unlockLevel) }
        try pay(machine.price, LedgerCategory.machines, &state)
        state.inventory.add(id, 1)
        return machine.price
    }

    /// Why a sprinkler can't stand here, or nil. (Grass on your land, free of
    /// fields, trees and buildings; planning skips the reach check.)
    public func placeProblem(at tile: TileCoord, in state: GameState, checkReach: Bool = true) -> EstateFailure? {
        let farming = Farming(map: map, balance: balance)
        switch farming.plowProblem(at: tile, in: state, checkReach: checkReach) {
        case nil: return nil
        case .notYourLand?: return .notYourLand
        case .tooFar?: return .tooFar
        default: return .cannotPlaceHere
        }
    }

    public func placeSprinkler(_ kind: String, at tile: TileCoord, state: inout GameState) throws(EstateFailure) {
        guard MachineCatalog.machine(kind) != nil else { throw .unknown }
        guard state.inventory.count(kind) > 0 else { throw .noneInPouch }
        if let problem = placeProblem(at: tile, in: state) { throw problem }
        state.inventory.remove(kind, 1)
        state.estate.sprinklers.append(Sprinkler(tile: tile, kind: kind))
        state.estate.sprinklers.sort { ($0.tile.y, $0.tile.x) < ($1.tile.y, $1.tile.x) }
        state.goals.add(GoalCounter.sprinklersPlaced)
    }

    public func pickUpSprinkler(at tile: TileCoord, state: inout GameState) throws(EstateFailure) {
        guard let sprinkler = state.estate.sprinkler(at: tile) else { throw .noSprinkler }
        guard !state.farmer.inTruck, state.farmer.position.distance(to: tile.center) <= balance.workReach else { throw .tooFar }
        state.estate.sprinklers.removeAll { $0.tile == tile }
        state.inventory.add(sprinkler.kind, 1)
    }

    // MARK: Farmhands

    /// The level the next hire needs, or nil when the farm has all it can take.
    public func nextHireLevel(_ state: GameState) -> Int? {
        let hired = state.estate.workers.count
        return hired < balance.workerUnlockLevels.count ? balance.workerUnlockLevels[hired] : nil
    }

    /// The first wage: the days until Monday's bills take over.
    public func firstWage(_ state: GameState) -> Int {
        let days = 7 - state.clock.dayIndex % 7
        return Int((Double(balance.workerWagePerWeek) * Double(days) / 7).rounded(.up))
    }

    static let names = ["Mia", "Jonas", "Ada", "Theo", "Lina", "Oskar", "Nora", "Emil", "Freja", "Karl"]
    public static let looks = 3

    /// Hires a farmhand for a job; returns them.
    public func hire(_ job: WorkerJob, state: inout GameState) throws(EstateFailure) -> Worker {
        guard let level = nextHireLevel(state) else { throw .tooManyWorkers }
        guard state.progress.level >= level else { throw .locked(level: level) }
        try pay(firstWage(state), LedgerCategory.wages, &state)
        let id = state.estate.nextWorkerID
        let worker = Worker(id: id, name: Self.names[(id - 1) % Self.names.count], look: (id - 1) % Self.looks + 1,
                            job: job, position: HomeValleyMap.farmhouseDoor + Vec2(Double(id) * 0.8, -1))
        state.estate.nextWorkerID += 1
        state.estate.workers.append(worker)
        state.goals.add(GoalCounter.workersHired)
        return worker
    }

    public func assign(_ id: Int, to job: WorkerJob, state: inout GameState) throws(EstateFailure) {
        guard let index = state.estate.workers.firstIndex(where: { $0.id == id }) else { throw .noSuchWorker }
        state.estate.workers[index].job = job
        state.estate.workers[index].progress = 0
    }

    /// Lets a farmhand go (wages already paid aren't refunded).
    public func dismiss(_ id: Int, state: inout GameState) throws(EstateFailure) {
        guard state.estate.workers.contains(where: { $0.id == id }) else { throw .noSuchWorker }
        state.estate.workers.removeAll { $0.id == id }
    }
}

extension Simulation {
    /// Runs an estate action; failures leave the state unchanged.
    public mutating func estate<T>(on map: WorldMap, _ body: (EstateRules, inout GameState) throws -> T) -> Result<T, EstateFailure> {
        var copy = state
        do {
            let value = try body(EstateRules(map: map, balance: balance), &copy)
            modify { $0 = copy }
            return .success(value)
        } catch let failure as EstateFailure {
            return .failure(failure)
        } catch {
            preconditionFailure("Estate rules only throw EstateFailure: \(error)")
        }
    }
}
