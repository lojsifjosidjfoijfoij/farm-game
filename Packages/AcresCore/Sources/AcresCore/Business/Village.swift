import Foundation

/// A village project the farm can pay for: coins and goods, given a bit at a
/// time, then something lasting in the village (you'll see it standing there)
/// and a perk for the farm. The long dream once the farm itself is built.
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
    public let perks: [VillagePerk]
    /// What stands in the village once it's done (see `VillageLayout`).
    public let pieces: [MapObject]
    /// Where its "coming soon" sign stands while it's open.
    public let signSpot: Vec2
}

/// What a finished project does for the farm.
public enum VillagePerk: Sendable, Equatable {
    /// More buyers: the market takes this much more before prices fall.
    case marketDepth(Double)
    /// Buyers come back faster: what still weighs on prices after a day is
    /// multiplied by this.
    case marketMemory(Double)
    /// Orders pay this much more (added to the contract bonus).
    case contractBonus(Double)
    /// Every market price is this much higher.
    case marketPrices(Double)
}

/// The combined effect of every finished project.
public struct VillagePerks: Sendable, Equatable {
    public var marketDepth: Double = 1
    public var marketMemory: Double = 1
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

    /// Projects were renamed to fit the map before they shipped widely (the
    /// bridge became the post office, the harbor the boathouse, the
    /// lighthouse the windmill); saves from that week keep what they gave.
    static let renamed = ["bridge": "post_office", "harbor": "boathouse", "lighthouse": "windmill"]

    private enum CodingKeys: String, CodingKey { case progress, finished }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let progress = try container.decode([String: ProjectProgress].self, forKey: .progress)
        let finished = try container.decode([String].self, forKey: .finished)
        self.progress = Dictionary(progress.map { (Self.renamed[$0.key] ?? $0.key, $0.value) }) { a, _ in a }
        self.finished = finished.map { Self.renamed[$0] ?? $0 }
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
            id: "flower_beds", name: "Flowers along the street",
            blurb: "The village council would love planters of flowers along the street, so people linger on their way to market.",
            unlockLevel: 3, coins: 3_000, goods: ["plank": 20, "sunflower": 10], xp: 60,
            reward: "More people stroll down to the market: it takes 25% more of everything before prices fall.",
            perks: [.marketDepth(1.25)],
            pieces: [77.6, 80.4, 98.2, 104.2, 110.0, 115.0].enumerated().map {
                MapObject(kind: "prop_flower_planter", position: Vec2($0.element, 21.1), variant: $0.offset)
            },
            signSpot: Vec2(79.0, 21.2)),
        VillageProject(
            id: "post_office", name: "A post office",
            blurb: "Letters take a week to find the valley. A little post office by the street, and farms and towns further out could send their orders.",
            unlockLevel: 4, coins: 8_000, goods: ["plank": 40, "log": 30], xp: 100,
            reward: "Orders come from further away: every order pays 10% more.",
            perks: [.contractBonus(0.10)],
            pieces: [MapObject(kind: "building_post_office", position: Vec2(90.8, 17.9))],
            signSpot: Vec2(90.8, 19.2)),
        VillageProject(
            id: "market_hall", name: "A roof for the market",
            blurb: "A timber market hall behind the square, so the stalls can stay open in rain and snow.",
            unlockLevel: 5, coins: 15_000, goods: ["plank": 60, "honey": 15, "flour": 20], xp: 150,
            reward: "Buyers come back twice as fast after you've sold a lot.",
            perks: [.marketMemory(0.5)],
            pieces: [MapObject(kind: "building_market_hall", position: Vec2(97, 31.4))],
            signSpot: Vec2(97, 32.2)),
        VillageProject(
            id: "harvest_fair", name: "The harvest fair",
            blurb: "Bring back the old fair on the meadow by the lake path: a bandstand, lanterns and prize tables for the best produce.",
            unlockLevel: 6, coins: 25_000, goods: ["pumpkin": 15, "cheese": 10, "strawberry_jam": 10], xp: 200,
            reward: "Word of the valley gets around: every market price is 5% higher.",
            perks: [.marketPrices(1.05)],
            pieces: [
                MapObject(kind: "prop_bunting", position: Vec2(108.2, 15.6)),
                MapObject(kind: "prop_bunting", position: Vec2(112.2, 15.6), variant: 1),
                MapObject(kind: "building_bandstand", position: Vec2(110.2, 12.4)),
                MapObject(kind: "prop_fair_lantern", position: Vec2(106.4, 14.4)),
                MapObject(kind: "prop_fair_lantern", position: Vec2(114.0, 14.4), variant: 1),
                MapObject(kind: "prop_fair_lantern", position: Vec2(106.4, 10.6), variant: 2),
                MapObject(kind: "prop_fair_lantern", position: Vec2(114.0, 10.6), variant: 3),
                MapObject(kind: "prop_prize_table", position: Vec2(107.6, 9.6)),
                MapObject(kind: "prop_hay_bale", position: Vec2(112.8, 9.4)),
                MapObject(kind: "prop_hay_bale", position: Vec2(115.2, 12.2), variant: 1),
            ],
            signSpot: Vec2(110.2, 12.8)),
        VillageProject(
            id: "boathouse", name: "A jetty on Willow Lake",
            blurb: "Rebuild the old boathouse and its jetty, and folk from the towns will come out to row on the lake of a Sunday.",
            unlockLevel: 7, coins: 50_000, goods: ["plank": 120, "cloth": 15, "smoked_trout": 15], xp: 300,
            reward: "Day-trippers stroll up to the market: it takes 50% more of everything before prices fall.",
            perks: [.marketDepth(1.5)],
            pieces: [
                MapObject(kind: "building_boathouse", position: Vec2(101.6, 7.6)),
                MapObject(kind: "prop_rowboat", position: Vec2(97.6, 6.6)),
                MapObject(kind: "prop_rowboat", position: Vec2(94.2, 8.8), variant: 1),
            ],
            signSpot: Vec2(102.4, 10.8)),
        VillageProject(
            id: "windmill", name: "The old windmill",
            blurb: "The windmill on the hill above the village has stood still for forty years. Get its sails turning again, and the valley is on the map.",
            unlockLevel: 8, coins: 100_000, goods: ["plank": 80, "sunflower_oil": 20, "goat_cheese": 15], xp: 500,
            reward: "The valley is on the map: orders pay 10% more and every market price is 5% higher.",
            perks: [.contractBonus(0.10), .marketPrices(1.05)],
            pieces: [MapObject(kind: "building_windmill", position: VillageLayout.windmillSpot)],
            signSpot: Vec2(108.4, 38.0)),
    ]

    public static func project(_ id: String) -> VillageProject? { all.first { $0.id == id } }

    /// The combined perks of the finished projects.
    public static func perks(_ state: GameState) -> VillagePerks {
        var perks = VillagePerks()
        for project in all where state.village.finished.contains(project.id) {
            for perk in project.perks {
                switch perk {
                case .marketDepth(let x): perks.marketDepth *= x
                case .marketMemory(let x): perks.marketMemory *= x
                case .contractBonus(let x): perks.contractBonus += x
                case .marketPrices(let x): perks.marketPrices *= x
                }
            }
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

    /// Everything the farm has given the village, in coins (goods at their usual value).
    public static func given(_ state: GameState) -> Int {
        func worth(coins: Int, goods: [String: Int]) -> Int {
            coins + goods.reduce(0) { sum, entry in
                sum + entry.value * (ItemCatalog.item(entry.key).map { ($0.value.lowerBound + $0.value.upperBound) / 2 } ?? 0)
            }
        }
        var total = 0
        for project in all {
            if state.village.finished.contains(project.id) {
                total += worth(coins: project.coins, goods: project.goods)
            } else if let given = state.village.progress[project.id] {
                total += worth(coins: given.coins, goods: given.goods)
            }
        }
        return total
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

/// Giving to village projects. Coins from the pocket, goods from farm storage,
/// the bag and the truck bed (the village sends a cart round for them).
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
            return (item, needed, state.inventory.count(item) + state.farmer.bag.count(item) + state.truck.cargo.count(item))
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

    /// Gives every wanted good the farm has (storage first, then the bag, then the truck); returns how many.
    @discardableResult
    public func giveGoods(_ id: String, state: inout GameState) throws(VillageFailure) -> Int {
        let project = try open(id, state)
        var given = 0
        for need in goodsNeeded(project, in: state) where need.needed > 0 {
            let fromStorage = min(need.needed, state.inventory.count(need.item))
            state.inventory.remove(need.item, fromStorage)
            let fromBag = min(need.needed - fromStorage, state.farmer.bag.count(need.item))
            state.farmer.bag.remove(need.item, fromBag)
            let fromTruck = min(need.needed - fromStorage - fromBag, state.truck.cargo.count(need.item))
            state.truck.cargo.remove(need.item, fromTruck)
            let total = fromStorage + fromBag + fromTruck
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

/// What the village projects put in the world: finished projects stand in the
/// village, open ones have a "coming soon" sign where they'll go, and the old
/// windmill's ruin waits on its hill until it's rebuilt. The map keeps these
/// sites clear (`HomeValleyMap`); this decides what stands on them.
public enum VillageLayout {
    /// The windmill's foot (the ruin and the rebuilt mill stand on the same spot).
    public static let windmillSpot = Vec2(110.6, 39.0)

    /// Ground each project needs, kept clear of trees and bushes on the map.
    public static let sites: [TileRect] = [
        TileRect(minX: 76.6, minY: 20.4, maxX: 81.4, maxY: 21.8),
        TileRect(minX: 97.2, minY: 20.4, maxX: 99.2, maxY: 21.8),
        TileRect(minX: 103.2, minY: 20.4, maxX: 105.2, maxY: 21.8),
        TileRect(minX: 109.0, minY: 20.4, maxX: 115.6, maxY: 21.8),
        TileRect(minX: 88.6, minY: 17.2, maxX: 93.0, maxY: 21.2),
        TileRect(minX: 91.8, minY: 30.8, maxX: 102.2, maxY: 37.0),
        TileRect(minX: 103.8, minY: 8.6, maxX: 116.6, maxY: 16.8),
        TileRect(minX: 100.8, minY: 5.4, maxX: 106.0, maxY: 11.4),
        TileRect(minX: 105.4, minY: 35.0, maxX: 116.0, maxY: 46.5),
    ]

    /// Where to look to see a project (the middle of its pieces, a little north for their height).
    public static func focus(for project: VillageProject) -> Vec2 {
        let points = project.pieces.map(\.position)
        guard !points.isEmpty else { return project.signSpot }
        let x = points.map(\.x).reduce(0, +) / Double(points.count)
        let y = points.map(\.y).reduce(0, +) / Double(points.count)
        return Vec2(x, y + 1.5)
    }

    /// Everything standing for the village projects right now.
    public static func standing(_ state: GameState) -> [MapObject] {
        var objects: [MapObject] = []
        for project in Village.all {
            if state.village.finished.contains(project.id) {
                objects += project.pieces
            } else {
                if project.id == "windmill" { objects.append(MapObject(kind: "building_windmill_ruin", position: windmillSpot)) }
                if state.progress.level >= project.unlockLevel {
                    objects.append(MapObject(kind: "prop_project_sign", position: project.signSpot))
                }
            }
        }
        return objects
    }

    /// Tiles the project buildings take up (for obstacles). Signs, lanterns,
    /// bunting and rowboats don't block.
    public static func blockedTiles(_ state: GameState) -> Set<TileCoord> {
        var tiles = Set<TileCoord>()
        for object in standing(state) where blocks(object.kind) {
            guard let rect = ObjectFootprint.rect(for: object) else { continue }
            tiles.formUnion(rect.coveredTiles)
        }
        return tiles
    }

    /// The project whose sign or building was tapped. Sprites stand north of
    /// their foot, so a tap anywhere on the picture counts. Rowboats don't:
    /// tapping the water is for fishing.
    public static func project(at spot: Vec2, in state: GameState) -> VillageProject? {
        for project in Village.all {
            var objects: [MapObject]
            if state.village.finished.contains(project.id) {
                objects = project.pieces.filter { $0.kind != "prop_rowboat" }
            } else {
                objects = []
                if project.id == "windmill" { objects.append(MapObject(kind: "building_windmill_ruin", position: windmillSpot)) }
                if state.progress.level >= project.unlockLevel {
                    objects.append(MapObject(kind: "prop_project_sign", position: project.signSpot))
                }
            }
            if objects.contains(where: { hitRect($0).contains(spot) }) { return project }
        }
        return nil
    }

    private static func hitRect(_ object: MapObject) -> TileRect {
        let p = object.position
        guard let spec = AssetManifest.spec(named: object.kind) else {
            return TileRect(minX: p.x - 0.5, minY: p.y - 0.3, maxX: p.x + 0.5, maxY: p.y + 1)
        }
        let half = max(0.5, spec.tilesWide * 0.45)
        return TileRect(minX: p.x - half, minY: p.y - 0.3, maxX: p.x + half, maxY: p.y + max(1, spec.tilesHigh * 0.85))
    }

    private static func blocks(_ kind: String) -> Bool {
        kind.hasPrefix("building_") || kind == "prop_flower_planter" || kind == "prop_prize_table" || kind == "prop_hay_bale"
    }
}
