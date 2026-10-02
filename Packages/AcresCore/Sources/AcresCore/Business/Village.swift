import Foundation

/// A village project the farm can pay for: coins and goods, given a bit at a
/// time, then something lasting for the whole village (and a perk for you).
/// The long dream once the farm itself is built.
public struct VillageProject: Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let blurb: String
    /// Farmer level needed to start giving.
    public let unlockLevel: Int
    public let coins: Int
    /// Goods wanted, by item.
    public let goods: [String: Int]
    public let xp: Int
    /// What finishing it does, in a sentence.
    public let reward: String
    public let perk: VillagePerk
}

/// What a finished project does for the farm.
public enum VillagePerk: Sendable, Equatable {
    /// More buyers: the market takes this much more before prices fall.
    case marketDepth(Double)
    /// Buyers come back faster: recovery per day is this much quicker.
    case marketRecovery(Double)
    /// Orders pay this much more (added to the contract bonus).
    case contractBonus(Double)
    /// Every market price is this much higher.
    case marketPrices(Double)
}

/// The combined effect of every finished project.
public struct VillagePerks: Sendable, Equatable {
    public var marketDepth: Double = 1
    public var marketRecovery: Double = 1
    public var contractBonus: Double = 0
    public var marketPrices: Double = 1
}

/// How much of a project has been given.
public struct ProjectProgress: Codable, Equatable, Sendable {
    public var coins: Int
    public var goods: [String: Int]

    public init(coins: Int = 0, goods: [String: Int] = [:]) {
        self.coins = coins
        self.goods = goods
    }
}

public struct VillageState: Codable, Equatable, Sendable {
    public var progress: [String: ProjectProgress]
    public var finished: [String]

    public init(progress: [String: ProjectProgress] = [:], finished: [String] = []) {
        self.progress = progress
        self.finished = finished
    }
}

public enum VillageFailure: Error, Equatable, Sendable {
    case unknownProject
    case locked(level: Int)
    case alreadyFinished
    case notEnoughMoney
    case nothingToGive
}

public enum Village {
    public static let all: [VillageProject] = [
        VillageProject(
            id: "flower_beds", name: "Flowers on the green",
            blurb: "The village council wants flower beds and benches round the village green, so people linger on market days.",
            unlockLevel: 3, coins: 3_000, goods: ["plank": 20, "sunflower": 10], xp: 60,
            reward: "More people stroll by the market: it takes 25% more of each good before prices fall.",
            perk: .marketDepth(1.25)),
        VillageProject(
            id: "bridge", name: "Mend the old bridge",
            blurb: "The stone bridge on the county road is crumbling. Farms further out would send for your goods if carts could cross.",
            unlockLevel: 4, coins: 8_000, goods: ["plank": 40, "log": 30], xp: 100,
            reward: "Clients from further away: orders pay 10% more.",
            perk: .contractBonus(0.10)),
        VillageProject(
            id: "market_hall", name: "A roof for the market",
            blurb: "A timber market hall, so the stalls stay open in rain and snow.",
            unlockLevel: 5, coins: 15_000, goods: ["plank": 60, "honey": 15, "flour": 20], xp: 150,
            reward: "Buyers come back twice as fast after you've sold a lot.",
            perk: .marketRecovery(2)),
        VillageProject(
            id: "harvest_fair", name: "The harvest fair",
            blurb: "Bring back the old autumn fair: a dance floor, lanterns and prize tables for the best produce.",
            unlockLevel: 6, coins: 25_000, goods: ["pumpkin": 15, "cheese": 10, "strawberry_jam": 10], xp: 200,
            reward: "The village's name gets around: every market price is 5% higher.",
            perk: .marketPrices(1.05)),
        VillageProject(
            id: "harbor", name: "Rebuild the harbor",
            blurb: "The jetty at Willow Lake fell in years ago. Boats from the towns across the water would buy straight from the quay.",
            unlockLevel: 7, coins: 50_000, goods: ["plank": 120, "cloth": 15, "smoked_trout": 15], xp: 300,
            reward: "Boats bring buyers from the towns: the market takes 50% more before prices fall.",
            perk: .marketDepth(1.5)),
        VillageProject(
            id: "lighthouse", name: "Light the lighthouse",
            blurb: "The old lighthouse on the point has been dark for a generation. Light it again, and Acres is on the map.",
            unlockLevel: 8, coins: 100_000, goods: ["plank": 80, "sunflower_oil": 20, "goat_cheese": 15], xp: 500,
            reward: "Your farm's name on the lamp room wall, orders pay 10% more and prices are 5% higher.",
            perk: .marketPrices(1.05)),
    ]

    public static func project(_ id: String) -> VillageProject? { all.first { $0.id == id } }

    /// The combined perks of the finished projects (the lighthouse also adds to orders).
    public static func perks(_ state: GameState) -> VillagePerks {
        var perks = VillagePerks()
        for project in all where state.village.finished.contains(project.id) {
            switch project.perk {
            case .marketDepth(let x): perks.marketDepth *= x
            case .marketRecovery(let x): perks.marketRecovery *= x
            case .contractBonus(let x): perks.contractBonus += x
            case .marketPrices(let x): perks.marketPrices *= x
            }
            if project.id == "lighthouse" { perks.contractBonus += 0.10 }
        }
        return perks
    }

    public static func progress(_ project: VillageProject, in state: GameState) -> ProjectProgress {
        state.village.progress[project.id] ?? ProjectProgress()
    }

    /// How much of the project is done, 0…1 (coins and goods weigh by value).
    public static func fraction(_ project: VillageProject, in state: GameState) -> Double {
        if state.village.finished.contains(project.id) { return 1 }
        let given = progress(project, in: state)
        var have = Double(min(given.coins, project.coins))
        var need = Double(project.coins)
        for (item, amount) in project.goods {
            let value = Double(ItemCatalog.item(item).map { ($0.value.lowerBound + $0.value.upperBound) / 2 } ?? 1)
            have += value * Double(min(amount, given.goods[item] ?? 0))
            need += value * Double(amount)
        }
        return need > 0 ? have / need : 1
    }

    /// The projects shown in the journal: finished ones, then open ones up to the next locked one.
    public static func visible(in state: GameState) -> [VillageProject] {
        var result: [VillageProject] = []
        for project in all {
            result.append(project)
            if state.progress.level < project.unlockLevel { break }
        }
        return result
    }
}

/// Giving to village projects. Coins from the pocket, goods from farm storage
/// and the bag (the journal sends a cart for them).
public struct VillageWorks: Sendable {
    public let balance: Balance

    public init(balance: Balance) {
        self.balance = balance
    }

    private func open(_ id: String, _ state: GameState) throws(VillageFailure) -> VillageProject {
        guard let project = Village.project(id) else { throw .unknownProject }
        guard !state.village.finished.contains(id) else { throw .alreadyFinished }
        guard state.progress.level >= project.unlockLevel else { throw .locked(level: project.unlockLevel) }
        return project
    }

    /// Coins still wanted.
    public func coinsNeeded(_ project: VillageProject, in state: GameState) -> Int {
        max(0, project.coins - Village.progress(project, in: state).coins)
    }

    /// Goods still wanted, and how many the farm has to give.
    public func goodsNeeded(_ project: VillageProject, in state: GameState) -> [(item: String, needed: Int, have: Int)] {
        let given = Village.progress(project, in: state)
        return project.goods.keys.sorted().map { item in
            let needed = max(0, (project.goods[item] ?? 0) - (given.goods[item] ?? 0))
            return (item, needed, state.inventory.count(item) + state.farmer.bag.count(item))
        }
    }

    /// Gives coins (up to what's still wanted); returns the coins given.
    @discardableResult
    public func giveCoins(_ id: String, amount: Int, state: inout GameState) throws(VillageFailure) -> Int {
        let project = try open(id, state)
        let give = min(amount, coinsNeeded(project, in: state))
        guard give > 0 else { throw .nothingToGive }
        guard state.money >= give else { throw .notEnoughMoney }
        state.money -= give
        state.finance.spend(give, LedgerCategory.village)
        state.village.progress[id, default: ProjectProgress()].coins += give
        return give
    }

    /// Gives every wanted good the farm has (storage first, then the bag); returns how many.
    @discardableResult
    public func giveGoods(_ id: String, state: inout GameState) throws(VillageFailure) -> Int {
        let project = try open(id, state)
        var given = 0
        for need in goodsNeeded(project, in: state) where need.needed > 0 {
            let fromStorage = min(need.needed, state.inventory.count(need.item))
            state.inventory.remove(need.item, fromStorage)
            let fromBag = min(need.needed - fromStorage, state.farmer.bag.count(need.item))
            state.farmer.bag.remove(need.item, fromBag)
            let total = fromStorage + fromBag
            guard total > 0 else { continue }
            state.village.progress[id, default: ProjectProgress()].goods[need.item, default: 0] += total
            given += total
        }
        guard given > 0 else { throw .nothingToGive }
        return given
    }

    public func isReady(_ project: VillageProject, in state: GameState) -> Bool {
        coinsNeeded(project, in: state) == 0 && goodsNeeded(project, in: state).allSatisfy { $0.needed == 0 }
    }

    /// Finishes a fully given project: the perk starts, XP and a goal count.
    public func finish(_ id: String, state: inout GameState) throws(VillageFailure) -> [SimEvent] {
        let project = try open(id, state)
        guard isReady(project, in: state) else { throw .nothingToGive }
        state.village.finished.append(id)
        state.village.progress[id] = nil
        state.goals.add(GoalCounter.projectsFinished)
        return Progression.addXP(project.xp, to: &state, balance: balance)
    }
}
