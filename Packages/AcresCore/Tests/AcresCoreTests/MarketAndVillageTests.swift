import XCTest
@testable import AcresCore

final class MarketAndVillageTests: XCTestCase {
    private let balance = Balance.standard

    /// A farm at the market with goods in the truck.
    private func atMarket(_ goods: [String: Int], level: Int = 1) -> Simulation {
        var sim = Simulation(state: .newGame(seed: 5))
        sim.visit(HomeValleyMap.marketZone)
        sim.modify { state in
            state.progress.level = level
            for (item, count) in goods { state.truck.cargo.add(item, count) }
        }
        return sim
    }

    func testSellingLotsLowersThePriceForTheRestOfTheDay() {
        var sim = atMarket(["wheat": 90])
        let trading = Trading(balance: balance)
        let fresh = trading.price(of: "wheat", in: sim.state)!
        XCTAssertEqual(trading.currentPrice(of: "wheat", in: sim.state), fresh)
        let first = trading.quote("wheat", count: 45, in: sim.state)
        XCTAssertEqual(sim.trade { try $0.sell("wheat", count: 45, state: &$1) }, .success(first))
        XCTAssertLessThan(first, fresh * 45, "each one fetches a little less")
        let second = trading.quote("wheat", count: 45, in: sim.state)
        XCTAssertLessThan(second, first, "the second load fetches less")
        XCTAssertLessThan(trading.currentPrice(of: "wheat", in: sim.state)!, fresh)
        // Other goods aren't affected.
        XCTAssertEqual(trading.currentPrice(of: "carrot", in: sim.state), trading.price(of: "carrot", in: sim.state))
    }

    func testThePriceNeverFallsBelowTheFloor() {
        var state = GameState.newGame(seed: 1)
        state.market = MarketState(day: state.clock.dayIndex, sold: ["wheat": 100_000])
        let market = Market(balance: balance)
        XCTAssertEqual(market.factor("wheat", in: state), balance.marketPriceFloor, accuracy: 1e-9)
        XCTAssertGreaterThan(market.quote("wheat", count: 10, unitPrice: 12, in: state), 0)
    }

    func testBuyersComeBackOverTheNextDays() {
        var state = GameState.newGame(seed: 1)
        let today = state.clock.dayIndex
        state.market = MarketState(day: today, sold: ["potato": 40])
        let market = Market(balance: balance)
        let low = market.factor("potato", in: state)
        state.clock = GameClock(dayIndex: today + 1, hour: 10)
        XCTAssertEqual(market.recent("potato", in: state), 20, accuracy: 1e-9, "half come back each day")
        XCTAssertGreaterThan(market.factor("potato", in: state), low)
        state.clock = GameClock(dayIndex: today + 8, hour: 10)
        XCTAssertGreaterThan(market.factor("potato", in: state), 0.99, "a week later it's fresh")
        market.record("potato", count: 1, in: &state)
        XCTAssertEqual(state.market.day, today + 8)
        XCTAssertEqual(state.market.sold["potato"]!, 1, accuracy: 0.5, "faded sales are dropped")
    }

    func testLaterCropsPayMorePerTile() {
        // Coins per tile per watered day, after seeds (regrowing crops: once grown).
        func perDay(_ crop: CropDefinition) -> Double {
            let price = Double(crop.sellPrice.lowerBound + crop.sellPrice.upperBound) / 2
            let yield = Double(crop.yield.lowerBound + crop.yield.upperBound) / 2
            if let regrow = crop.regrowSeconds { return price * yield / (regrow / GameTime.day) }
            return (price * yield - Double(crop.seedCost)) / (crop.growthSeconds / GameTime.day)
        }
        let byLevel = Dictionary(grouping: CropCatalog.all, by: \.unlockLevel)
        let levels = byLevel.keys.sorted()
        for (low, high) in zip(levels, levels.dropFirst()) {
            let bestLow = byLevel[low]!.map(perDay).max()!
            let bestHigh = byLevel[high]!.map(perDay).max()!
            XCTAssertGreaterThanOrEqual(bestHigh, bestLow, "level \(high) has a crop at least as good as level \(low)")
        }
        for crop in CropCatalog.all {
            XCTAssertGreaterThan(perDay(crop), 20, "\(crop.id) is worth a tile")
        }
        XCTAssertGreaterThan(perDay(CropCatalog.crop("melon")!), 2 * perDay(CropCatalog.crop("potato")!))
    }

    func testGivingToAVillageProjectAndFinishingIt() throws {
        var state = GameState.newGame(seed: 2)
        state.progress.level = 4
        state.money = 20_000
        state.inventory.add("plank", 30)
        state.farmer.bag.add("plank", 15)
        state.inventory.add("log", 30)
        let works = VillageWorks(balance: balance)
        let bridge = Village.project("bridge")!

        XCTAssertEqual(try works.giveCoins("bridge", amount: 3_000, state: &state), 3_000)
        XCTAssertEqual(try works.giveCoins("bridge", amount: 50_000, state: &state), 5_000, "only what's still wanted")
        XCTAssertEqual(state.money, 12_000)
        XCTAssertThrowsError(try works.giveCoins("bridge", amount: 10, state: &state))
        XCTAssertFalse(works.isReady(bridge, in: state))

        XCTAssertEqual(try works.giveGoods("bridge", state: &state), 70)
        XCTAssertEqual(state.inventory.count("plank"), 0, "storage first")
        XCTAssertEqual(state.farmer.bag.count("plank"), 5, "then the bag, only what's wanted")
        XCTAssertTrue(works.isReady(bridge, in: state))

        _ = try works.finish("bridge", state: &state)
        XCTAssertEqual(state.village.finished, ["bridge"])
        XCTAssertEqual(state.goals.count(GoalCounter.projectsFinished), 1)
        XCTAssertEqual(Village.perks(state).contractBonus, 0.10, accuracy: 1e-9)
        XCTAssertEqual(Village.fraction(bridge, in: state), 1)
        XCTAssertThrowsError(try works.giveCoins("bridge", amount: 10, state: &state)) { error in
            XCTAssertEqual(error as? VillageFailure, .alreadyFinished)
        }
    }

    func testProjectsUnlockByLevelAndCanNotFinishEarly() {
        var state = GameState.newGame(seed: 2)
        state.money = 1_000_000
        let works = VillageWorks(balance: balance)
        XCTAssertThrowsError(try works.giveCoins("flower_beds", amount: 100, state: &state)) { error in
            XCTAssertEqual(error as? VillageFailure, .locked(level: 3))
        }
        XCTAssertEqual(Village.visible(in: state).map(\.id), ["flower_beds"], "a peek at the first one")
        state.progress.level = 3
        XCTAssertEqual(Village.visible(in: state).map(\.id), ["flower_beds", "bridge"])
        XCTAssertNoThrow(try works.giveCoins("flower_beds", amount: 3_000, state: &state))
        XCTAssertThrowsError(try works.finish("flower_beds", state: &state), "the goods are still wanted")
        XCTAssertGreaterThan(Village.fraction(Village.project("flower_beds")!, in: state), 0.5)
    }

    func testFinishedProjectsHelpAtTheMarket() {
        var state = GameState.newGame(seed: 2)
        let trading = Trading(balance: balance)
        let market = Market(balance: balance)
        let price = trading.price(of: "pumpkin", in: state)!
        state.market = MarketState(day: state.clock.dayIndex, sold: ["pumpkin": 20])
        let factor = market.factor("pumpkin", in: state)
        state.village.finished = ["flower_beds", "market_hall", "harvest_fair", "harbor"]
        XCTAssertGreaterThan(market.factor("pumpkin", in: state), factor, "more buyers")
        XCTAssertEqual(trading.price(of: "pumpkin", in: state)!, Int((Double(price) * 1.05).rounded()))
        state.clock = GameClock(dayIndex: state.clock.dayIndex + 1, hour: 10)
        XCTAssertEqual(market.recent("pumpkin", in: state), 0, accuracy: 1e-9, "buyers come back twice as fast")
    }

    func testEveryProjectWantsThingsTheFarmCanMake() {
        for project in Village.all {
            for item in project.goods.keys {
                XCTAssertNotNil(ItemCatalog.item(item), "\(project.id) wants \(item)")
            }
        }
        XCTAssertEqual(Set(Village.all.map(\.id)).count, Village.all.count)
        XCTAssertEqual(Village.all.map(\.unlockLevel), Village.all.map(\.unlockLevel).sorted())
    }
}
