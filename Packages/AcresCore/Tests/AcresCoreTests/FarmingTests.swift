import XCTest
@testable import AcresCore

final class FarmingTests: XCTestCase {

    let map = HomeValleyMap.map

    private func newSim(balance: Balance = .standard) -> Simulation {
        Simulation(state: .newGame(seed: 99, balance: balance), balance: balance)
    }

    /// The first `count` plowable tiles on the home farm (row by row).
    private func plowableTiles(_ count: Int, in sim: Simulation) -> [TileCoord] {
        let farming = Farming(map: map, balance: sim.balance)
        var result: [TileCoord] = []
        let area = PropertyCatalog.homeFarm.area
        for y in Int(area.minY)..<Int(area.maxY) {
            for x in Int(area.minX)..<Int(area.maxX) {
                let tile = TileCoord(x, y)
                if farming.plowProblem(at: tile, in: sim.state, checkReach: false) == nil { result.append(tile) }
                if result.count == count { return result }
            }
        }
        return result
    }

    private func plowAndPlant(_ crop: String, at tile: TileCoord, in sim: inout Simulation) {
        XCTAssertEqual(sim.work(.plow, at: tile, on: map).outcome, .plowed)
        XCTAssertEqual(sim.work(.plant(cropID: crop), at: tile, on: map).outcome, .planted(cropID: crop))
    }

    // MARK: Land rules

    func testTheHomeFarmHasPlentyOfFarmland() {
        XCTAssertGreaterThan(plowableTiles(1000, in: newSim()).count, 200)
    }

    func testCannotFarmOutsideYourLand() {
        var sim = newSim()
        XCTAssertEqual(sim.work(.plow, at: TileCoord(5, 5), on: map).outcome, .failed(.notYourLand))
        XCTAssertEqual(sim.work(.plow, at: TileCoord(49, 34), on: map).outcome, .failed(.notYourLand), "the plot for sale")
    }

    func testCannotPlowUnderBuildingsOrTheTruck() {
        var sim = newSim()
        XCTAssertEqual(sim.work(.plow, at: TileCoord(21, 37), on: map).outcome, .failed(.cannotPlowHere), "farmhouse")
        XCTAssertEqual(sim.work(.plow, at: TileCoord(30, 38), on: map).outcome, .failed(.cannotPlowHere), "barn")
        let truckTile = TileCoord(containing: sim.state.truck.position)
        XCTAssertEqual(sim.work(.plow, at: truckTile, on: map).outcome, .failed(.cannotPlowHere), "truck")
    }

    func testYouFarmWhereYourFarmerStands() {
        var sim = newSim()
        let tile = plowableTiles(1, in: sim)[0]
        sim.stand(at: Vec2(tile.center.x + 3, tile.center.y))
        XCTAssertEqual(sim.perform(.plow, at: tile, on: map).outcome, .failed(.tooFar))
        sim.stand(at: tile.center)
        sim.modify { $0.farmer.inTruck = true }
        XCTAssertEqual(sim.perform(.plow, at: tile, on: map).outcome, .failed(.tooFar), "get out of the truck first")
        sim.stand(at: Vec2(tile.center.x + 1, tile.center.y))
        XCTAssertEqual(sim.perform(.plow, at: tile, on: map).outcome, .plowed, "a neighbouring tile is within reach")
    }

    func testWorkUsesEnergyAndTiredFarmersRest() {
        var sim = newSim()
        let tile = plowableTiles(1, in: sim)[0]
        sim.stand(at: tile.center)
        sim.modify { $0.farmer.energy = 1 }
        XCTAssertEqual(sim.perform(.plow, at: tile, on: map).outcome, .failed(.tooTired))
        sim.modify { $0.farmer.energy = 10 }
        XCTAssertEqual(sim.perform(.plow, at: tile, on: map).outcome, .plowed)
        XCTAssertEqual(sim.state.farmer.energy, 10 - sim.balance.energyCost.plow, accuracy: 1e-9)
        XCTAssertEqual(sim.state.goals.count(GoalCounter.plowed), 1)
    }

    func testPlowingTwiceFails() {
        var sim = newSim()
        let tile = plowableTiles(1, in: sim)[0]
        XCTAssertEqual(sim.work(.plow, at: tile, on: map).outcome, .plowed)
        XCTAssertEqual(sim.work(.plow, at: tile, on: map).outcome, .failed(.alreadyPlowed))
    }

    // MARK: Planting

    func testPlantingUsesASeed() {
        var sim = newSim()
        let tile = plowableTiles(1, in: sim)[0]
        let before = sim.state.inventory.count("seeds_wheat")
        plowAndPlant("wheat", at: tile, in: &sim)
        XCTAssertEqual(sim.state.inventory.count("seeds_wheat"), before - 1)
        XCTAssertEqual(sim.state.plots[tile]?.crop?.cropID, "wheat")
        XCTAssertEqual(sim.work(.plant(cropID: "wheat"), at: tile, on: map).outcome, .failed(.alreadyPlanted))
    }

    func testPlantingRules() {
        var sim = newSim()
        let tiles = plowableTiles(3, in: sim)
        for tile in tiles { _ = sim.work(.plow, at: tile, on: map) }
        XCTAssertEqual(sim.work(.plant(cropID: "corn"), at: tiles[0], on: map).outcome,
                       .failed(.outOfSeason(cropID: "corn", season: .spring)))
        XCTAssertEqual(sim.work(.plant(cropID: "strawberry"), at: tiles[1], on: map).outcome,
                       .failed(.noSeeds(cropID: "strawberry")))
        XCTAssertEqual(sim.work(.plant(cropID: "wheat"), at: plowableTiles(1, in: sim)[0], on: map).outcome,
                       .failed(.notPlowed))
        XCTAssertEqual(sim.work(.plant(cropID: "nope"), at: tiles[2], on: map).outcome, .failed(.unknownCrop))
    }

    // MARK: Growth

    func testWateredWheatRipensInADayDryInTwo() {
        var sim = newSim()
        let day = GameTime.day
        XCTAssertEqual(CropCatalog.crop("wheat")!.growthSeconds, day)
        let tiles = plowableTiles(2, in: sim)
        plowAndPlant("wheat", at: tiles[0], in: &sim)
        plowAndPlant("wheat", at: tiles[1], in: &sim)
        XCTAssertEqual(sim.work(.water, at: tiles[0], on: map).outcome, .watered)

        let events = sim.advance(by: day + 1, mode: .live)
        XCTAssertTrue(sim.state.plots[tiles[0]]!.crop!.isReady)
        XCTAssertFalse(sim.state.plots[tiles[1]]!.crop!.isReady)
        XCTAssertTrue(events.contains(.cropReady(tiles[0], cropID: "wheat")))

        sim.advance(by: day, mode: .live)
        XCTAssertTrue(sim.state.plots[tiles[1]]!.crop!.isReady)
    }

    func testSoilDriesOutAndGrowthSlowsDown() {
        var balance = Balance.standard
        balance.soilWetDuration = 60
        var sim = newSim(balance: balance)
        let tile = plowableTiles(1, in: sim)[0]
        plowAndPlant("potato", at: tile, in: &sim)  // G seconds when watered
        _ = sim.work(.water, at: tile, on: map)
        let g = CropCatalog.crop("potato")!.growthSeconds

        // 60 s wet (60 growth) + the rest at half speed.
        let expected = 60 + (g - 60) * 2
        XCTAssertEqual(FarmForecast.secondsUntilReady(sim.state.plots[tile]!, now: sim.state.worldTime, balance: balance)!,
                       expected, accuracy: 1e-6)
        sim.advance(by: expected - 10, mode: .live)
        XCTAssertFalse(sim.state.plots[tile]!.crop!.isReady)
        sim.advance(by: 11, mode: .live)
        XCTAssertTrue(sim.state.plots[tile]!.crop!.isReady)
        XCTAssertEqual(sim.state.plots[tile]!.crop!.wateredGrowth, 60, accuracy: 1e-6)
    }

    func testStagesAdvanceAsCropsGrow() {
        var sim = newSim()
        let tile = plowableTiles(1, in: sim)[0]
        plowAndPlant("potato", at: tile, in: &sim)
        _ = sim.work(.water, at: tile, on: map)
        var stages: [Int] = []
        let eta = FarmForecast.secondsUntilReady(sim.state.plots[tile]!, now: sim.state.worldTime, balance: sim.balance)!
        let step = (eta + 1) / 12
        for _ in 0..<13 {
            stages.append(sim.state.plots[tile]!.crop!.stage)
            sim.advance(by: step, mode: .live)
        }
        XCTAssertEqual(stages.first, 0)
        XCTAssertEqual(stages.last, 4)
        XCTAssertEqual(stages, stages.sorted(), "stages never go backwards")
        XCTAssertEqual(Set(stages), [0, 1, 2, 3, 4])
    }

    func testGrowthIsIdenticalForAnyStepSize() {
        var balance = Balance.standard
        balance.soilWetDuration = 97  // ends mid-step on purpose
        var a = newSim(balance: balance)
        let tiles = plowableTiles(4, in: a)
        for (i, tile) in tiles.enumerated() {
            plowAndPlant(["wheat", "carrot", "potato", "wheat"][i], at: tile, in: &a)
            if i % 2 == 0 { _ = a.work(.water, at: tile, on: map) }
        }
        var b = a
        a.advance(by: 700, mode: .offline)
        for _ in 0..<(700 * 4) { b.advance(by: 0.25, mode: .offline) }
        for tile in tiles {
            XCTAssertEqual(a.state.plots[tile]!.crop!.growth, b.state.plots[tile]!.crop!.growth, accuracy: 1e-6)
        }
    }

    func testCropsGrowOfflineAndNeverRot() {
        var sim = newSim()
        let tile = plowableTiles(1, in: sim)[0]
        plowAndPlant("wheat", at: tile, in: &sim)
        let seen = Date(timeIntervalSince1970: 1_900_000_000)
        let report = OfflineCatchUp.run(&sim, lastSeen: seen, now: seen + 3 * 24 * 3600)
        let crop = sim.state.plots[tile]!.crop!
        XCTAssertTrue(crop.isReady)
        XCTAssertEqual(crop.growth, CropCatalog.crop("wheat")!.growthSeconds, "growth is capped at ripe")
        XCTAssertEqual(report.events.filter { if case .cropReady = $0 { true } else { false } }.count, 1)
    }

    // MARK: Watering

    func testWateringRules() {
        var sim = newSim()
        let tile = plowableTiles(1, in: sim)[0]
        _ = sim.work(.plow, at: tile, on: map)
        XCTAssertEqual(sim.work(.water, at: tile, on: map).outcome, .failed(.nothingToWater))
        _ = sim.work(.plant(cropID: "wheat"), at: tile, on: map)
        XCTAssertEqual(sim.work(.water, at: tile, on: map).outcome, .watered)
        XCTAssertEqual(sim.work(.water, at: tile, on: map).outcome, .failed(.alreadyWet))
    }

    // MARK: Harvest

    func testHarvestFillsStorageGivesXPAndLeavesSoil() {
        var sim = newSim()
        let tile = plowableTiles(1, in: sim)[0]
        plowAndPlant("wheat", at: tile, in: &sim)
        XCTAssertEqual(sim.work(.harvest, at: tile, on: map).outcome, .failed(.notReady))
        sim.advance(by: 2 * GameTime.day, mode: .live)

        let result = sim.work(.harvest, at: tile, on: map)
        guard case .harvested("wheat", let amount, 2) = result.outcome else {
            return XCTFail("unexpected \(result.outcome)")
        }
        XCTAssertTrue(CropCatalog.crop("wheat")!.yield.contains(amount))
        XCTAssertEqual(sim.state.inventory.count("wheat"), amount)
        XCTAssertEqual(sim.state.progress.xp, 2)
        XCTAssertNotNil(sim.state.plots[tile], "soil stays plowed")
        XCTAssertNil(sim.state.plots[tile]?.crop)
    }

    func testStrawberriesRegrowAfterHarvest() {
        var sim = newSim()
        sim.modify { $0.inventory.add("seeds_strawberry", 1) }
        let tile = plowableTiles(1, in: sim)[0]
        plowAndPlant("strawberry", at: tile, in: &sim)
        _ = sim.work(.water, at: tile, on: map)
        // Watered once: wet for a day, then half speed.
        let strawberry = CropCatalog.crop("strawberry")!
        sim.advance(by: GameTime.day + (strawberry.growthSeconds - GameTime.day) * 2 + 1, mode: .live)
        XCTAssertTrue(sim.work(.harvest, at: tile, on: map).outcome.succeeded)

        let crop = sim.state.plots[tile]!.crop!
        XCTAssertEqual(crop.cropID, "strawberry")
        XCTAssertEqual(crop.harvests, 1)
        XCTAssertFalse(crop.isReady)
        // The soil is still wet from the first watering for part of the regrow time.
        let eta = FarmForecast.secondsUntilReady(sim.state.plots[tile]!, now: sim.state.worldTime, balance: sim.balance)!
        XCTAssertGreaterThanOrEqual(eta, strawberry.regrowSeconds!)
        sim.advance(by: eta + 1, mode: .live)
        XCTAssertTrue(sim.state.plots[tile]!.crop!.isReady)
    }

    func testFullStorageStopsHarvestWithoutConsumingLuck() {
        var balance = Balance.standard
        balance.storageCapacity = 4
        var sim = newSim(balance: balance)
        sim.modify { $0.inventory.add("wheat", 3) }
        let tile = plowableTiles(1, in: sim)[0]
        plowAndPlant("wheat", at: tile, in: &sim)
        sim.advance(by: 2 * GameTime.day, mode: .live)

        let rngBefore = sim.state.rng
        XCTAssertEqual(sim.work(.harvest, at: tile, on: map).outcome, .failed(.storageFull))
        XCTAssertEqual(sim.state.rng, rngBefore)
        XCTAssertTrue(sim.state.plots[tile]!.crop!.isReady, "the crop waits in the field")
    }

    func testSeedsDoNotUseStorage() {
        let inventory = Inventory(items: ["seeds_wheat": 50, "wheat": 3, "carrot": 2])
        XCTAssertEqual(inventory.storageUsed, 5)
    }

    // MARK: Contextual tapping

    func testSuggestedActionFollowsTheTileState() {
        var sim = newSim()
        let farming = Farming(map: map, balance: sim.balance)
        let tile = plowableTiles(1, in: sim)[0]

        // Planning a job ignores reach: the farmer walks over first.
        XCTAssertEqual(farming.suggestedAction(at: tile, in: sim.state, seed: "wheat", checkReach: false), .plow)
        XCTAssertNil(farming.suggestedAction(at: tile, in: sim.state, seed: "wheat"), "not within reach yet")
        _ = sim.work(.plow, at: tile, on: map)
        XCTAssertEqual(farming.suggestedAction(at: tile, in: sim.state, seed: "wheat"), .plant(cropID: "wheat"))
        XCTAssertNil(farming.suggestedAction(at: tile, in: sim.state, seed: nil), "no seed chosen: the UI asks")
        _ = sim.work(.plant(cropID: "wheat"), at: tile, on: map)
        XCTAssertEqual(farming.suggestedAction(at: tile, in: sim.state, seed: "wheat"), .water)
        _ = sim.work(.water, at: tile, on: map)
        XCTAssertNil(farming.suggestedAction(at: tile, in: sim.state, seed: "wheat"), "growing happily")
        sim.advance(by: GameTime.day + 1, mode: .live)
        XCTAssertEqual(farming.suggestedAction(at: tile, in: sim.state, seed: "wheat"), .harvest)
        XCTAssertNil(farming.suggestedAction(at: TileCoord(3, 3), in: sim.state, seed: "wheat", checkReach: false))
    }

    func testEachToolOnlyDoesItsOwnJob() {
        var sim = newSim()
        let farming = Farming(map: map, balance: sim.balance)
        let tile = plowableTiles(1, in: sim)[0]
        func tool(_ kind: FarmAction.Kind, seed: String? = "wheat") -> Result<FarmAction, FarmFailure> {
            farming.toolAction(kind, at: tile, in: sim.state, seed: seed, checkReach: false)
        }

        // Grass: only the hoe works; the seeds never plow.
        XCTAssertEqual(tool(.plow), .success(.plow))
        XCTAssertEqual(tool(.plant), .failure(.notPlowed))
        XCTAssertEqual(tool(.water), .failure(.notPlowed))
        XCTAssertEqual(tool(.harvest), .failure(.notReady))

        // Plowed soil: the hoe does nothing more; seeds plant the packet in hand.
        _ = sim.work(.plow, at: tile, on: map)
        XCTAssertEqual(tool(.plow), .failure(.alreadyPlowed))
        XCTAssertEqual(tool(.plant), .success(.plant(cropID: "wheat")))
        XCTAssertEqual(tool(.plant, seed: nil), .failure(.unknownCrop))
        XCTAssertEqual(tool(.plant, seed: "pumpkin"), .failure(.outOfSeason(cropID: "pumpkin", season: .spring)))
        XCTAssertEqual(tool(.water), .failure(.nothingToWater))

        // A seedling: water it once.
        _ = sim.work(.plant(cropID: "wheat"), at: tile, on: map)
        XCTAssertEqual(tool(.plant), .failure(.alreadyPlanted))
        XCTAssertEqual(tool(.water), .success(.water))
        _ = sim.work(.water, at: tile, on: map)
        XCTAssertEqual(tool(.water), .failure(.alreadyWet))
        XCTAssertEqual(tool(.harvest), .failure(.notReady))

        sim.advance(by: GameTime.day + 1, mode: .live)
        XCTAssertEqual(tool(.harvest), .success(.harvest))
        XCTAssertEqual(tool(.water), .failure(.nothingToWater))

        XCTAssertEqual(farming.toolAction(.plow, at: TileCoord(3, 3), in: sim.state, seed: nil, checkReach: false),
                       .failure(.notYourLand))
        sim.modify { $0.inventory.remove("seeds_carrot", $0.inventory.count("seeds_carrot")) }
        let empty = TileCoord(tile.x + 1, tile.y)
        _ = sim.work(.plow, at: empty, on: map)
        XCTAssertEqual(farming.toolAction(.plant, at: empty, in: sim.state, seed: "carrot", checkReach: false),
                       .failure(.noSeeds(cropID: "carrot")))
    }

    func testEverySeasonHasCropsToPlant() {
        for season in Season.allCases {
            let crops = CropCatalog.all.filter { $0.canBePlanted(in: season) }
            XCTAssertGreaterThanOrEqual(crops.count, 3, "\(season.name) needs crops")
            XCTAssertTrue(crops.contains { $0.unlockLevel <= 3 }, "\(season.name) has an early crop")
        }
        XCTAssertEqual(Set(CropCatalog.all.map(\.id)).count, CropCatalog.all.count)
        for crop in CropCatalog.all {
            XCTAssertEqual(crop.stageNotes.count, CropDefinition.stageCount, crop.id)
            XCTAssertLessThan(crop.seedCost, crop.sellPrice.lowerBound * crop.yield.lowerBound, "\(crop.id) pays back its seed")
        }
    }

    func testPlantableSeedsFollowSeasonAndPouch() {
        let sim = newSim()
        let farming = Farming(map: map, balance: sim.balance)
        XCTAssertEqual(farming.plantableSeeds(in: sim.state).map(\.id), ["wheat", "carrot", "potato"])
    }

    // MARK: Progression

    func testLevelUps() {
        var state = GameState.newGame(seed: 1)
        let balance = Balance.standard
        XCTAssertEqual(balance.xpToNextLevel(from: 1), 20)
        let events = Progression.addXP(20 + balance.xpToNextLevel(from: 2) + 3, to: &state, balance: balance)
        XCTAssertEqual(events, [.levelUp(2), .levelUp(3)])
        XCTAssertEqual(state.progress.level, 3)
        XCTAssertEqual(state.progress.xp, 3)
        XCTAssertGreaterThan(balance.xpToNextLevel(from: 10), balance.xpToNextLevel(from: 5))
    }

    // MARK: Summary and forecast

    func testAwaySummaryListsReadyGrowingAndThirstyCrops() {
        var sim = newSim()
        let tiles = plowableTiles(3, in: sim)
        plowAndPlant("wheat", at: tiles[0], in: &sim)
        plowAndPlant("wheat", at: tiles[1], in: &sim)
        plowAndPlant("potato", at: tiles[2], in: &sim)
        let seen = Date(timeIntervalSince1970: 1_900_000_000)
        // Dry soil: wheat needs 2 days, potatoes 4.
        let report = OfflineCatchUp.run(&sim, lastSeen: seen, now: seen + 3 * GameTime.day)
        let summary = AwaySummary.make(report: report, state: sim.state, balance: sim.balance)
        XCTAssertTrue(summary.lines.contains(.cropsReady(cropID: "wheat", count: 2)))
        XCTAssertTrue(summary.lines.contains { if case .cropsGrowing("potato", 1, _) = $0 { true } else { false } })
        XCTAssertTrue(summary.lines.contains(.thirstyCrops(count: 1)))
    }

    func testForecastAgreesWithTheSimulation() {
        var sim = newSim()
        let tiles = plowableTiles(3, in: sim)
        plowAndPlant("wheat", at: tiles[0], in: &sim)
        plowAndPlant("carrot", at: tiles[1], in: &sim)
        plowAndPlant("potato", at: tiles[2], in: &sim)
        _ = sim.work(.water, at: tiles[1], on: map)
        let eta = FarmForecast.secondsUntilAllReady(sim.state, balance: sim.balance)!
        sim.advance(by: eta - 1, mode: .offline)
        XCTAssertFalse(tiles.allSatisfy { sim.state.plots[$0]!.crop!.isReady })
        sim.advance(by: 2, mode: .offline)
        XCTAssertTrue(tiles.allSatisfy { sim.state.plots[$0]!.crop!.isReady })
        XCTAssertNil(FarmForecast.secondsUntilAllReady(sim.state, balance: sim.balance))
    }

    func testFarmingIsDeterministic() {
        func play() -> GameState {
            var sim = newSim()
            let tiles = plowableTiles(6, in: sim)
            for tile in tiles { plowAndPlant("wheat", at: tile, in: &sim) }
            sim.advance(by: 500, mode: .live)
            for tile in tiles { _ = sim.work(.harvest, at: tile, on: map) }
            return sim.state
        }
        XCTAssertEqual(play(), play())
    }

    func testThreeDayCatchUpWithAFullFarmIsFast() {
        var sim = newSim()
        let tiles = plowableTiles(1000, in: sim)
        // Slow crops so every plot keeps growing for the whole catch-up.
        sim.modify { state in
            for tile in tiles {
                state.plots[tile] = Plot(tile: tile, crop: PlantedCrop(cropID: "pumpkin", plantedAt: 0))
            }
        }
        var balance = sim.balance
        balance.dryGrowthRate = 0.0001
        sim = Simulation(state: sim.state, balance: balance)
        let seen = Date(timeIntervalSince1970: 1_900_000_000)
        let start = Date()
        _ = OfflineCatchUp.run(&sim, lastSeen: seen, now: seen + 3 * 24 * 3600)
        let elapsed = Date().timeIntervalSince(start)
        print("3-day catch-up with \(tiles.count) growing plots: \(Int(elapsed * 1000)) ms")
        XCTAssertLessThan(elapsed, 1)
    }

    func testV1SavesGetStartingSeedsAndTheHomeFarm() throws {
        let file = try SaveSystem(store: MemorySaveStore(), deviceID: "t").decode(Data(SaveFixtures.v1.utf8)).get()
        XCTAssertEqual(file.state.inventory.count("seeds_wheat"), 12)
        XCTAssertEqual(file.state.ownedProperties, ["home_farm"])
        XCTAssertTrue(file.state.plots.isEmpty)
    }
}
