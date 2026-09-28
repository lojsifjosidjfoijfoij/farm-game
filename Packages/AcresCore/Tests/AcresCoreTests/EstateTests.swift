import XCTest
@testable import AcresCore

final class EstateTests: XCTestCase {

    let map = HomeValleyMap.map
    let balance = Balance.standard
    var rules: EstateRules { EstateRules(map: map, balance: balance) }
    var farming: Farming { Farming(map: map, balance: balance) }

    /// A rich, experienced farmer on Tuesday (day 1) at 07:00.
    private func sim(level: Int = 8, money: Int = 50_000) -> Simulation {
        var state = GameState.newGame(seed: 41)
        state.clock = GameClock(dayIndex: 1, hour: 7)
        state.finance.lastProcessedDay = 1
        state.contracts.nextID = 50
        state.progress.level = level
        state.money = money
        state.tutorial = .complete
        state.ownedFields = FieldCatalog.all.filter { $0.propertyID == PropertyCatalog.homeFarm.id }.map(\.id)
        return Simulation(state: state)
    }

    private func play(_ sim: inout Simulation, hours: Double) {
        sim.advance(by: hours * 60 / balance.gameMinutesPerRealSecond, mode: .live)
    }

    /// Plowable tiles on the home farm, row by row.
    private func fieldTiles(_ count: Int, in sim: Simulation) -> [TileCoord] {
        var result: [TileCoord] = []
        let area = PropertyCatalog.homeFarm.area
        for y in Int(area.minY)..<Int(area.maxY) {
            for x in Int(area.minX)..<Int(area.maxX) where farming.plowProblem(at: TileCoord(x, y), in: sim.state, checkReach: false) == nil {
                result.append(TileCoord(x, y))
                if result.count == count { return result }
            }
        }
        return result
    }

    /// Plows and plants (with the farmer walking over), leaving the soil dry.
    private func plant(_ crop: String, at tiles: [TileCoord], in sim: inout Simulation) {
        sim.modify { $0.inventory.add(CropCatalog.crop(crop)!.seedItemID, tiles.count) }
        for tile in tiles {
            XCTAssertEqual(sim.work(.plow, at: tile, on: map).outcome, .plowed)
            XCTAssertEqual(sim.work(.plant(cropID: crop), at: tile, on: map).outcome, .planted(cropID: crop))
        }
    }

    // MARK: Land

    func testParcelsDontOverlapAndCanBeFarmed() {
        let all = PropertyCatalog.all
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        for (index, property) in all.enumerated() {
            for other in all[(index + 1)...] {
                XCTAssertFalse(property.area.intersects(other.area), "\(property.name) overlaps \(other.name)")
            }
        }
        var state = GameState.newGame(seed: 1)
        state.ownedProperties = all.map(\.id)
        for property in PropertyCatalog.forSale {
            XCTAssertNotNil(property.price)
            if let sign = property.signSpot { XCTAssertTrue(property.area.contains(sign), "\(property.name) sign") }
            var farmable = 0
            for y in Int(property.area.minY)..<Int(property.area.maxY.rounded(.up)) {
                for x in Int(property.area.minX)..<Int(property.area.maxX.rounded(.up)) {
                    let tile = TileCoord(x, y)
                    guard property.contains(tile) else { continue }
                    XCTAssertNotEqual(map.terrain(at: tile), .asphalt, "\(property.name) takes in a road at \(tile)")
                    if farming.groundProblem(at: tile, in: state, checkReach: false) == nil { farmable += 1 }
                }
            }
            XCTAssertGreaterThan(farmable, 60, "\(property.name) has room for fields and buildings")
        }
        for building in EstateLayout.buildings {
            XCTAssertNil(PropertyCatalog.property(containing: TileCoord(containing: building.position)),
                         "the farm's buildings stand off the fields")
        }
    }

    func testBuyingLand() {
        var sim = sim(level: 1)
        XCTAssertEqual(sim.estate(on: map) { try $0.buyLand("east_meadow", state: &$1) }, .failure(.locked(level: 2)))
        sim.modify { $0.progress.level = 2; $0.money = 1_000 }
        XCTAssertEqual(sim.estate(on: map) { try $0.buyLand("east_meadow", state: &$1) }, .failure(.notEnoughMoney))
        sim.modify { $0.money = 3_000 }
        XCTAssertEqual(sim.estate(on: map) { try $0.buyLand("east_meadow", state: &$1) }, .success(2_500))
        XCTAssertEqual(sim.state.ownedProperties, ["east_meadow", "home_farm"])
        XCTAssertEqual(sim.state.money, 500)
        XCTAssertEqual(sim.state.finance.thisWeek.expenses[LedgerCategory.land], 2_500)
        XCTAssertEqual(sim.estate(on: map) { try $0.buyLand("east_meadow", state: &$1) }, .failure(.alreadyOwned))
        XCTAssertEqual(sim.estate(on: map) { try $0.buyLand("home_farm", state: &$1) }, .failure(.unknown))
        XCTAssertEqual(Bank.weeklyBills(sim.state, balance: balance).first { $0.category == LedgerCategory.propertyTax }?.amount,
                       2 * balance.propertyTaxPerWeek, "taxed like the farm")

        // The new land's fields go on sale; once one is bought, it can be farmed.
        let meadow = PropertyCatalog.property("east_meadow")!
        let field = FieldCatalog.field("meadow_1")!
        let tile = TileCoord(50, 35)
        XCTAssertTrue(meadow.contains(tile) && field.contains(tile))
        XCTAssertEqual(sim.work(.plow, at: tile, on: map).outcome, .failed(.notAField))
        XCTAssertEqual(sim.estate(on: map) { try $0.buyField("meadow_1", state: &$1) }, .failure(.locked(level: field.unlockLevel)))
        sim.modify { $0.progress.level = field.unlockLevel; $0.money = field.price }
        XCTAssertEqual(sim.estate(on: map) { try $0.buyField("meadow_1", state: &$1) }, .success(field.price))
        XCTAssertEqual(sim.state.money, 0)
        XCTAssertTrue(sim.state.ownedFields.contains("meadow_1"))
        XCTAssertEqual(sim.estate(on: map) { try $0.buyField("meadow_1", state: &$1) }, .failure(.alreadyOwned))
        XCTAssertEqual(sim.work(.plow, at: tile, on: map).outcome, .plowed)
        XCTAssertEqual(sim.estate(on: map) { try $0.buyField("west_1", state: &$1) }, .failure(.notYourLand), "not their land yet")
    }

    func testFieldsLieOnTheirLandOnClearGround() {
        var state = GameState.newGame(seed: 1)
        state.ownedProperties = PropertyCatalog.all.map(\.id)
        state.ownAllFields()
        let fields = FieldCatalog.all
        XCTAssertEqual(Set(fields.map(\.id)).count, fields.count)
        XCTAssertNotNil(FieldCatalog.field(FieldCatalog.starterID))
        for (index, field) in fields.enumerated() {
            let property = PropertyCatalog.property(field.propertyID)
            XCTAssertNotNil(property, field.id)
            XCTAssertEqual(field.area.minX.rounded(), field.area.minX, "\(field.id) has whole-tile edges")
            for other in fields[(index + 1)...] {
                XCTAssertFalse(field.area.intersects(other.area) && field.tiles.contains(where: other.contains),
                               "\(field.id) overlaps \(other.id)")
            }
            var plowable = 0
            for tile in field.tiles {
                XCTAssertTrue(property?.contains(tile) ?? false, "\(field.id) \(tile) is on \(field.propertyID)")
                if farming.plowProblem(at: tile, in: state, checkReach: false) == nil { plowable += 1 }
            }
            XCTAssertGreaterThanOrEqual(Double(plowable), Double(field.tileCount) * 0.8, "\(field.id) is mostly clear ground")
        }
        // Old saves: the fields a farm's level and land have earned.
        XCTAssertEqual(FieldCatalog.earned(level: 1, properties: ["home_farm"]), [FieldCatalog.starterID])
        XCTAssertEqual(Set(FieldCatalog.earned(level: 3, properties: ["home_farm", "east_meadow"])),
                       ["home_1", "home_2", "home_3", "meadow_1"])
    }

    func testTreesOnBoughtLandCanBeChopped() {
        var sim = sim()
        let woods = PropertyCatalog.property("north_woods")!
        let forestry = Forestry(map: map, balance: balance)
        guard let tree = map.objects.first(where: { $0.kind.hasPrefix("tree_") && woods.area.contains($0.position) }),
              let tile = forestry.treeTile(at: tree.position, in: sim.state) else { return XCTFail("a tree in the woods") }
        XCTAssertEqual(forestry.accessProblem(at: tile, in: sim.state, checkReach: false), .notYourLand)
        _ = sim.estate(on: map) { try $0.buyLand("north_woods", state: &$1) }
        XCTAssertNil(forestry.accessProblem(at: tile, in: sim.state, checkReach: false))
    }

    // MARK: Upgrades

    func testStorageUpgradesRaiseCapacityAndPutUpBuildings() {
        var sim = sim(level: 3)
        XCTAssertEqual(sim.state.storageCapacity(balance), 300)
        XCTAssertTrue(EstateLayout.blockedTiles(sim.state.estate).isEmpty)
        XCTAssertEqual(sim.estate(on: map) { try $0.upgradeStorage(state: &$1) }, .success(1_500))
        XCTAssertEqual(sim.state.storageCapacity(balance), 450)
        XCTAssertEqual(EstateLayout.standing(sim.state.estate).map(\.kind), ["building_storage_shed"])
        let shed = EstateLayout.blockedTiles(sim.state.estate)
        XCTAssertFalse(shed.isEmpty)
        XCTAssertTrue(shed.allSatisfy { Obstacles(map: map, state: sim.state).isBlocked($0) })
        XCTAssertEqual(sim.estate(on: map) { try $0.upgradeStorage(state: &$1) }, .failure(.locked(level: 4)))
        sim.modify { $0.progress.level = 8 }
        _ = sim.estate(on: map) { try $0.upgradeStorage(state: &$1) }
        _ = sim.estate(on: map) { try $0.upgradeStorage(state: &$1) }
        XCTAssertEqual(sim.state.storageCapacity(balance), 900)
        XCTAssertEqual(EstateLayout.standing(sim.state.estate).count, 3)
        XCTAssertEqual(sim.estate(on: map) { try $0.upgradeStorage(state: &$1) }, .failure(.maxLevel))
        XCTAssertEqual(sim.state.finance.thisWeek.expenses[LedgerCategory.buildings], 1_500 + 4_000 + 9_000)

        // The truck still gets from the farm to the village.
        let built = EstateLayout.blockedTiles(sim.state.estate)
        XCTAssertNotNil(Pathfinder.path(on: map, built: built, from: HomeValleyMap.truckParkingSpot,
                                        to: HomeValleyMap.marketZone.center))
        XCTAssertFalse(TruckPhysics(map: map, tuning: balance.driving, built: built).collides(HomeValleyMap.truckParkingSpot))
    }

    func testABiggerTruckBedCarriesMore() {
        var sim = sim()
        sim.goHome()
        _ = sim.estate(on: map) { try $0.upgradeTruckBed(state: &$1) }
        XCTAssertEqual(sim.state.truckCapacity(balance), 90)
        sim.modify { $0.inventory.add("wheat", 200) }
        XCTAssertEqual(sim.trade { try $0.loadAll(state: &$1) }, .success(90))
    }

    // MARK: Sprinklers

    func testSprinklersArePlacedOnYourGrassAndKeepCropsWet() {
        var sim = sim(level: 2)
        XCTAssertEqual(sim.estate(on: map) { try $0.buyMachine("sprinkler", state: &$1) }, .failure(.locked(level: 3)))
        sim.modify { $0.progress.level = 8 }
        XCTAssertEqual(sim.estate(on: map) { try $0.buyMachine("sprinkler", state: &$1) }, .success(450))
        XCTAssertEqual(sim.state.inventory.count("sprinkler"), 1)
        XCTAssertEqual(sim.state.inventory.storageUsed, 0, "machines don't take storage")

        let tiles = fieldTiles(3, in: sim)
        let spot = tiles[1]
        let neighbor = tiles[2]
        plant("wheat", at: [neighbor], in: &sim)
        sim.stand(at: spot.center)
        XCTAssertEqual(sim.estate(on: map) { try $0.placeSprinkler("sprinkler", at: neighbor, state: &$1) }.map { _ in 0 }, .failure(.cannotPlaceHere),
                       "not on a field")
        XCTAssertEqual(sim.estate(on: map) { try $0.placeSprinkler("sprinkler", at: TileCoord(5, 5), state: &$1) }.map { _ in 0 }, .failure(.notYourLand))
        XCTAssertEqual(sim.estate(on: map) { try $0.placeSprinkler("sprinkler", at: spot, state: &$1) }.map { _ in 0 }, .success(0))
        XCTAssertEqual(sim.state.inventory.count("sprinkler"), 0)
        XCTAssertEqual(sim.estate(on: map) { try $0.placeSprinkler("sprinkler", at: tiles[0], state: &$1) }.map { _ in 0 }, .failure(.noneInPouch))
        XCTAssertEqual(sim.work(.plow, at: spot, on: map).outcome, .failed(.cannotPlowHere))

        // Offline for half a day: the watered crop grows at full speed.
        sim.advance(by: GameTime.days(0.5), mode: .offline)
        let plot = sim.state.plots[neighbor]!
        XCTAssertTrue(plot.isWet(at: sim.state.worldTime))
        XCTAssertEqual(plot.crop!.wateredGrowth, plot.crop!.growth, accuracy: 1e-6)
        XCTAssertEqual(farming.toolAction(.water, at: neighbor, in: sim.state, seed: nil, checkReach: false), .failure(.alreadyWet))

        sim.stand(at: spot.center)
        XCTAssertEqual(sim.estate(on: map) { try $0.pickUpSprinkler(at: spot, state: &$1) }.map { _ in 0 }, .success(0))
        XCTAssertEqual(sim.state.inventory.count("sprinkler"), 1)
        XCTAssertTrue(sim.state.estate.sprinklers.isEmpty)
    }

    func testABigSprinklerCoversAFiveByFiveSquare() {
        let sprinkler = Sprinkler(tile: TileCoord(10, 10), kind: "sprinkler_pro")
        XCTAssertTrue(sprinkler.covers(TileCoord(12, 8)))
        XCTAssertFalse(sprinkler.covers(TileCoord(13, 10)))
        XCTAssertFalse(sprinkler.covers(TileCoord(10, 10)), "not its own tile")
        XCTAssertFalse(Sprinkler(tile: TileCoord(10, 10), kind: "sprinkler").covers(TileCoord(12, 10)))
    }

    // MARK: Farmhands

    func testHiringNeedsTheLevelAndPaysTheFirstWage() {
        var sim = sim(level: 3)
        XCTAssertEqual(sim.estate(on: map) { try $0.hire(.fields, state: &$1) }.map(\.id), .failure(.locked(level: 4)))
        sim.modify { $0.progress.level = 4 }
        let money = sim.state.money
        // Tuesday: six days until Monday.
        let first = Int((350.0 * 6 / 7).rounded(.up))
        guard case .success(let mia) = sim.estate(on: map, { try $0.hire(.fields, state: &$1) }) else { return XCTFail() }
        XCTAssertEqual(mia.name, "Mia")
        XCTAssertEqual(sim.state.money, money - first)
        XCTAssertEqual(sim.state.finance.thisWeek.expenses[LedgerCategory.wages], first)
        XCTAssertEqual(sim.estate(on: map) { try $0.hire(.animals, state: &$1) }.map(\.id), .failure(.locked(level: 6)))
        XCTAssertEqual(Bank.weeklyBills(sim.state, balance: balance).first { $0.category == LedgerCategory.wages }?.amount, 350)

        _ = sim.estate(on: map) { try $0.assign(mia.id, to: .animals, state: &$1) }
        XCTAssertEqual(sim.state.estate.workers.first?.job, .animals)
        _ = sim.estate(on: map) { try $0.dismiss(mia.id, state: &$1) }
        XCTAssertTrue(sim.state.estate.workers.isEmpty)
        XCTAssertNil(Bank.weeklyBills(sim.state, balance: balance).first { $0.category == LedgerCategory.wages })
    }

    func testAFieldHandWatersAndHarvestsDuringWorkingHours() {
        var sim = sim()
        let tiles = fieldTiles(12, in: sim)
        plant("wheat", at: tiles, in: &sim)
        sim.goHome()
        _ = sim.estate(on: map) { try $0.hire(.fields, state: &$1) }
        sim.modify { $0.rank.rank = FarmRanks.finale.id }  // no rank-up XP in the way
        let xp = sim.state.progress.xp
        let level = sim.state.progress.level

        play(&sim, hours: 1)  // 07:00 → 08:00: not started yet
        XCTAssertEqual(sim.state.estate.workers[0].tasksDone, 0)
        XCTAssertTrue(tiles.allSatisfy { !sim.state.plots[$0]!.isWet(at: sim.state.worldTime) })

        play(&sim, hours: 1)  // 08:00 → 09:00: 8 tasks
        XCTAssertEqual(sim.state.estate.workers[0].tasksDone, 8)
        XCTAssertEqual(tiles.filter { sim.state.plots[$0]!.isWet(at: sim.state.worldTime) }.count, 8)
        XCTAssertEqual(sim.state.estate.workers[0].lastTask, .water)

        // Ripe crops come first, into storage, with no XP for the farmer.
        sim.modify { state in
            for tile in tiles.prefix(3) {
                var plot = state.plots[tile]!
                plot.crop!.growth = CropCatalog.crop("wheat")!.growthSeconds
                state.plots[tile] = plot
            }
        }
        play(&sim, hours: 0.5)
        XCTAssertEqual(sim.state.estate.workers[0].tasksDone, 12)
        XCTAssertTrue(tiles.prefix(3).allSatisfy { sim.state.plots[$0]?.crop == nil })
        XCTAssertGreaterThanOrEqual(sim.state.inventory.count("wheat"), 9)
        XCTAssertEqual(sim.state.progress.xp, xp)
        XCTAssertEqual(sim.state.progress.level, level)

        // Nothing left to do: they wait (and don't bank the idle time).
        play(&sim, hours: 3)
        let done = sim.state.estate.workers[0].tasksDone
        XCTAssertLessThanOrEqual(sim.state.estate.workers[0].progress, 1)
        play(&sim, hours: 9)  // past 17:00 and through the night
        XCTAssertEqual(sim.state.estate.workers[0].tasksDone, done, "evenings off")
    }

    func testAFieldHandLeavesRipeCropsWhenStorageIsFull() {
        var sim = sim()
        let tiles = fieldTiles(2, in: sim)
        plant("wheat", at: tiles, in: &sim)
        sim.goHome()
        _ = sim.estate(on: map) { try $0.hire(.fields, state: &$1) }
        let capacity = sim.state.storageCapacity(balance)
        sim.modify { state in
            state.inventory.add("log", capacity - 2)
            for tile in tiles {
                var plot = state.plots[tile]!
                plot.crop!.growth = CropCatalog.crop("wheat")!.growthSeconds
                state.plots[tile] = plot
            }
        }
        play(&sim, hours: 2)
        XCTAssertTrue(tiles.allSatisfy { sim.state.plots[$0]?.crop?.isReady == true })
    }

    func testAnAnimalKeeperCollectsWatersAndFeeds() {
        var sim = sim()
        guard let coop = PenCatalog.pen("coop") else { return XCTFail() }
        sim.modify { state in
            state.ranch["coop"] = PenState(isRepaired: true, waterUntil: 0, animals: [
                AnimalState(id: 1, speciesID: "chicken", name: "Pip", age: 99_999, production: 99_999, happiness: 0.8),
                AnimalState(id: 2, speciesID: "chicken", name: "Dot", age: 99_999, production: nil, happiness: 0.8),
            ])
            state.inventory.add("animal_feed", 5)
        }
        _ = sim.estate(on: map) { try $0.hire(.animals, state: &$1) }
        play(&sim, hours: 1.5)  // 08:00 → 08:30: four tasks
        let pen = sim.state.ranch["coop"]
        XCTAssertGreaterThanOrEqual(sim.state.inventory.count("egg"), 1)
        XCTAssertTrue(pen.hasWater(at: sim.state.worldTime))
        XCTAssertFalse(pen.animals.contains(where: \.isHungry))
        XCTAssertEqual(sim.state.estate.workers[0].position, Ranching.workSpot(coop))
    }

    func testFarmhandsRestWhileTheGameIsClosed() {
        var sim = sim()
        let tiles = fieldTiles(4, in: sim)
        plant("wheat", at: tiles, in: &sim)
        _ = sim.estate(on: map) { try $0.hire(.fields, state: &$1) }
        sim.modify { $0.clock = GameClock(dayIndex: 1, hour: 10) }
        sim.advance(by: 2 * 3600, mode: .offline)
        XCTAssertEqual(sim.state.estate.workers[0].tasksDone, 0)
    }

    func testFrameSizeDoesNotChangeTheWork() {
        var frames = sim()
        let tiles = fieldTiles(30, in: frames)
        plant("carrot", at: tiles, in: &frames)
        frames.goHome()
        _ = frames.estate(on: map) { try $0.hire(.fields, state: &$1) }
        var chunks = frames
        for _ in 0..<(3 * 60 * 30) { frames.advance(by: 1.0 / 30, mode: .live) }
        chunks.advance(by: 3 * 60, mode: .live)
        XCTAssertEqual(frames.state.estate.workers[0].tasksDone, chunks.state.estate.workers[0].tasksDone)
        let now = frames.state.worldTime
        XCTAssertEqual(tiles.filter { frames.state.plots[$0]!.isWet(at: now) }, tiles.filter { chunks.state.plots[$0]!.isWet(at: now) })
    }
}
