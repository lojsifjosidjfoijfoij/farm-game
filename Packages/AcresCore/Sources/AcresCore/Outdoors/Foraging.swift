import Foundation

/// Something wild to pick up: mushrooms, berries, flowers, nuts.
public struct ForageDefinition: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let plural: String
    public let season: Season
    /// How often it turns up compared with the season's others.
    public let weight: Double
    public let value: ClosedRange<Int>
    public let xp: Int
}

public enum ForageCatalog {
    public static let all: [ForageDefinition] = [
        ForageDefinition(id: "wild_garlic", name: "Wild garlic", plural: "bunches of wild garlic", season: .spring,
                         weight: 3, value: 14...20, xp: 2),
        ForageDefinition(id: "daffodil", name: "Daffodil", plural: "daffodils", season: .spring, weight: 2, value: 18...24, xp: 2),
        ForageDefinition(id: "morel", name: "Morel", plural: "morels", season: .spring, weight: 0.8, value: 60...80, xp: 5),
        ForageDefinition(id: "blackberry", name: "Blackberries", plural: "handfuls of blackberries", season: .summer,
                         weight: 3, value: 16...22, xp: 2),
        ForageDefinition(id: "chamomile", name: "Chamomile", plural: "bunches of chamomile", season: .summer,
                         weight: 2, value: 20...26, xp: 2),
        ForageDefinition(id: "elderflower", name: "Elderflower", plural: "sprays of elderflower", season: .summer,
                         weight: 1.5, value: 26...34, xp: 3),
        ForageDefinition(id: "chanterelle", name: "Chanterelle", plural: "chanterelles", season: .autumn,
                         weight: 2.5, value: 40...55, xp: 4),
        ForageDefinition(id: "hazelnut", name: "Hazelnuts", plural: "handfuls of hazelnuts", season: .autumn,
                         weight: 3, value: 18...24, xp: 2),
        ForageDefinition(id: "holly", name: "Holly", plural: "sprigs of holly", season: .winter, weight: 3, value: 16...22, xp: 2),
        ForageDefinition(id: "pinecone", name: "Pinecone", plural: "pinecones", season: .winter, weight: 3, value: 8...12, xp: 1),
        ForageDefinition(id: "snowdrop", name: "Snowdrop", plural: "snowdrops", season: .winter, weight: 1.2, value: 30...40, xp: 3),
    ]

    public static func find(_ id: String) -> ForageDefinition? { all.first { $0.id == id } }

    public static func inSeason(_ season: Season) -> [ForageDefinition] { all.filter { $0.season == season } }
}

/// Today's finds that were already picked. Everything else is derived from
/// the day, so only this is saved.
public struct ForageState: Codable, Equatable, Sendable {
    /// The game day `picked` is for (-1: none yet).
    public var day: Int
    /// Indices into `Foraging.spots`.
    public var picked: [Int]

    public init(day: Int = -1, picked: [Int] = []) {
        self.day = day
        self.picked = picked
    }

    public func picked(on day: Int) -> Set<Int> { self.day == day ? Set(picked) : [] }
}

/// One wild find lying somewhere today.
public struct ForageSpawn: Equatable, Sendable, Identifiable {
    /// Index into `Foraging.spots`.
    public let id: Int
    public let item: String
    public let position: Vec2
}

/// Foraging: every morning a handful of the season's finds turn up at spots
/// in the woods and meadows. They're the same for everyone on that day (a
/// hash of the day), and gone once picked.
public struct Foraging: Sendable {
    public let balance: Balance

    public init(balance: Balance) {
        self.balance = balance
    }

    /// Every place a find can turn up: open grass away from roads, the farm
    /// and the village. Fixed for the map.
    public static let spots: [Vec2] = {
        let map = HomeValleyMap.map
        var rng = SeededRandom(seed: SeededRandom.stableHash("forage-spots"))
        let regions: [(TileRect, Int)] = [
            (TileRect(minX: 1, minY: 42, maxX: 63, maxY: 64), 40),     // the forest behind the farm
            (TileRect(minX: 1, minY: 64, maxX: 143, maxY: 95), 70),    // the big northern forest
            (TileRect(minX: 64, minY: 38, maxX: 143, maxY: 64), 40),   // woods east of the village
            (TileRect(minX: 1, minY: 1, maxX: 55, maxY: 21), 40),      // south meadows
            (TileRect(minX: 60, minY: 1, maxX: 143, maxY: 14), 40),    // fields south of the village
            (TileRect(minX: 1, minY: 1, maxX: 9, maxY: 42), 12),       // the western strip
        ]
        let avoid = [HomeValleyMap.homeFarmArea.insetBy(-1), TileRect(minX: 58, minY: 14, maxX: 125, maxY: 37),
                     TileRect(minX: 120, minY: 22, maxX: 143, maxY: 36), HomeValleyMap.lakeArea.insetBy(-1)]
        var result: [Vec2] = []
        for (area, count) in regions {
            var placed = 0
            var attempts = 0
            while placed < count && attempts < count * 60 {
                attempts += 1
                let p = Vec2(rng.next(in: area.minX...area.maxX), rng.next(in: area.minY...area.maxY))
                let tile = TileCoord(containing: p)
                guard map.isInside(tile), map.terrain(at: tile) == .grass, !map.blockedTiles.contains(tile),
                      !avoid.contains(where: { $0.contains(p) }),
                      !PenCatalog.all.contains(where: { $0.footprint.insetBy(-1).contains(p) }),
                      !result.contains(where: { $0.distance(to: p) < 2.5 }) else { continue }
                result.append(Vec2(Double(tile.x) + 0.5, Double(tile.y) + 0.5))
                placed += 1
            }
        }
        return result
    }()

    /// How many finds turn up in a day.
    public func count(in season: Season) -> Int { season == .winter ? balance.forageWinterCount : balance.forageCount }

    /// The finds lying out today (not picked, not built over).
    public func today(_ state: GameState) -> [ForageSpawn] {
        guard state.has(.foraging) else { return [] }  // the woods keep their secrets for a while
        let day = state.clock.dayIndex
        let season = state.clock.date(daysPerSeason: balance.daysPerSeason).season
        let picked = state.forage.picked(on: day)
        let obstacles = EstateLayout.blockedTiles(state.estate)
        return Self.spawns(day: day, season: season, count: count(in: season)).filter { spawn in
            let tile = TileCoord(containing: spawn.position)
            return !picked.contains(spawn.id) && state.plots[tile] == nil && state.woodland.trees[tile] == nil
                && !state.estate.isOccupied(tile) && !obstacles.contains(tile) && !state.isFarmland(tile)
        }
    }

    /// The day's finds, before any are picked.
    public static func spawns(day: Int, season: Season, count: Int) -> [ForageSpawn] {
        let pool = ForageCatalog.inSeason(season)
        let total = pool.reduce(0) { $0 + $1.weight }
        guard !pool.isEmpty, !spots.isEmpty else { return [] }
        var rng = SeededRandom(seed: SeededRandom.stableHash("forage") ^ (UInt64(bitPattern: Int64(day)) &* 0xA24B_AED4_963E_E407))
        var free = Array(spots.indices)
        var result: [ForageSpawn] = []
        for _ in 0..<min(count, free.count) {
            let index = free.remove(at: Int(rng.nextUnit() * Double(free.count)) % free.count)
            var roll = rng.nextUnit() * total
            var item = pool[0]
            for find in pool {
                roll -= find.weight
                if roll < 0 { item = find; break }
            }
            result.append(ForageSpawn(id: index, item: item.id, position: spots[index]))
        }
        return result
    }

    /// Picks up a find the farmer is standing by.
    public func pick(_ spawnID: Int, state: inout GameState) throws(OutdoorFailure) -> OutdoorCatch {
        guard let spawn = today(state).first(where: { $0.id == spawnID }),
              let find = ForageCatalog.find(spawn.item) else { throw .nothingHere }
        if state.farmer.inTruck { throw .inTruck }
        guard state.farmer.position.distance(to: spawn.position) <= balance.workReach + 0.5 else { throw .tooFar }
        guard state.inventory.storageUsed + 1 <= state.storageCapacity(balance) else { throw .storageFull }
        let day = state.clock.dayIndex
        if state.forage.day != day { state.forage = ForageState(day: day) }
        state.forage.picked.append(spawnID)
        let isNew = state.goals.count(GoalCounter.foundWild(find.id)) == 0
        state.inventory.add(find.id, 1)
        state.goals.add(GoalCounter.foraged, 1)
        state.goals.add(GoalCounter.foundWild(find.id), 1)
        let events = Progression.addXP(find.xp, to: &state, balance: balance)
        return OutdoorCatch(item: find.id, xp: find.xp, events: events, isNew: isNew)
    }
}
