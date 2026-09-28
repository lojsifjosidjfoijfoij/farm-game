import Foundation

/// Progress toward goals: counters of things done, and claimed rewards.
public struct GoalState: Codable, Equatable, Sendable {
    /// Things done so far, by counter name (see `GoalCounter`).
    public var counters: [String: Int]
    /// Goals whose reward was collected, in order.
    public var claimed: [String]

    public init(counters: [String: Int] = [:], claimed: [String] = []) {
        self.counters = counters
        self.claimed = claimed
    }

    public func count(_ counter: String) -> Int { counters[counter] ?? 0 }

    public mutating func add(_ counter: String, _ amount: Int = 1) {
        guard amount > 0 else { return }
        counters[counter, default: 0] += amount
    }
}

/// Counter names the game records.
public enum GoalCounter {
    public static let plowed = "plowed"
    public static let planted = "planted"
    public static let harvested = "harvested"
    public static let watered = "watered"
    public static let coinsFromSales = "coinsFromSales"
    public static let seedsBought = "seedsBought"
    public static let slept = "slept"
    public static let treesChopped = "treesChopped"
    public static let fruitTreesPlanted = "fruitTreesPlanted"
    public static let animalsBought = "animalsBought"
    public static let contractsCompleted = "contractsCompleted"
    public static let shopRented = "shopRented"
    public static let coinsFromShop = "coinsFromShop"
    public static let landBought = "landBought"
    public static let storageUpgrades = "storageUpgrades"
    public static let sprinklersPlaced = "sprinklersPlaced"
    public static let workersHired = "workersHired"
    public static let workshopsPlaced = "workshopsPlaced"
    public static let crafted = "crafted"
    public static let fieldsBought = "fieldsBought"
    public static let casts = "casts"
    public static let fishCaught = "fishCaught"
    public static let foraged = "foraged"
    /// Fish of one kind caught.
    public static func caught(_ fish: String) -> String { "caught:\(fish)" }
    /// Wild finds of one kind picked.
    public static func foundWild(_ item: String) -> String { "found:\(item)" }
    public static func collected(_ item: String) -> String { "collected:\(item)" }
}

/// One goal: what to do, what it pays.
public struct GoalDefinition: Sendable, Identifiable, Equatable {
    public enum Requirement: Sendable, Equatable {
        /// A counter reaches a number.
        case count(String, Int)
        case money(Int)
        case level(Int)
        /// Own this many animals of a species (any age).
        case animals(String, Int)
        case penRepaired(String)
    }

    public let id: String
    public let title: String
    public let detail: String
    public let requirement: Requirement
    public let coins: Int
    public let xp: Int
}

/// The goal ladder: always a few goals open at once, so there's a clear next
/// step and a bigger dream. (Phases 6–8 add business goals.)
public enum GoalCatalog {
    /// How many unclaimed goals are shown at once.
    public static let openAtOnce = 3

    public static let all: [GoalDefinition] = [
        GoalDefinition(id: "plow8", title: "Break ground", detail: "Plow 8 tiles of the old field.",
                       requirement: .count(GoalCounter.plowed, 8), coins: 40, xp: 5),
        GoalDefinition(id: "plant8", title: "First sowing", detail: "Plant 8 crops.",
                       requirement: .count(GoalCounter.planted, 8), coins: 40, xp: 5),
        GoalDefinition(id: "sleep1", title: "A good night's sleep", detail: "Go to bed in the farmhouse.",
                       requirement: .count(GoalCounter.slept, 1), coins: 30, xp: 5),
        GoalDefinition(id: "harvest20", title: "Harvest time", detail: "Harvest 20 crops.",
                       requirement: .count(GoalCounter.harvested, 20), coins: 80, xp: 10),
        GoalDefinition(id: "sell200", title: "Market day", detail: "Sell goods worth 200 coins at the market.",
                       requirement: .count(GoalCounter.coinsFromSales, 200), coins: 100, xp: 10),
        GoalDefinition(id: "contract1", title: "First order", detail: "Accept an order on your phone, then truck the goods to the client.",
                       requirement: .count(GoalCounter.contractsCompleted, 1), coins: 120, xp: 15),
        GoalDefinition(id: "seeds30", title: "Stock up", detail: "Buy 30 seeds at the seed shop.",
                       requirement: .count(GoalCounter.seedsBought, 30), coins: 60, xp: 10),
        GoalDefinition(id: "field2", title: "A second field", detail: "Buy another field next to your first one (phone → Farm).",
                       requirement: .count(GoalCounter.fieldsBought, 1), coins: 100, xp: 15),
        GoalDefinition(id: "level2", title: "Getting the hang of it", detail: "Reach farmer level 2.",
                       requirement: .level(2), coins: 100, xp: 0),
        GoalDefinition(id: "coop", title: "Chicken keeper", detail: "Fix up the chicken coop behind the farmhouse.",
                       requirement: .penRepaired("coop"), coins: 100, xp: 15),
        GoalDefinition(id: "chickens3", title: "First flock", detail: "Own 3 chickens.",
                       requirement: .animals("chicken", 3), coins: 150, xp: 15),
        GoalDefinition(id: "eggs12", title: "Fresh eggs", detail: "Collect 12 eggs.",
                       requirement: .count(GoalCounter.collected("egg"), 12), coins: 150, xp: 20),
        GoalDefinition(id: "chop5", title: "Lumberjack", detail: "Chop 5 trees in your woodlot.",
                       requirement: .count(GoalCounter.treesChopped, 5), coins: 120, xp: 15),
        GoalDefinition(id: "shop1", title: "Open for business", detail: "Rent the corner shop in the village (level 3).",
                       requirement: .count(GoalCounter.shopRented, 1), coins: 150, xp: 20),
        GoalDefinition(id: "fish1", title: "Gone fishing", detail: "Catch a fish: pick the rod, tap the farm pond, tap when it bites.",
                       requirement: .count(GoalCounter.fishCaught, 1), coins: 80, xp: 10),
        GoalDefinition(id: "storage1", title: "More room", detail: "Build a storage shed (phone → Farm).",
                       requirement: .count(GoalCounter.storageUpgrades, 1), coins: 200, xp: 25),
        GoalDefinition(id: "money3k", title: "Nest egg", detail: "Have 3,000 coins.",
                       requirement: .money(3_000), coins: 200, xp: 20),
        GoalDefinition(id: "land1", title: "Room to grow", detail: "Buy a parcel of land next to your farm.",
                       requirement: .count(GoalCounter.landBought, 1), coins: 300, xp: 40),
        GoalDefinition(id: "forage15", title: "Forager", detail: "Pick 15 wild finds (they turn up in the woods and meadows every morning).",
                       requirement: .count(GoalCounter.foraged, 15), coins: 200, xp: 25),
        GoalDefinition(id: "orchard", title: "Orchard", detail: "Plant 2 fruit trees.",
                       requirement: .count(GoalCounter.fruitTreesPlanted, 2), coins: 150, xp: 20),
        GoalDefinition(id: "sprinkler1", title: "Rain maker", detail: "Place a sprinkler in your fields.",
                       requirement: .count(GoalCounter.sprinklersPlaced, 1), coins: 150, xp: 25),
        GoalDefinition(id: "workshop1", title: "Handmade", detail: "Place a workshop (phone → Farm) and make something in it.",
                       requirement: .count(GoalCounter.crafted, 1), coins: 200, xp: 25),
        GoalDefinition(id: "contract5", title: "Reliable supplier", detail: "Finish 5 orders. Reliable farms get bigger ones.",
                       requirement: .count(GoalCounter.contractsCompleted, 5), coins: 400, xp: 40),
        GoalDefinition(id: "shop500", title: "Shopkeeper", detail: "Take in 500 coins at your shop.",
                       requirement: .count(GoalCounter.coinsFromShop, 500), coins: 250, xp: 30),
        GoalDefinition(id: "worker1", title: "A helping hand", detail: "Hire a farmhand (phone → Farm).",
                       requirement: .count(GoalCounter.workersHired, 1), coins: 300, xp: 40),
        GoalDefinition(id: "crafted50", title: "Artisan", detail: "Make 50 goods in your workshops.",
                       requirement: .count(GoalCounter.crafted, 50), coins: 500, xp: 50),
        GoalDefinition(id: "fish25", title: "Angler", detail: "Catch 25 fish. Willow Lake, south of the village, has bigger ones.",
                       requirement: .count(GoalCounter.fishCaught, 25), coins: 350, xp: 40),
        GoalDefinition(id: "cows2", title: "Dairy farmer", detail: "Own 2 cows.",
                       requirement: .animals("cow", 2), coins: 300, xp: 30),
        GoalDefinition(id: "harvest300", title: "Big harvest", detail: "Harvest 300 crops.",
                       requirement: .count(GoalCounter.harvested, 300), coins: 400, xp: 40),
        GoalDefinition(id: "wool10", title: "Warm wool", detail: "Collect 10 wool.",
                       requirement: .count(GoalCounter.collected("wool"), 10), coins: 400, xp: 40),
        GoalDefinition(id: "level8", title: "Seasoned farmer", detail: "Reach farmer level 8.",
                       requirement: .level(8), coins: 500, xp: 0),
        GoalDefinition(id: "goats2", title: "Goat herd", detail: "Buy Goat Hill, fix up its pen and own 2 goats.",
                       requirement: .animals("goat", 2), coins: 500, xp: 50),
        GoalDefinition(id: "truffles5", title: "Truffle hunter", detail: "Collect 5 truffles.",
                       requirement: .count(GoalCounter.collected("truffle"), 5), coins: 500, xp: 50),
        GoalDefinition(id: "money25k", title: "Farming empire", detail: "Have 25,000 coins.",
                       requirement: .money(25_000), coins: 1_500, xp: 100),
    ]

    public static func goal(_ id: String) -> GoalDefinition? { all.first { $0.id == id } }

    /// Current and target amounts (target ≥ 1).
    public static func progress(_ goal: GoalDefinition, in state: GameState) -> (current: Int, target: Int) {
        switch goal.requirement {
        case .count(let counter, let target): (min(target, state.goals.count(counter)), target)
        case .money(let target): (min(target, state.money), target)
        case .level(let target): (min(target, state.progress.level), target)
        case .animals(let species, let target):
            (min(target, state.ranch.allAnimals.filter { $0.speciesID == species }.count), target)
        case .penRepaired(let pen): (state.ranch[pen].isRepaired ? 1 : 0, 1)
        }
    }

    public static func isComplete(_ goal: GoalDefinition, in state: GameState) -> Bool {
        let p = progress(goal, in: state)
        return p.current >= p.target
    }

    /// The goals to show: the first unclaimed ones, in ladder order.
    public static func open(in state: GameState) -> [GoalDefinition] {
        Array(all.filter { !state.goals.claimed.contains($0.id) }.prefix(openAtOnce))
    }
}

extension Simulation {
    /// Collects a completed goal's reward. Returns the goal, or nil if it isn't
    /// open or not done yet.
    public mutating func claimGoal(_ id: String) -> (goal: GoalDefinition, events: [SimEvent])? {
        guard let goal = GoalCatalog.goal(id),
              GoalCatalog.open(in: state).contains(where: { $0.id == id }),
              GoalCatalog.isComplete(goal, in: state) else { return nil }
        let balance = self.balance
        let events = modify { state -> [SimEvent] in
            state.goals.claimed.append(id)
            state.money += goal.coins
            state.finance.earn(goal.coins, LedgerCategory.goals)
            return Progression.addXP(goal.xp, to: &state, balance: balance)
        }
        return (goal, events)
    }

    /// Counts something done toward goals.
    public mutating func recordGoal(_ counter: String, _ amount: Int = 1) {
        modify { $0.goals.add(counter, amount) }
    }
}
