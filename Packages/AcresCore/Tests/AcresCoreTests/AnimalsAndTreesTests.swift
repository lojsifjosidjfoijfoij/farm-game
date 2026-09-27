import XCTest
@testable import AcresCore

final class AnimalTests: XCTestCase {

    let coop = PenCatalog.pen("coop")!
    let chicken = AnimalCatalog.species("chicken")!

    /// A farm at level 5 with plenty of coins, truck in the yard.
    private func farm(level: Int = 5, money: Int = 10_000, balance: Balance = .standard) -> Simulation {
        var state = GameState.newGame(seed: 7, balance: balance)
        state.progress.level = level
        state.money = money
        return Simulation(state: state, balance: balance)
    }

    /// Tops up the coop's trough for a day.
    private func fillTrough(_ sim: inout Simulation) {
        sim.modify { $0.ranch["coop"].waterUntil = $0.worldTime + GameTime.day * 2 }
    }

    /// A repaired coop with `count` chicks bought at the livestock market.
    private func farmWithChicks(_ count: Int, balance: Balance = .standard) -> Simulation {
        var sim = farm(balance: balance)
        XCTAssertEqual(sim.work(.repair, on: coop).outcome, .repaired(penID: "coop"))
        sim.visit(HomeValleyMap.livestockZone)
        for _ in 0..<count {
            _ = sim.trade { try $0.buyAnimal("chicken", state: &$1) }
        }
        sim.goHome()
        return sim
    }

    func testRepairingAPenNeedsLevelAndCoins() {
        var low = farm(level: 1)
        XCTAssertEqual(low.work(.repair, on: coop).outcome, .failed(.locked(level: 2)))
        var poor = farm(money: 10)
        XCTAssertEqual(poor.work(.repair, on: coop).outcome, .failed(.notEnoughMoney))

        var sim = farm()
        XCTAssertEqual(Ranching(balance: sim.balance).suggestedAction(for: coop, in: sim.state), .repair)
        XCTAssertEqual(sim.work(.repair, on: coop).outcome, .repaired(penID: "coop"))
        XCTAssertEqual(sim.state.money, 10_000 - coop.repairCost)
        XCTAssertTrue(sim.state.ranch["coop"].isRepaired)
        XCTAssertTrue(sim.state.ranch["coop"].hasWater(at: sim.state.worldTime), "repairs come with fresh water")
        XCTAssertEqual(sim.work(.repair, on: coop).outcome, .failed(.alreadyRepaired))
    }

    func testPensAreWorkedFromTheGate() {
        var sim = farm()
        sim.visit(HomeValleyMap.marketZone)
        XCTAssertEqual(sim.perform(.repair, on: coop).outcome, .failed(.tooFar))
        sim.stand(at: HomeValleyMap.farmhouseDoor)
        XCTAssertEqual(sim.perform(.repair, on: coop).outcome, .failed(.tooFar), "the door is too far from the coop")
        sim.stand(at: Ranching.workSpot(coop))
        XCTAssertEqual(sim.perform(.repair, on: coop).outcome, .repaired(penID: "coop"))
    }

    func testBuyingAnimals() {
        var sim = farm()
        sim.visit(HomeValleyMap.livestockZone)
        XCTAssertEqual(sim.trade { try $0.buyAnimal("chicken", state: &$1) }.map(\.name), .failure(.penNotRepaired(penID: "coop")))

        var away = farmWithChicks(0)
        XCTAssertEqual(away.trade { try $0.buyAnimal("chicken", state: &$1) }.map(\.name), .failure(.notAtShop(.livestock)))

        var shop = farmWithChicks(0)
        shop.visit(HomeValleyMap.livestockZone)
        let money = shop.state.money
        for _ in 0..<coop.capacity {
            guard case .success = shop.trade({ try $0.buyAnimal("chicken", state: &$1) }) else { return XCTFail("buy failed") }
        }
        XCTAssertEqual(shop.state.money, money - coop.capacity * chicken.price)
        XCTAssertEqual(shop.trade { try $0.buyAnimal("chicken", state: &$1) }.map(\.name), .failure(.penFull(penID: "coop")))

        let animals = shop.state.ranch["coop"].animals
        XCTAssertEqual(Set(animals.map(\.name)).count, animals.count, "every animal gets its own name")
        XCTAssertEqual(animals.map(\.id), Array(1...coop.capacity))
        XCTAssertTrue(animals.allSatisfy { !$0.isAdult && !$0.isHungry })

        var pigs = farm(level: 5)
        pigs.visit(HomeValleyMap.livestockZone)
        XCTAssertEqual(pigs.trade { try $0.buyAnimal("pig", state: &$1) }.map(\.name), .failure(.locked(level: 6)))
    }

    func testYoungAnimalsGrowUpHungry() {
        var sim = farmWithChicks(1)
        XCTAssertNil(Ranching(balance: sim.balance).suggestedAction(for: coop, in: sim.state), "chicks need nothing")
        let events = sim.advance(by: chicken.growUpSeconds + 1, mode: .live)
        XCTAssertTrue(events.contains(.animalGrewUp(penID: "coop", animalID: 1)))
        XCTAssertTrue(sim.state.ranch["coop"].animals[0].isHungry)
    }

    func testTheOneTapOrderIsCollectWaterFeed() {
        var sim = farmWithChicks(2)
        sim.advance(by: chicken.growUpSeconds, mode: .live)
        fillTrough(&sim)
        let ranching = Ranching(balance: sim.balance)
        XCTAssertEqual(ranching.suggestedAction(for: coop, in: sim.state), .feed)
        sim.modify { $0.ranch["coop"].waterUntil = 0 }
        XCTAssertEqual(ranching.suggestedAction(for: coop, in: sim.state), .water)
        XCTAssertEqual(sim.work(.water, on: coop).outcome, .watered)
        XCTAssertEqual(ranching.suggestedAction(for: coop, in: sim.state), .feed)
    }

    func testFeedingUsesTheFavouriteFoodAndCanRunOut() {
        var sim = farmWithChicks(3)
        sim.advance(by: chicken.growUpSeconds, mode: .live)
        fillTrough(&sim)
        sim.modify { $0.inventory.add("wheat", 1); $0.inventory.add("animal_feed", 1) }
        let before = sim.state.ranch["coop"].animals[0].happiness
        XCTAssertEqual(sim.work(.feed, on: coop).outcome, .fed(animals: 2, eaten: ["wheat": 1, "animal_feed": 1]))
        let animals = sim.state.ranch["coop"].animals
        XCTAssertEqual(animals.filter(\.isHungry).count, 1)
        XCTAssertEqual(animals[0].happiness, before + sim.balance.happinessPerFeeding, accuracy: 1e-9)
        XCTAssertEqual(sim.work(.feed, on: coop).outcome, .failed(.noFeed(speciesID: "chicken")))
    }

    func testProductionIsTwiceAsFastWithWater() {
        var sim = farmWithChicks(1)
        sim.advance(by: chicken.growUpSeconds, mode: .live)
        sim.modify { $0.inventory.add("wheat", 5) }
        _ = sim.work(.feed, on: coop)
        // The trough runs dry half-way through the product.
        let half = chicken.produceSeconds / 2
        sim.modify { $0.ranch["coop"].waterUntil = $0.worldTime + half }
        sim.advance(by: half, mode: .live)
        XCTAssertFalse(sim.state.ranch["coop"].animals[0].hasProduct)
        sim.advance(by: half, mode: .live)
        XCTAssertFalse(sim.state.ranch["coop"].animals[0].hasProduct, "dry: only half speed")
        let events = sim.advance(by: half + 1, mode: .live)
        XCTAssertTrue(sim.state.ranch["coop"].animals[0].hasProduct)
        XCTAssertTrue(events.contains(.animalProductReady(penID: "coop", animalID: 1)))
    }

    func testCollectingGivesProductsAndXPThenTheyAreHungryAgain() {
        var sim = farmWithChicks(2)
        sim.advance(by: chicken.growUpSeconds, mode: .live)
        fillTrough(&sim)
        sim.modify { $0.inventory.add("wheat", 5) }
        _ = sim.work(.feed, on: coop)
        sim.advance(by: chicken.produceSeconds, mode: .live)
        XCTAssertEqual(Ranching(balance: sim.balance).suggestedAction(for: coop, in: sim.state), .collect)
        let xp = sim.state.progress.xp
        guard case .collected(let items, let gained) = sim.work(.collect, on: coop).outcome else { return XCTFail() }
        XCTAssertEqual(gained, 2 * chicken.xp)
        XCTAssertTrue((2...4).contains(items["egg"] ?? 0))
        XCTAssertEqual(sim.state.inventory.count("egg"), items["egg"])
        XCTAssertEqual(sim.state.progress.xp, xp + gained)
        XCTAssertTrue(sim.state.ranch["coop"].animals.allSatisfy(\.isHungry))
    }

    func testFullStorageLeavesProductsWaiting() {
        var balance = Balance.standard
        balance.storageCapacity = 7
        var sim = farmWithChicks(1, balance: balance)
        sim.advance(by: chicken.growUpSeconds, mode: .live)
        fillTrough(&sim)
        sim.modify { $0.inventory.add("wheat", 1) }
        _ = sim.work(.feed, on: coop)
        sim.advance(by: chicken.produceSeconds, mode: .live)
        sim.modify { $0.inventory.add("log", 7) }
        let rng = sim.state.rng
        XCTAssertEqual(sim.work(.collect, on: coop).outcome, .failed(.storageFull))
        XCTAssertTrue(sim.state.ranch["coop"].animals[0].hasProduct)
        XCTAssertEqual(sim.state.rng, rng, "a refused collect doesn't use up luck")
    }

    func testHungryAnimalsGrowSadAndHappyOnesGiveBonuses() {
        var sim = farmWithChicks(1)
        sim.advance(by: chicken.growUpSeconds + sim.balance.realSecondsPerGameDay, mode: .offline)
        XCTAssertEqual(sim.state.ranch["coop"].animals[0].happiness,
                       sim.balance.newAnimalHappiness - sim.balance.happinessDecayPerDay, accuracy: 1e-6)
        sim.advance(by: 24 * 3600, mode: .offline)
        XCTAssertEqual(sim.state.ranch["coop"].animals[0].happiness, 0, "never below zero")
        XCTAssertEqual(Ranching.bonusChance(happiness: 0.2), 0)
        XCTAssertEqual(Ranching.bonusChance(happiness: 1), 1)
    }

    func testOneBigAdvanceEqualsManySmallOnes() {
        var a = farmWithChicks(3)
        a.modify { $0.inventory.add("wheat", 10) }
        a.advance(by: chicken.growUpSeconds, mode: .live)
        _ = a.work(.feed, on: coop)
        a.modify { $0.ranch["coop"].waterUntil = $0.worldTime + 70 }
        var b = a
        a.advance(by: 3 * 3600, mode: .offline)
        for _ in 0..<(3 * 3600 / 7) { b.advance(by: 7, mode: .offline) }
        b.advance(by: Double(3 * 3600 % 7), mode: .offline)
        for (x, y) in zip(a.state.ranch["coop"].animals, b.state.ranch["coop"].animals) {
            XCTAssertEqual(x.production ?? -1, y.production ?? -1, accuracy: 1e-6)
            XCTAssertEqual(x.happiness, y.happiness, accuracy: 1e-6)
            XCTAssertEqual(x.age, y.age, accuracy: 1e-6)
        }
    }

    func testAwaySummaryMentionsTheAnimals() {
        var sim = farmWithChicks(2)
        sim.modify { $0.inventory.add("wheat", 1) }
        sim.advance(by: chicken.growUpSeconds, mode: .live)
        _ = sim.work(.feed, on: coop)
        let report = OfflineCatchUp.run(&sim, lastSeen: Date(timeIntervalSince1970: 0), now: Date(timeIntervalSince1970: 3600))
        let summary = AwaySummary.make(report: report, state: sim.state, balance: sim.balance)
        XCTAssertTrue(summary.lines.contains(.productsReady(itemID: "egg", count: 1)))
        XCTAssertTrue(summary.lines.contains(.hungryAnimals(count: 1)))
    }
}

final class TreeTests: XCTestCase {

    let map = HomeValleyMap.map

    private func farm(balance: Balance = .standard) -> Simulation {
        var state = GameState.newGame(seed: 11, balance: balance)
        state.progress.level = 6
        state.money = 10_000
        return Simulation(state: state, balance: balance)
    }

    /// A wild wood tree on the home farm.
    private func wildTreeOnTheFarm() -> (TileCoord, TreeSpecies) {
        let area = PropertyCatalog.homeFarm.area
        let found = map.treesByFoot.sorted { $0.key.y != $1.key.y ? $0.key.y < $1.key.y : $0.key.x < $1.key.x }
            .first { tile, objects in
                area.contains(tile.center) && TreeCatalog.species(forMapKind: objects[0].kind) != nil
            }!
        return (found.key, TreeCatalog.species(forMapKind: found.value[0].kind)!)
    }

    func testTheFarmHasAWoodlot() {
        let area = PropertyCatalog.homeFarm.area
        let trees = map.treesByFoot.filter { area.contains($0.key.center) && TreeCatalog.species(forMapKind: $0.value[0].kind) != nil }
        XCTAssertGreaterThan(trees.count, 15, "trees to chop behind the pens")
    }

    func testChoppingAWildTreeLeavesAStumpThatSproutsAgain() {
        var sim = farm()
        let (tile, species) = wildTreeOnTheFarm()
        let forestry = Forestry(map: map, balance: sim.balance)
        XCTAssertEqual(forestry.suggestedAction(at: tile, in: sim.state, checkReach: false), .chop)
        XCTAssertTrue(Obstacles(map: map, state: sim.state).isBlocked(tile))

        guard case .chopped(let id, let logs, let xp) = sim.work(.chop, at: tile, on: map).outcome else { return XCTFail() }
        XCTAssertEqual(id, species.id)
        XCTAssertTrue(species.logs.contains(logs))
        XCTAssertEqual(xp, species.chopXP)
        XCTAssertEqual(sim.state.inventory.count("log"), logs)
        XCTAssertTrue(sim.state.woodland.hiddenMapTrees.contains(tile))
        XCTAssertEqual(forestry.tree(at: tile, in: sim.state)?.stage, .stump)
        XCTAssertEqual(forestry.suggestedAction(at: tile, in: sim.state, checkReach: false), .clearStump)

        sim.advance(by: sim.balance.stumpRegrowSeconds + 1, mode: .live)
        XCTAssertEqual(forestry.tree(at: tile, in: sim.state)?.stage, .sapling)
        let events = sim.advance(by: species.growSeconds, mode: .offline)
        XCTAssertEqual(forestry.tree(at: tile, in: sim.state)?.stage, .mature)
        XCTAssertTrue(events.contains(.treeGrown(tile)))
        XCTAssertEqual(forestry.suggestedAction(at: tile, in: sim.state, checkReach: false), .chop)
    }

    func testClearingAStumpFreesTheGround() {
        var sim = farm()
        let (tile, _) = wildTreeOnTheFarm()
        _ = sim.work(.chop, at: tile, on: map)
        XCTAssertEqual(sim.work(.clearStump, at: tile, on: map).outcome, .stumpCleared(xp: sim.balance.stumpRemovalXP))
        XCTAssertNil(Forestry(map: map, balance: sim.balance).tree(at: tile, in: sim.state))
        XCTAssertFalse(Obstacles(map: map, state: sim.state).isBlocked(tile))
        XCTAssertEqual(sim.work(.plow, at: tile, on: map).outcome, .plowed, "cleared land can be farmed")
    }

    func testCannotChopOutsideYourLand() {
        var sim = farm()
        let outside = map.treesByFoot.keys.first { PropertyCatalog.property(containing: $0) == nil }!
        XCTAssertEqual(sim.work(.chop, at: outside, on: map).outcome, .failed(.notYourLand))
        XCTAssertNil(Forestry(map: map, balance: sim.balance).suggestedAction(at: outside, in: sim.state))
    }

    func testPlantingAFruitTreeAndPickingFruit() {
        var sim = farm()
        let apple = TreeCatalog.species("apple")!
        sim.visit(HomeValleyMap.seedShopZone)
        XCTAssertEqual(sim.trade { try $0.buySaplings("apple", count: 1, state: &$1) }, .success(apple.saplingCost))
        sim.goHome()

        let tile = TileCoord(40, 33)
        XCTAssertEqual(sim.work(.plant(speciesID: "apple"), at: tile, on: map).outcome, .failed(.notPlowed))
        XCTAssertEqual(sim.work(.plow, at: tile, on: map).outcome, .plowed)
        XCTAssertEqual(sim.work(.plant(speciesID: "apple"), at: tile, on: map).outcome, .planted(speciesID: "apple"))
        XCTAssertNil(sim.state.plots[tile], "the tree takes the plot's place")
        XCTAssertEqual(sim.state.inventory.count("sapling_apple"), 0)
        XCTAssertTrue(Obstacles(map: map, state: sim.state).isBlocked(tile))

        let forestry = Forestry(map: map, balance: sim.balance)
        XCTAssertNil(forestry.suggestedAction(at: tile, in: sim.state, checkReach: false), "young trees are left alone")
        sim.advance(by: apple.growSeconds + apple.fruitSeconds, mode: .offline)
        XCTAssertTrue(sim.state.woodland[tile]!.hasFruit)
        XCTAssertEqual(forestry.suggestedAction(at: tile, in: sim.state, checkReach: false), .pickFruit)
        guard case .picked("apple", let amount, _) = sim.work(.pickFruit, at: tile, on: map).outcome else { return XCTFail() }
        XCTAssertTrue(apple.fruitYield.contains(amount))
        XCTAssertNil(forestry.suggestedAction(at: tile, in: sim.state, checkReach: false), "a tap never chops a fruit tree")
        XCTAssertEqual(sim.work(.chop, at: tile, on: map).outcome, .chopped(speciesID: "apple", logs: 2, xp: apple.chopXP),
                       "but it can be chopped on purpose")
    }

    func testTreeGrowthIsExactForAnyStepSize() {
        var a = farm()
        let (tile, _) = wildTreeOnTheFarm()
        _ = a.work(.chop, at: tile, on: map)
        a.modify { $0.woodland[TileCoord(40, 33)] = TreeState(tile: TileCoord(40, 33), speciesID: "cherry") }
        var b = a
        a.advance(by: 2 * 3600, mode: .offline)
        for _ in 0..<(2 * 3600 / 13) { b.advance(by: 13, mode: .offline) }
        b.advance(by: Double(2 * 3600 % 13), mode: .offline)
        XCTAssertEqual(a.state.woodland, b.state.woodland)
    }

    func testTappingACanopyFindsTheTree() {
        let sim = farm()
        let (tile, _) = wildTreeOnTheFarm()
        let forestry = Forestry(map: map, balance: sim.balance)
        let foot = forestry.tree(at: tile, in: sim.state)!.position
        XCTAssertEqual(forestry.treeTile(at: Vec2(foot.x, foot.y + 1.2), in: sim.state), tile)
        XCTAssertNil(forestry.treeTile(at: Vec2(26, 32), in: sim.state), "no tree in the yard")
    }
}

final class Phase4WorldTests: XCTestCase {

    let map = HomeValleyMap.map

    func testPensAreOnTheFarmSolidAndClear() {
        for pen in PenCatalog.all {
            XCTAssertEqual(PropertyCatalog.property(containing: TileCoord(containing: pen.area.center))?.id, "home_farm")
            XCTAssertNotNil(pen.species, pen.id)
            XCTAssertTrue(pen.area.contains(pen.trough), "\(pen.id) trough inside")
            for tile in WorldMap.tiles(covering: pen.footprint) {
                XCTAssertTrue(map.isBlocked(tile), "\(pen.id) \(tile) should be solid")
                XCTAssertNil(map.treesByFoot[tile], "\(pen.id) \(tile) has a tree")
            }
            if let shelter = pen.shelterKind { XCTAssertNotNil(AssetManifest.spec(named: shelter), shelter) }
        }
        for (i, a) in PenCatalog.all.enumerated() {
            for b in PenCatalog.all[(i + 1)...] {
                XCTAssertFalse(a.footprint.intersects(b.footprint), "\(a.id) overlaps \(b.id)")
            }
        }
    }

    func testEverySpeciesHasAPenAndKnownItems() {
        for species in AnimalCatalog.all {
            XCTAssertEqual(PenCatalog.pen(species.penID)?.speciesID, species.id)
            XCTAssertNotNil(ItemCatalog.item(species.productItemID), species.productItemID)
            for food in species.feeds { XCTAssertNotNil(ItemCatalog.item(food), food) }
            for pose in ["idle", "walk1", "walk2", "eat", "sleep"] {
                XCTAssertNotNil(AssetManifest.spec(named: "animal_\(species.adultArt)_\(pose)"))
                XCTAssertNotNil(AssetManifest.spec(named: "animal_\(species.youngArt)_\(pose)"))
            }
        }
        for tree in TreeCatalog.all {
            XCTAssertNotNil(ItemCatalog.item(tree.saplingItemID))
            if let fruit = tree.fruitItemID { XCTAssertNotNil(ItemCatalog.item(fruit)) }
            for look in ["sapling", "young", "summer"] { XCTAssertNotNil(AssetManifest.spec(named: "tree_\(tree.id)_\(look)")) }
        }
        for item in ItemCatalog.all { XCTAssertNotNil(AssetManifest.spec(named: item.icon), item.icon) }
    }

    func testSellingAnimalGoodsAndLoadingEverythingSellable() {
        var sim = Simulation(state: .newGame(seed: 3))
        sim.modify {
            $0.inventory.add("egg", 3)
            $0.inventory.add("log", 4)
            $0.inventory.add("animal_feed", 5)
        }
        XCTAssertEqual(sim.trade { try $0.loadAll(state: &$1) }, .success(7))
        XCTAssertEqual(sim.state.truck.cargo.items, ["egg": 3, "log": 4])
        XCTAssertEqual(sim.state.inventory.count("animal_feed"), 5, "feed isn't for sale")

        sim.visit(HomeValleyMap.marketZone)
        let trading = Trading(balance: sim.balance)
        let expected = 3 * trading.price(of: "egg", in: sim.state)! + 4 * trading.price(of: "log", in: sim.state)!
        XCTAssertEqual(sim.trade { try $0.sellAll(state: &$1) }, .success(expected))
        XCTAssertNil(trading.price(of: "animal_feed", in: sim.state))
        XCTAssertNil(trading.price(of: "seeds_wheat", in: sim.state))
    }

    func testBuyingFeed() {
        var sim = Simulation(state: .newGame(seed: 3))
        sim.visit(HomeValleyMap.livestockZone)
        XCTAssertEqual(sim.trade { try $0.buyFeed(count: 10, state: &$1) }, .success(10 * sim.balance.feedPrice))
        XCTAssertEqual(sim.state.inventory.count("animal_feed"), 10)
    }

    func testCropPricesDidNotChange() {
        // Prices of crops must stay what Phase 3 players saw for the same day.
        let wheat = CropCatalog.crop("wheat")!
        for day in 0..<20 {
            XCTAssertEqual(MarketPricing.price(of: ItemCatalog.item("wheat")!, day: day), MarketPricing.price(of: wheat, day: day))
        }
    }
}
