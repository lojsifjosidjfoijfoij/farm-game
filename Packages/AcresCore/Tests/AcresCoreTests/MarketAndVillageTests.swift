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
        let depth = balance.marketDepth(.crop)
        state.market = MarketState(day: today, sold: ["potato": depth])
        let market = Market(balance: balance)
        let low = market.factor("potato", in: state)
        XCTAssertEqual(low, 0.5, accuracy: 1e-9, "a crop's price halves after its depth in coins")
        state.clock = GameClock(dayIndex: today + 1, hour: 10)
        XCTAssertEqual(market.recent("potato", in: state), depth / 4, accuracy: 1e-9, "three quarters come back each day")
        XCTAssertGreaterThan(market.factor("potato", in: state), 0.75)
        state.clock = GameClock(dayIndex: today + 7, hour: 10)
        XCTAssertGreaterThan(market.factor("potato", in: state), 0.999, "a week later it's fresh")
        market.record("potato", count: 1, in: &state)
        XCTAssertEqual(state.market.day, today + 7)
        XCTAssertEqual(state.market.sold["potato"]!, 24, accuracy: 1e-9, "faded sales are dropped; one potato counts its usual price")
    }

    func testASmallFarmHardlyNoticesAndAOneCropEmpireDoes() {
        let state = GameState.newGame(seed: 1)
        let market = Market(balance: balance)
        // A starter field of wheat (15 tiles, ~52 sheaves) on a fresh market.
        let wheat = market.quote("wheat", count: 52, unitPrice: 12, in: state)
        XCTAssertGreaterThan(Double(wheat), 0.9 * 52 * 12)
        // Day after day of it: the buyers mostly come back overnight.
        var daily = state
        for day in 1...6 {
            daily.clock = GameClock(dayIndex: state.clock.dayIndex + day, hour: 10)
            market.record("wheat", count: 52, in: &daily)
        }
        daily.clock = GameClock(dayIndex: state.clock.dayIndex + 7, hour: 10)
        XCTAssertGreaterThan(Double(market.quote("wheat", count: 52, unitPrice: 12, in: daily)), 0.85 * 52 * 12)
        // Sixty melons (~25,000 coins) in one go end at the floor.
        var empire = state
        market.record("melon", count: 60, in: &empire)
        XCTAssertEqual(market.factor("melon", in: empire), balance.marketPriceFloor, accuracy: 1e-9)
        // The same coins spread over ten goods fetch far more.
        let one = market.quote("melon", count: 60, unitPrice: 415, in: state)
        XCTAssertLessThan(Double(one), 0.5 * 60 * 415)
        XCTAssertGreaterThan(Double(market.quote("melon", count: 6, unitPrice: 415, in: state)), 0.75 * 6 * 415)
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
        state.inventory.add("log", 20)
        state.truck.cargo.add("log", 15)
        let works = VillageWorks(balance: balance)
        let office = Village.project("post_office")!

        XCTAssertEqual(try works.giveCoins("post_office", amount: 3_000, state: &state), 3_000)
        XCTAssertEqual(try works.giveCoins("post_office", amount: 50_000, state: &state), 5_000, "only what's still wanted")
        XCTAssertEqual(state.money, 12_000)
        XCTAssertThrowsError(try works.giveCoins("post_office", amount: 10, state: &state))
        XCTAssertFalse(works.isReady(office, in: state))

        XCTAssertEqual(try works.giveGoods("post_office", state: &state), 70)
        XCTAssertEqual(state.inventory.count("plank"), 0, "storage first")
        XCTAssertEqual(state.farmer.bag.count("plank"), 5, "then the bag, only what's wanted")
        XCTAssertEqual(state.truck.cargo.count("log"), 5, "and the truck")
        XCTAssertTrue(works.isReady(office, in: state))

        _ = try works.finish("post_office", state: &state)
        XCTAssertEqual(state.village.finished, ["post_office"])
        XCTAssertEqual(state.goals.count(GoalCounter.projectsFinished), 1)
        XCTAssertEqual(Village.perks(state).contractBonus, 0.10, accuracy: 1e-9)
        XCTAssertEqual(Village.fraction(office, in: state), 1)
        XCTAssertThrowsError(try works.giveCoins("post_office", amount: 10, state: &state)) { error in
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
        XCTAssertEqual(Village.visible(in: state).map(\.id), ["flower_beds", "post_office"])
        XCTAssertNoThrow(try works.giveCoins("flower_beds", amount: 3_000, state: &state))
        XCTAssertThrowsError(try works.finish("flower_beds", state: &state), "the goods are still wanted")
        XCTAssertGreaterThan(Village.fraction(Village.project("flower_beds")!, in: state), 0.5)
    }

    func testFinishedProjectsHelpAtTheMarket() {
        var state = GameState.newGame(seed: 2)
        let trading = Trading(balance: balance)
        let market = Market(balance: balance)
        let price = trading.price(of: "pumpkin", in: state)!
        state.market = MarketState(day: state.clock.dayIndex, sold: ["pumpkin": 4_000])  // coins' worth
        let factor = market.factor("pumpkin", in: state)
        state.village.finished = ["flower_beds", "market_hall", "harvest_fair", "boathouse"]
        XCTAssertGreaterThan(market.factor("pumpkin", in: state), factor, "more buyers")
        XCTAssertEqual(trading.price(of: "pumpkin", in: state)!, Int((Double(price) * 1.05).rounded()))
        state.clock = GameClock(dayIndex: state.clock.dayIndex + 1, hour: 10)
        XCTAssertEqual(market.recent("pumpkin", in: state), 500, accuracy: 1e-9, "buyers come back twice as fast")
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

    // MARK: The projects in the world

    func testEveryProjectStandsOnClearGroundOffTheRoads() {
        let map = HomeValleyMap.map
        for project in Village.all {
            var objects = project.pieces + [MapObject(kind: "prop_project_sign", position: project.signSpot)]
            if project.id == "windmill" { objects.append(MapObject(kind: "building_windmill_ruin", position: VillageLayout.windmillSpot)) }
            for object in objects {
                XCTAssertNotNil(AssetManifest.assetName(forObjectKind: object.kind, season: .summer), "\(object.kind) has art")
                if object.kind == "prop_rowboat" {
                    XCTAssertNotNil(Waters.water(at: object.position), "rowboats float on the lake")
                } else {
                    XCTAssertTrue(VillageLayout.sites.contains { $0.contains(object.position) }, "\(project.id): \(object.kind) is on its site")
                }
                guard let rect = ObjectFootprint.rect(for: object) else { continue }
                for tile in rect.coveredTiles where object.kind.hasPrefix("building_") && object.kind != "building_boathouse" {
                    XCTAssertFalse(map.solidTiles.contains(tile), "\(project.id): \(object.kind) at \(tile) clear of the map's buildings")
                    XCTAssertFalse([Terrain.asphalt, .gravel].contains(map.terrain(at: tile)), "\(project.id): \(tile) off the road")
                }
            }
        }
        // Nothing wild grows on the sites (no tree poking through the market hall).
        for object in map.objects where object.kind.hasPrefix("tree_") || object.kind.hasPrefix("nature_") {
            if object.kind == "nature_lake" || object.kind == "nature_reeds" || object.kind == "nature_lily_pads" { continue }
            XCTAssertFalse(VillageLayout.sites.contains { $0.contains(object.position) }, "\(object.kind) at \(object.position) is on a site")
        }
    }

    func testWhatStandsFollowsTheProjects() {
        var state = GameState.newGame(seed: 2)
        XCTAssertEqual(VillageLayout.standing(state).map(\.kind), ["building_windmill_ruin"], "just the old ruin at first")
        let ruinTiles = VillageLayout.blockedTiles(state)
        XCTAssertFalse(ruinTiles.isEmpty, "the ruin is solid")
        XCTAssertTrue(Obstacles(map: HomeValleyMap.map, state: state).isBlocked(TileCoord(containing: VillageLayout.windmillSpot + Vec2(0, 0.5))))

        state.progress.level = 4
        XCTAssertEqual(VillageLayout.standing(state).filter { $0.kind == "prop_project_sign" }.count, 2, "signs where open projects will go")
        state.village.finished = ["post_office", "windmill"]
        let kinds = VillageLayout.standing(state).map(\.kind)
        XCTAssertTrue(kinds.contains("building_post_office"))
        XCTAssertTrue(kinds.contains("building_windmill"))
        XCTAssertFalse(kinds.contains("building_windmill_ruin"))
        XCTAssertEqual(kinds.filter { $0 == "prop_project_sign" }.count, 1, "only the flower beds' sign is left")
        let office = Village.project("post_office")!
        XCTAssertTrue(Obstacles.built(state).contains(TileCoord(containing: office.pieces[0].position + Vec2(0, 0.5))))
    }

    func testTappingASignOrABuildingFindsItsProject() {
        var state = GameState.newGame(seed: 2)
        XCTAssertEqual(VillageLayout.project(at: VillageLayout.windmillSpot + Vec2(0, 2), in: state)?.id, "windmill", "the ruin")
        let hall = Village.project("market_hall")!
        XCTAssertNil(VillageLayout.project(at: hall.signSpot + Vec2(0, 0.5), in: state), "no sign before the level")
        state.progress.level = 5
        XCTAssertEqual(VillageLayout.project(at: hall.signSpot + Vec2(0, 0.5), in: state)?.id, "market_hall")
        state.village.finished = ["market_hall", "boathouse"]
        XCTAssertEqual(VillageLayout.project(at: hall.pieces[0].position + Vec2(3, 3), in: state)?.id, "market_hall", "the hall's roof")
        XCTAssertNil(VillageLayout.project(at: Vec2(94.2, 9.0), in: state), "the water by a rowboat is for fishing")
        XCTAssertNil(VillageLayout.project(at: Vec2(70, 10), in: state))
    }

    func testOldProjectNamesCarryOver() throws {
        let json = #"{ "finished": ["harbor"], "progress": { "bridge": { "coins": 500, "goods": {} }, "lighthouse": { "coins": 7, "goods": { "plank": 2 } } } }"#
        let village = try JSONDecoder().decode(VillageState.self, from: Data(json.utf8))
        XCTAssertEqual(village.finished, ["boathouse"])
        XCTAssertEqual(village.progress["post_office"], ProjectProgress(coins: 500))
        XCTAssertEqual(village.progress["windmill"], ProjectProgress(coins: 7, goods: ["plank": 2]))
    }
}
