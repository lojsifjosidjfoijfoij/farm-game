import Foundation

// MARK: - The almanac

/// Everything the farm has grown, caught, found or made, and the collection
/// sets whose rewards were claimed.
public struct AlmanacState: Codable, Equatable, Sendable {
    /// Item IDs, sorted.
    public var discovered: [String]
    public var claimedSets: [String]

    public init(discovered: [String] = [], claimedSets: [String] = []) {
        self.discovered = discovered
        self.claimedSets = claimedSets
    }

    public func has(_ item: String) -> Bool { discovered.contains(item) }
}

/// A themed page of the almanac: fill it for a reward.
public struct AlmanacSet: Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let items: [String]
    public let coins: Int
    public let xp: Int
}

public enum Almanac {
    /// The kinds of things the almanac collects.
    public static let categories: [ItemCategory] = [.crop, .fruit, .animalProduct, .fish, .forage, .artisan, .wood]

    /// Every entry, in catalog order.
    public static let entries: [ItemDefinition] = ItemCatalog.all.filter { categories.contains($0.category) }

    public static let sets: [AlmanacSet] = [
        AlmanacSet(id: "fields", name: "Field and furrow",
                   items: ["wheat", "carrot", "potato", "corn", "pumpkin", "lettuce", "onion", "kale", "garlic", "cabbage"],
                   coins: 300, xp: 40),
        AlmanacSet(id: "summer", name: "Summer bounty", items: ["strawberry", "tomato", "sunflower", "blueberry", "melon"],
                   coins: 400, xp: 50),
        AlmanacSet(id: "orchard", name: "The orchard", items: ["apple", "cherry"], coins: 150, xp: 20),
        AlmanacSet(id: "barnyard", name: "Barnyard", items: ["egg", "milk", "wool", "truffle", "goat_milk"], coins: 500, xp: 60),
        AlmanacSet(id: "pond", name: "Pond life", items: ["sunfish", "carp", "perch", "catfish"], coins: 200, xp: 30),
        AlmanacSet(id: "lake", name: "Lake life", items: ["trout", "bass", "whitefish", "pike", "salmon", "eel"],
                   coins: 500, xp: 60),
        AlmanacSet(id: "legends", name: "Legends of the valley", items: ["golden_koi", "sturgeon"], coins: 1_500, xp: 150),
        AlmanacSet(id: "wild_warm", name: "Spring and summer wilds",
                   items: ["wild_garlic", "daffodil", "morel", "blackberry", "chamomile", "elderflower"], coins: 350, xp: 40),
        AlmanacSet(id: "wild_cold", name: "Autumn and winter wilds",
                   items: ["chanterelle", "hazelnut", "holly", "pinecone", "snowdrop"], coins: 350, xp: 40),
        AlmanacSet(id: "pantry", name: "The pantry",
                   items: ["flour", "cornmeal", "honey", "strawberry_jam", "blueberry_jam", "blackberry_jam", "tomato_sauce",
                           "pickled_onions", "sauerkraut"], coins: 500, xp: 60),
        AlmanacSet(id: "cellar", name: "The cellar",
                   items: ["cheese", "goat_cheese", "apple_juice", "carrot_juice", "cherry_juice", "elderflower_cordial",
                           "sunflower_oil"], coins: 600, xp: 70),
        AlmanacSet(id: "crafts", name: "Crafts and smokehouse",
                   items: ["log", "plank", "cloth", "chamomile_tea", "dried_mushrooms", "smoked_trout", "smoked_salmon", "smoked_eel"],
                   coins: 700, xp: 80),
    ]

    public static func set(_ id: String) -> AlmanacSet? { sets.first { $0.id == id } }

    public static func isComplete(_ set: AlmanacSet, _ almanac: AlmanacState) -> Bool { set.items.allSatisfy(almanac.has) }

    /// 0…1 of all entries discovered.
    public static func completion(_ almanac: AlmanacState) -> Double {
        let found = entries.filter { almanac.has($0.id) }.count
        return entries.isEmpty ? 0 : Double(found) / Double(entries.count)
    }

    /// Claims a finished set's reward. Returns the coins and any level-ups, or nil.
    public static func claim(_ id: String, state: inout GameState, balance: Balance) -> (coins: Int, events: [SimEvent])? {
        guard let set = set(id), !state.almanac.claimedSets.contains(id), isComplete(set, state.almanac) else { return nil }
        state.almanac.claimedSets.append(id)
        state.money += set.coins
        state.finance.earn(set.coins, LedgerCategory.goals)
        return (set.coins, Progression.addXP(set.xp, to: &state, balance: balance))
    }

    /// Items the farm has had (in storage, the truck or the shop), or caught,
    /// found or collected before.
    static func seen(in state: GameState) -> Set<String> {
        var result = Set(state.inventory.items.keys)
        result.formUnion(state.truck.cargo.items.keys)
        result.formUnion(state.farmer.bag.items.keys)
        for shelf in state.store.shelves where shelf.stock > 0 {
            if let item = shelf.itemID { result.insert(item) }
        }
        for key in state.goals.counters.keys {
            for prefix in ["caught:", "found:", "collected:"] where key.hasPrefix(prefix) {
                result.insert(String(key.dropFirst(prefix.count)))
            }
        }
        return result
    }
}

/// Notes new almanac entries as they turn up. Runs over each span at once.
public struct AlmanacSystem: SimulationSystem {
    public init() {}

    public var handlesAnyStepSize: Bool { true }

    private static let collectible = Set(Almanac.entries.map(\.id))

    public func step(_ state: inout GameState, _ context: inout StepContext) {
        let known = Set(state.almanac.discovered)
        let new = Almanac.seen(in: state).filter { Self.collectible.contains($0) && !known.contains($0) }
        guard !new.isEmpty else { return }
        state.almanac.discovered = (known.union(new)).sorted()
        context.events += new.sorted().map { .discovered($0) }
    }
}

// MARK: - Farm ranks

/// How the valley sees the farm, by its net worth. The top rank is the
/// finale: the Valley's Finest Farm (and farming goes on).
public struct FarmRank: Sendable, Equatable, Identifiable {
    public let id: Int
    public let title: String
    public let netWorth: Int
    public let blurb: String
    /// Which farmhouse stands (0 run-down … 3 grand).
    public let farmhouseTier: Int
    public var xp: Int { 40 * id }
}

public struct RankState: Codable, Equatable, Sendable {
    /// The best rank reached (it never drops).
    public var rank: Int
    /// The game day the farm became the Valley's Finest Farm.
    public var finaleDay: Int?

    public init(rank: Int = 0, finaleDay: Int? = nil) {
        self.rank = rank
        self.finaleDay = finaleDay
    }
}

public enum FarmRanks {
    public static let all: [FarmRank] = [
        FarmRank(id: 0, title: "Run-down plot", netWorth: 0, blurb: "A leaky roof and a field full of weeds.", farmhouseTier: 0),
        FarmRank(id: 1, title: "Hobby farm", netWorth: 5_000, blurb: "The neighbours have noticed the new crops.", farmhouseTier: 0),
        FarmRank(id: 2, title: "Family farm", netWorth: 15_000, blurb: "The farmhouse gets a fresh coat of paint and a new roof.",
                 farmhouseTier: 1),
        FarmRank(id: 3, title: "Thriving farm", netWorth: 40_000, blurb: "Your name comes up at the market.", farmhouseTier: 1),
        FarmRank(id: 4, title: "Valley estate", netWorth: 90_000, blurb: "The farmhouse grows a porch and a second floor.",
                 farmhouseTier: 2),
        FarmRank(id: 5, title: "Farming empire", netWorth: 160_000, blurb: "Half the valley eats what you grow.", farmhouseTier: 2),
        FarmRank(id: 6, title: "Valley's Finest Farm", netWorth: 250_000,
                 blurb: "The finest farm in the valley, with a farmhouse to match.", farmhouseTier: 3),
    ]

    public static var finale: FarmRank { all[all.count - 1] }

    public static func rank(_ index: Int) -> FarmRank { all[max(0, min(all.count - 1, index))] }

    /// The next rank up, if any.
    public static func next(after index: Int) -> FarmRank? { index + 1 < all.count ? all[index + 1] : nil }
}

/// What the farm is worth: coins, land, buildings, machines, animals and
/// goods, minus what's owed.
public enum NetWorth {
    public static func of(_ state: GameState, balance: Balance) -> Int {
        var total = state.money
        // Land.
        for id in state.ownedProperties { total += PropertyCatalog.property(id)?.price ?? 0 }
        // Buildings.
        total += balance.storageUpgradeCosts.prefix(state.estate.storageLevel).reduce(0, +)
        total += balance.truckBedUpgradeCosts.prefix(state.estate.truckBedLevel).reduce(0, +)
        // Machines and workshops, placed or in the pouch.
        for sprinkler in state.estate.sprinklers { total += MachineCatalog.machine(sprinkler.kind)?.price ?? 0 }
        for workshop in state.estate.workshops { total += workshop.definition?.price ?? 0 }
        // Pens and animals.
        for pen in PenCatalog.all where state.ranch[pen.id].isRepaired { total += pen.repairCost }
        for animal in state.ranch.allAnimals { total += animal.species?.price ?? 0 }
        // Goods, at their usual value (machines at their price).
        total += value(of: state.inventory.items)
        total += value(of: state.truck.cargo.items)
        total += value(of: state.farmer.bag.items)
        for shelf in state.store.shelves {
            if let item = shelf.itemID { total += value(of: [item: shelf.stock]) }
        }
        // What the farm has given the village still counts: it's the farm's
        // standing in the valley (so giving never costs you a rank).
        total += Village.given(state)
        // Debts.
        total -= state.finance.loan?.balance ?? 0
        return total
    }

    private static func value(of items: [String: Int]) -> Int {
        items.reduce(0) { sum, entry in
            guard let item = ItemCatalog.item(entry.key) else { return sum }
            let each = item.category.isSellable || item.category == .machine
                ? (item.value.lowerBound + item.value.upperBound) / 2 : 0
            return sum + each * entry.value
        }
    }
}

/// Moves the farm up the ranks as its net worth grows (checked over each span).
public struct RankSystem: SimulationSystem {
    public init() {}

    public var handlesAnyStepSize: Bool { true }

    public func step(_ state: inout GameState, _ context: inout StepContext) {
        guard let next = FarmRanks.next(after: state.rank.rank),
              NetWorth.of(state, balance: context.balance) >= next.netWorth else { return }
        let worth = NetWorth.of(state, balance: context.balance)
        // Every rank passed counts (a big sale can skip one).
        while let rank = FarmRanks.next(after: state.rank.rank), worth >= rank.netWorth {
            state.rank.rank = rank.id
            context.events.append(.rankUp(rank.id))
            context.events += Progression.addXP(rank.xp, to: &state, balance: context.balance)
            if rank.id == FarmRanks.finale.id { state.rank.finaleDay = state.clock.dayIndex }
        }
    }
}

extension Simulation {
    /// Claims an almanac set's reward.
    public mutating func claimAlmanacSet(_ id: String) -> (coins: Int, events: [SimEvent])? {
        let balance = self.balance
        return modify { state in Almanac.claim(id, state: &state, balance: balance) }
    }
}
