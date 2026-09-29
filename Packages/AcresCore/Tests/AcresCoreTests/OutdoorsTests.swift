import XCTest
@testable import AcresCore

final class OutdoorsTests: XCTestCase {

    let map = HomeValleyMap.map
    let balance = Balance.standard
    let pond = Waters.water("farm_pond")!
    let lake = Waters.water("willow_lake")!

    private func sim(seed: UInt64 = 71, season: Season = .summer, hour: Int = 10) -> Simulation {
        var state = GameState.newGame(seed: seed)
        state.progress.level = 3
        state.tutorial = .complete
        state.clock = GameClock(dayIndex: season.rawValue * balance.daysPerSeason + 2, hour: Double(hour))
        state.finance.lastProcessedDay = state.clock.dayIndex
        state.daily.day = state.clock.dayIndex
        return Simulation(state: state)
    }

    // MARK: Water and fish

    func testWatersAreSolidWithReachableShores() {
        for water in Waters.all {
            XCTAssertTrue(map.isBlocked(TileCoord(containing: water.area.center)), "\(water.id) is water")
            let shore = water.shoreSpots
            XCTAssertGreaterThanOrEqual(shore.count, 6, water.id)
            for spot in shore { XCTAssertFalse(map.isBlocked(TileCoord(containing: spot)), "\(water.id) shore \(spot)") }
        }
        // You can walk to both: the pond from the farmhouse, the lake down the path from the village street.
        XCTAssertNotNil(pond.shoreSpots.lazy.compactMap { Pathfinder.path(on: self.map, from: HomeValleyMap.farmhouseDoor, to: $0) }.first)
        XCTAssertNotNil(lake.shoreSpots.lazy.compactMap { Pathfinder.path(on: self.map, from: Vec2(101.2, 22.6), to: $0) }.first)
    }

    func testSomethingAlwaysBites() {
        XCTAssertEqual(Set(FishCatalog.all.map(\.id)).count, FishCatalog.all.count)
        for fish in FishCatalog.all {
            XCTAssertFalse(fish.waters.isEmpty, fish.id)
            XCTAssertEqual(ItemCatalog.item(fish.id)?.category, .fish)
        }
        for kind in [WaterBody.Kind.pond, .lake] {
            for season in Season.allCases {
                for hour in [6, 12, 20, 2] {
                    XCTAssertFalse(FishCatalog.biting(in: kind, season: season, hour: hour).isEmpty, "\(kind) \(season) \(hour)h")
                }
            }
        }
        // The lake has its own fish.
        XCTAssertTrue(FishCatalog.biting(in: .lake, season: .autumn, hour: 10).contains { $0.id == "salmon" })
        XCTAssertFalse(FishCatalog.biting(in: .pond, season: .autumn, hour: 10).contains { $0.id == "salmon" })
        XCTAssertFalse(FishCatalog.biting(in: .pond, season: .summer, hour: 10).contains { $0.id == "catfish" }, "night only")
        XCTAssertTrue(FishCatalog.biting(in: .pond, season: .summer, hour: 21).contains { $0.id == "catfish" })
    }

    func testCastingAndLanding() {
        var game = sim()
        let target = pond.area.center
        XCTAssertEqual(game.outdoors { try $0.cast(at: target, state: &$2) }.map(\.fishID), .failure(.tooFar))
        game.stand(at: Vec2(pond.area.center.x, pond.area.minY - 0.7))
        XCTAssertEqual(game.outdoors { try $0.cast(at: Vec2(30, 30), state: &$2) }.map(\.fishID), .failure(.notWater))

        let energy = game.state.farmer.energy
        guard case .success(let bite) = game.outdoors({ try $0.cast(at: target, state: &$2) }) else { return XCTFail("cast") }
        XCTAssertEqual(game.state.farmer.energy, energy - balance.energyCost.cast)
        XCTAssertEqual(bite.waterID, "farm_pond")
        XCTAssertTrue(bite.fish!.waters.contains(.pond))

        // Same world, same cast, same fish.
        var twin = sim()
        twin.stand(at: Vec2(pond.area.center.x, pond.area.minY - 0.7))
        XCTAssertEqual(twin.outdoors { try $0.cast(at: target, state: &$2) }.map(\.fishID), .success(bite.fishID))

        let xp = game.state.progress.xp
        guard case .success(let caught) = game.outdoors({ try $0.land(bite, state: &$2) }) else { return XCTFail("land") }
        XCTAssertTrue(caught.isNew)
        XCTAssertEqual(game.state.inventory.count(bite.fishID), 1)
        XCTAssertEqual(game.state.goals.count(GoalCounter.fishCaught), 1)
        XCTAssertEqual(game.state.goals.count(GoalCounter.caught(bite.fishID)), 1)
        XCTAssertGreaterThan(game.state.progress.xp + game.state.progress.level * 1000, xp + 3 * 1000)
        guard case .success(let again) = game.outdoors({ try $0.land(bite, state: &$2) }) else { return XCTFail("land") }
        XCTAssertFalse(again.isNew)
    }

    func testTiredOrDrivingFarmersDontFish() {
        var game = sim()
        game.stand(at: Vec2(pond.area.center.x, pond.area.minY - 0.7))
        game.modify { $0.farmer.energy = 1 }
        XCTAssertEqual(game.outdoors { try $0.cast(at: self.pond.area.center, state: &$2) }.map(\.fishID), .failure(.tooTired))
        game.modify { $0.farmer.energy = 50; $0.farmer.inTruck = true }
        XCTAssertEqual(game.outdoors { try $0.cast(at: self.pond.area.center, state: &$2) }.map(\.fishID), .failure(.inTruck))
    }

    func testLegendsAreRareButReal() {
        var game = sim(season: .spring)
        game.stand(at: Vec2(pond.area.center.x, pond.area.minY - 0.7))
        var counts: [String: Int] = [:]
        for _ in 0..<3_000 {
            game.modify { $0.farmer.energy = 100 }
            if case .success(let bite) = game.outdoors({ try $0.cast(at: self.pond.area.center, state: &$2) }) {
                counts[bite.fishID, default: 0] += 1
            }
        }
        let koi = counts["golden_koi"] ?? 0
        XCTAssertGreaterThan(koi, 0)
        XCTAssertLessThan(Double(koi) / 3_000, 0.03)
        XCTAssertGreaterThan(counts["sunfish"] ?? 0, counts["perch"] ?? 0, "common fish are common")
    }

    // MARK: Foraging

    func testForageSpotsAreOpenGround() {
        let spots = Foraging.spots
        XCTAssertGreaterThan(spots.count, 150)
        for spot in spots {
            let tile = TileCoord(containing: spot)
            XCTAssertEqual(map.terrain(at: tile), .grass)
            XCTAssertFalse(map.isBlocked(tile), "\(spot)")
            XCTAssertFalse(HomeValleyMap.homeFarmArea.contains(spot), "not in the fields")
            XCTAssertFalse(PenCatalog.all.contains { $0.footprint.contains(spot) })
        }
        XCTAssertEqual(ForageCatalog.all.count, Set(ForageCatalog.all.map(\.id)).count)
        for season in Season.allCases { XCTAssertFalse(ForageCatalog.inSeason(season).isEmpty, "\(season)") }
    }

    func testFindsAreDailyAndSeasonal() {
        let forage = Foraging(balance: balance)
        let a = Foraging.spawns(day: 30, season: .autumn, count: forage.count(in: .autumn))
        XCTAssertEqual(a, Foraging.spawns(day: 30, season: .autumn, count: forage.count(in: .autumn)), "same day, same finds")
        XCTAssertNotEqual(a.map(\.id), Foraging.spawns(day: 31, season: .autumn, count: forage.count(in: .autumn)).map(\.id))
        XCTAssertEqual(a.count, balance.forageCount)
        XCTAssertEqual(Set(a.map(\.id)).count, a.count, "one find per spot")
        XCTAssertTrue(a.allSatisfy { ForageCatalog.find($0.item)?.season == .autumn })
        XCTAssertEqual(Foraging.spawns(day: 60, season: .winter, count: forage.count(in: .winter)).count, balance.forageWinterCount)
    }

    func testPickingAFind() {
        var game = sim(season: .spring)
        game.modify { $0.ownedProperties = PropertyCatalog.all.map(\.id) }  // no brush anywhere
        let forage = Foraging(balance: balance)
        let today = forage.today(game.state)
        XCTAssertEqual(today.count, balance.forageCount)
        let find = today[0]
        XCTAssertEqual(game.outdoors { try $1.pick(find.id, state: &$2) }.map(\.item), .failure(.tooFar))
        game.stand(at: find.position + Vec2(0.5, 0))
        XCTAssertEqual(game.outdoors { try $1.pick(find.id, state: &$2) }.map(\.item), .success(find.item))
        XCTAssertEqual(game.state.inventory.count(find.item), 1)
        XCTAssertEqual(game.state.goals.count(GoalCounter.foraged), 1)
        XCTAssertEqual(forage.today(game.state).count, balance.forageCount - 1, "gone once picked")
        XCTAssertEqual(game.outdoors { try $1.pick(find.id, state: &$2) }.map(\.item), .failure(.nothingHere))
        // Tomorrow brings new finds.
        game.modify { $0.clock = GameClock(dayIndex: $0.clock.dayIndex + 1, hour: 8) }
        XCTAssertEqual(forage.today(game.state).count, balance.forageCount)
    }

    func testFindsDontTurnUpInBrush() {
        let game = sim(season: .autumn)  // just the home farm: land for sale is overgrown
        let wild = WildLand(state: game.state)
        let today = Foraging(balance: balance).today(game.state)
        XCTAssertFalse(today.isEmpty)
        XCTAssertTrue(today.allSatisfy { !wild.contains(TileCoord(containing: $0.position)) })
    }

    func testFindsDontGrowOnFields() {
        var game = sim(season: .summer)
        let forage = Foraging(balance: balance)
        let find = forage.today(game.state)[0]
        let tile = TileCoord(containing: find.position)
        game.modify { $0.plots[tile] = Plot(tile: tile) }
        XCTAssertFalse(forage.today(game.state).contains { $0.id == find.id })
    }

    // MARK: Goats and orders

    func testGoatsLiveOnGoatHill() {
        let pen = PenCatalog.pen("goat_pen")!
        XCTAssertEqual(AnimalCatalog.species("goat")?.penID, pen.id)
        XCTAssertEqual(PropertyCatalog.property(containing: TileCoord(containing: pen.area.center))?.id, "goat_hill")
        var game = sim()
        game.modify { $0.progress.level = 5; $0.money = 20_000 }
        let ranching = Ranching(balance: balance)
        XCTAssertEqual(ranching.accessProblem(pen, in: game.state, checkReach: false), .notYourLand)
        XCTAssertEqual(game.estate(on: map) { try $0.buyLand("goat_hill", state: &$1) }.map { _ in 0 }, .success(0))
        XCTAssertNil(ranching.accessProblem(pen, in: game.state, checkReach: false))
        XCTAssertFalse(map.isBlocked(TileCoord(containing: Ranching.workSpot(pen))), "the gate is clear")
        XCTAssertNotNil(Pathfinder.path(on: map, from: Vec2(55.8, 50.3), to: Ranching.workSpot(pen)), "the track leads to the gate")
    }

    func testOrdersOnlyAskForWhatsAround() {
        XCTAssertTrue(Contracts.isInSeason("salmon", .autumn))
        XCTAssertFalse(Contracts.isInSeason("salmon", .spring))
        XCTAssertTrue(Contracts.isInSeason("carp", .winter))
        XCTAssertFalse(Contracts.isInSeason("chanterelle", .summer))
        XCTAssertFalse(Contracts.isInSeason("blackberry_jam", .winter))
        XCTAssertTrue(Contracts.isInSeason("wheat", .winter), "stored crops are fine")
        XCTAssertFalse(Contracts.isObtainable("golden_koi", level: 20), "no orders for legends")
        XCTAssertFalse(Contracts.isObtainable("perch", level: 1))
        XCTAssertTrue(Contracts.isObtainable("perch", level: 2))
        for client in ClientCatalog.all {
            XCTAssertTrue(client.wants.allSatisfy { ItemCatalog.item($0)?.category.isSellable == true }, client.id)
        }
    }
}
