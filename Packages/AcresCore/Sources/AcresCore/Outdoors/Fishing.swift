import Foundation

// MARK: - Water

/// Somewhere to fish. Taps inside `area` cast there; the farmer stands on the shore.
public struct WaterBody: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Hashable {
        case pond, lake
    }

    public let id: String
    public let name: String
    public let kind: Kind
    /// The water, in tile units (the same as the map object's footprint).
    public let area: TileRect

    /// Spots just outside the water, every tile or so, that the map leaves free.
    public var shoreSpots: [Vec2] {
        let map = HomeValleyMap.map
        let ring = area.insetBy(-0.7)
        var spots: [Vec2] = []
        var x = ring.minX
        while x <= ring.maxX + 1e-9 {
            spots.append(Vec2(x, ring.minY))
            spots.append(Vec2(x, ring.maxY))
            x += 1
        }
        var y = ring.minY + 1
        while y < ring.maxY - 0.5 {
            spots.append(Vec2(ring.minX, y))
            spots.append(Vec2(ring.maxX, y))
            y += 1
        }
        return spots.filter { !map.blockedTiles.contains(TileCoord(containing: $0)) && map.isInside(TileCoord(containing: $0)) }
    }
}

public enum Waters {
    /// The little pond by the farm, and Willow Lake south of the village.
    public static let all: [WaterBody] = [
        WaterBody(id: "farm_pond", name: "Farm pond", kind: .pond,
                  area: TileRect(minX: 10.8, minY: 24.1, maxX: 14.0, maxY: 26.3)),
        WaterBody(id: "willow_lake", name: "Willow Lake", kind: .lake, area: HomeValleyMap.lakeArea),
    ]

    public static func water(_ id: String) -> WaterBody? { all.first { $0.id == id } }

    /// The water at a point, if any.
    public static func water(at point: Vec2) -> WaterBody? { all.first { $0.area.contains(point) } }
}

// MARK: - Fish

public struct FishDefinition: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let plural: String
    /// Where it bites.
    public let waters: Set<WaterBody.Kind>
    /// When it bites (all year if empty).
    public let seasons: Set<Season>
    /// Only after dark (19:00–06:00).
    public let nightOnly: Bool
    /// How often it bites compared with the others (higher is commoner).
    public let weight: Double
    /// 0 (easy) … 1 (a real fight): how small and fast the catch window is.
    public let difficulty: Double
    public let value: ClosedRange<Int>
    public let xp: Int
    /// A legend: rare, hard, worth a lot.
    public var isLegendary: Bool { weight < 0.5 }

    public init(id: String, name: String, plural: String, waters: Set<WaterBody.Kind>, seasons: Set<Season> = [],
                nightOnly: Bool = false, weight: Double, difficulty: Double, value: ClosedRange<Int>, xp: Int) {
        self.id = id
        self.name = name
        self.plural = plural
        self.waters = waters
        self.seasons = seasons
        self.nightOnly = nightOnly
        self.weight = weight
        self.difficulty = difficulty
        self.value = value
        self.xp = xp
    }

    public func bites(in water: WaterBody.Kind, season: Season, hour: Int) -> Bool {
        waters.contains(water) && (seasons.isEmpty || seasons.contains(season)) && (!nightOnly || hour >= 19 || hour < 6)
    }

    /// "Spring, autumn · night".
    public var whenText: String {
        let when = seasons.isEmpty ? "All year" : Season.allCases.filter { seasons.contains($0) }.map(\.name).joined(separator: ", ")
        return nightOnly ? "\(when) · at night" : when
    }
}

public enum FishCatalog {
    public static let all: [FishDefinition] = [
        FishDefinition(id: "sunfish", name: "Sunfish", plural: "sunfish", waters: [.pond, .lake],
                       weight: 5, difficulty: 0.1, value: 12...18, xp: 2),
        FishDefinition(id: "carp", name: "Carp", plural: "carp", waters: [.pond, .lake],
                       weight: 4, difficulty: 0.25, value: 20...28, xp: 3),
        FishDefinition(id: "perch", name: "Perch", plural: "perch", waters: [.pond, .lake], seasons: [.spring, .summer, .autumn],
                       weight: 3, difficulty: 0.35, value: 28...36, xp: 3),
        FishDefinition(id: "catfish", name: "Catfish", plural: "catfish", waters: [.pond], seasons: [.summer, .autumn],
                       nightOnly: true, weight: 2.5, difficulty: 0.5, value: 45...60, xp: 5),
        FishDefinition(id: "golden_koi", name: "Golden koi", plural: "golden koi", waters: [.pond],
                       weight: 0.2, difficulty: 0.85, value: 320...400, xp: 25),
        FishDefinition(id: "trout", name: "Trout", plural: "trout", waters: [.lake], seasons: [.spring, .autumn, .winter],
                       weight: 3, difficulty: 0.45, value: 40...52, xp: 4),
        FishDefinition(id: "bass", name: "Bass", plural: "bass", waters: [.lake], seasons: [.summer],
                       weight: 3, difficulty: 0.5, value: 45...58, xp: 4),
        FishDefinition(id: "whitefish", name: "Whitefish", plural: "whitefish", waters: [.lake], seasons: [.winter],
                       weight: 3, difficulty: 0.4, value: 36...46, xp: 4),
        FishDefinition(id: "pike", name: "Pike", plural: "pike", waters: [.lake], seasons: [.autumn, .winter],
                       weight: 1.5, difficulty: 0.65, value: 70...90, xp: 6),
        FishDefinition(id: "salmon", name: "Salmon", plural: "salmon", waters: [.lake], seasons: [.autumn],
                       weight: 1.6, difficulty: 0.6, value: 80...100, xp: 7),
        FishDefinition(id: "eel", name: "Eel", plural: "eels", waters: [.lake], seasons: [.spring, .summer],
                       nightOnly: true, weight: 1.3, difficulty: 0.7, value: 90...115, xp: 8),
        FishDefinition(id: "sturgeon", name: "Sturgeon", plural: "sturgeon", waters: [.lake], seasons: [.summer],
                       weight: 0.25, difficulty: 0.9, value: 380...460, xp: 30),
    ]

    public static func fish(_ id: String) -> FishDefinition? { all.first { $0.id == id } }

    /// What bites here and now.
    public static func biting(in water: WaterBody.Kind, season: Season, hour: Int) -> [FishDefinition] {
        all.filter { $0.bites(in: water, season: season, hour: hour) }
    }
}

// MARK: - Rules

public enum OutdoorFailure: Error, Equatable, Sendable {
    /// Casting on dry land.
    case notWater
    case tooFar
    case tooTired
    case storageFull
    /// Nothing to forage there (or it was picked).
    case nothingHere
    case inTruck
    /// The rod comes later.
    case locked(level: Int)
}

/// A fish on the line: what it is, where it was hooked.
public struct FishBite: Equatable, Sendable {
    public let fishID: String
    public let waterID: String
    public var fish: FishDefinition? { FishCatalog.fish(fishID) }
}

/// What landing a fish (or picking a wild find) gave.
public struct OutdoorCatch: Sendable {
    public let item: String
    public let xp: Int
    /// Level-ups from the XP.
    public let events: [SimEvent]
    /// First of its kind ever.
    public let isNew: Bool
}

/// Fishing: cast (costs energy, decides what bites), then land it (the app
/// runs the catch; landing puts the fish in storage).
public struct Fishing: Sendable {
    public let balance: Balance

    public init(balance: Balance) {
        self.balance = balance
    }

    /// Why a cast at `target` wouldn't work, if it wouldn't.
    public func castProblem(at target: Vec2, in state: GameState, checkReach: Bool = true) -> OutdoorFailure? {
        guard let water = Waters.water(at: target) else { return .notWater }
        guard state.has(.rod) else { return .locked(level: Feature.rod.unlockLevel) }
        if state.farmer.inTruck { return .inTruck }
        if checkReach, water.area.distance(to: state.farmer.position) > balance.castReach { return .tooFar }
        if state.farmer.energy < balance.energyCost.cast { return .tooTired }
        return nil
    }

    /// Casts: spends energy and decides (with the game's RNG) what bites.
    public func cast(at target: Vec2, state: inout GameState) throws(OutdoorFailure) -> FishBite {
        if let problem = castProblem(at: target, in: state) { throw problem }
        guard let water = Waters.water(at: target) else { throw .notWater }
        state.farmer.energy = max(0, state.farmer.energy - balance.energyCost.cast)
        let season = state.clock.date(daysPerSeason: balance.daysPerSeason).season
        let pool = FishCatalog.biting(in: water.kind, season: season, hour: state.clock.hour)
        let total = pool.reduce(0) { $0 + $1.weight }
        var roll = state.rng.nextUnit() * total
        var pick = pool.first
        for fish in pool {
            roll -= fish.weight
            if roll < 0 { pick = fish; break }
        }
        state.goals.add(GoalCounter.casts, 1)
        return FishBite(fishID: pick?.id ?? "sunfish", waterID: water.id)
    }

    /// Lands a hooked fish: into storage, with XP.
    public func land(_ bite: FishBite, state: inout GameState) throws(OutdoorFailure) -> OutdoorCatch {
        guard let fish = bite.fish else { throw .notWater }
        guard state.inventory.storageUsed + 1 <= state.storageCapacity(balance) else { throw .storageFull }
        let isNew = state.goals.count(GoalCounter.caught(fish.id)) == 0
        state.inventory.add(fish.id, 1)
        state.goals.add(GoalCounter.fishCaught, 1)
        state.goals.add(GoalCounter.caught(fish.id), 1)
        let events = Progression.addXP(fish.xp, to: &state, balance: balance)
        return OutdoorCatch(item: fish.id, xp: fish.xp, events: events, isNew: isNew)
    }
}

extension Simulation {
    /// Runs a fishing or foraging action; failures leave the state unchanged.
    public mutating func outdoors<T>(_ body: (Fishing, Foraging, inout GameState) throws -> T) -> Result<T, OutdoorFailure> {
        var copy = state
        do {
            let value = try body(Fishing(balance: balance), Foraging(balance: balance), &copy)
            modify { $0 = copy }
            return .success(value)
        } catch let failure as OutdoorFailure {
            return .failure(failure)
        } catch {
            return .failure(.nothingHere)
        }
    }
}
