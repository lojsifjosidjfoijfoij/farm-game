import XCTest
@testable import AcresCore

final class FarmerTests: XCTestCase {

    let map = HomeValleyMap.map

    func testANewGameStartsMondayMorningAtTheFarmhouse() {
        let state = GameState.newGame(seed: 1)
        let date = state.clock.date(daysPerSeason: Balance.standard.daysPerSeason)
        XCTAssertEqual(date.weekday, .monday)
        XCTAssertEqual(date.week, 1)
        XCTAssertEqual(state.clock.hour, 6)
        XCTAssertEqual(state.farmerPosition, HomeValleyMap.farmhouseDoor)
        XCTAssertEqual(state.farmer.energy, Balance.standard.energyMax)
        XCTAssertFalse(Obstacles(map: map, state: state).isBlocked(TileCoord(containing: HomeValleyMap.farmhouseDoor)),
                       "the farmer can stand at the door")
    }

    func testWeekdaysCycle() {
        XCTAssertEqual(CalendarDate(dayIndex: 6, daysPerSeason: 7).weekday, .sunday)
        XCTAssertEqual(CalendarDate(dayIndex: 7, daysPerSeason: 7).weekday, .monday)
        XCTAssertEqual(CalendarDate(dayIndex: 7, daysPerSeason: 7).week, 2)
        XCTAssertEqual(CalendarDate(dayIndex: 7, daysPerSeason: 7).season, .summer, "a season is a week")
    }

    func testEnergyDrainsWhileAwakeButNotWhileAway() {
        var sim = Simulation(state: .newGame(seed: 2))
        sim.advance(by: 10 * 60, mode: .live)  // ten game hours
        XCTAssertEqual(sim.state.farmer.energy, 100 - 10 * sim.balance.energyDrainPerHour, accuracy: 1e-6)
        let before = sim.state.farmer.energy
        sim.advance(by: 10 * 60, mode: .offline)
        XCTAssertEqual(sim.state.farmer.energy, before, "offline time doesn't tire the farmer")
    }

    func testSleepingRunsTheNightAndRefillsEnergy() {
        var sim = Simulation(state: .newGame(seed: 3))
        sim.advance(by: 16 * 60, mode: .live)  // 22:00
        XCTAssertEqual(sim.state.clock.hour, 22)
        sim.modify { $0.farmer.energy = 20; $0.farmer.position = Vec2(30, 32) }
        let worldTime = sim.state.worldTime
        let report = sim.sleep()
        XCTAssertEqual(report.hoursSlept, 8, accuracy: 1e-6)
        XCTAssertEqual(sim.state.clock.hour, 6)
        XCTAssertEqual(sim.state.clock.dayIndex, 1)
        XCTAssertEqual(sim.state.worldTime, worldTime + 8 * 60, accuracy: 1e-6, "the farm grew through the night")
        XCTAssertEqual(sim.state.farmer.energy, sim.balance.energyMax, "8 hours fills you up")
        XCTAssertEqual(sim.state.farmer.position, HomeValleyMap.farmhouseDoor)
        XCTAssertEqual(sim.state.goals.count(GoalCounter.slept), 1)
    }

    func testStayingUpTooLateCostsSleep() {
        var sim = Simulation(state: .newGame(seed: 4))
        sim.advance(by: 20 * 60, mode: .live)  // 02:00
        XCTAssertTrue(sim.isTooLateToStayUp)
        sim.modify { $0.farmer.energy = 0 }
        let report = sim.sleep(passedOut: true)
        XCTAssertEqual(report.hoursSlept, 4, accuracy: 1e-6)
        XCTAssertEqual(sim.state.farmer.energy, 4 * sim.balance.energyPerSleepHour, accuracy: 1e-6, "only half rested")
        XCTAssertFalse(sim.isTooLateToStayUp)
    }

    func testALongAbsenceWakesARestedFarmer() {
        var sim = Simulation(state: .newGame(seed: 5))
        sim.modify { $0.farmer.energy = 5 }
        let seen = Date(timeIntervalSince1970: 1_900_000_000)
        _ = OfflineCatchUp.run(&sim, lastSeen: seen, now: seen + 5 * 3600)
        XCTAssertEqual(sim.state.farmer.energy, sim.balance.energyMax)
        XCTAssertEqual(sim.state.clock.hour, 6)
    }

    func testShopsKeepOpeningHoursAndTheMarketNeedsTheTruck() {
        var state = GameState.newGame(seed: 6)
        state.farmer.position = HomeValleyMap.seedShopZone.center  // walked there
        state.clock = GameClock(dayIndex: 0, hour: 6.5)
        var sim = Simulation(state: state)
        XCTAssertEqual(sim.trade { try $0.buySeeds("wheat", count: 1, state: &$1) }, .failure(.closed(opens: 8)))
        sim.modify { $0.clock = GameClock(dayIndex: 0, hour: 9) }
        XCTAssertEqual(sim.trade { try $0.buySeeds("wheat", count: 1, state: &$1) }, .success(4), "walking in works")

        sim.modify { $0.farmer.position = HomeValleyMap.marketZone.center; $0.truck.cargo.add("wheat", 2) }
        XCTAssertEqual(sim.trade { try $0.sellAll(state: &$1) }, .failure(.truckNotHere(.market)), "the goods are in the truck")
        sim.modify { $0.truck.position = HomeValleyMap.marketZone.center }
        guard case .success = sim.trade({ try $0.sellAll(state: &$1) }) else { return XCTFail("should sell") }
        XCTAssertGreaterThan(sim.state.goals.count(GoalCounter.coinsFromSales), 0)
        XCTAssertTrue(ShopCatalog.first(.gasStation)!.isAlwaysOpen)
    }

    func testGoalsOpenInOrderAndPayOut() {
        var sim = Simulation(state: .newGame(seed: 7))
        XCTAssertEqual(GoalCatalog.open(in: sim.state).map(\.id), ["plow8", "plant8", "sleep1"])
        XCTAssertNil(sim.claimGoal("plow8"), "not done yet")
        XCTAssertNil(sim.claimGoal("coop"), "not open yet")
        sim.recordGoal(GoalCounter.plowed, 8)
        let money = sim.state.money
        guard let claim = sim.claimGoal("plow8") else { return XCTFail("claimable") }
        XCTAssertEqual(sim.state.money, money + claim.goal.coins)
        XCTAssertEqual(GoalCatalog.open(in: sim.state).map(\.id), ["plant8", "sleep1", "harvest20"])
        XCTAssertNil(sim.claimGoal("plow8"), "only once")
    }

    func testEveryGoalIsReachable() {
        let counters = Set([GoalCounter.plowed, GoalCounter.planted, GoalCounter.harvested, GoalCounter.coinsFromSales,
                            GoalCounter.seedsBought, GoalCounter.slept, GoalCounter.treesChopped,
                            GoalCounter.fruitTreesPlanted, GoalCounter.collected("egg"), GoalCounter.collected("wool"),
                            GoalCounter.collected("truffle"),
                            GoalCounter.contractsCompleted, GoalCounter.shopRented, GoalCounter.coinsFromShop,
                            GoalCounter.landBought, GoalCounter.storageUpgrades, GoalCounter.sprinklersPlaced,
                            GoalCounter.workersHired, GoalCounter.crafted, GoalCounter.workshopsPlaced,
                            GoalCounter.fishCaught, GoalCounter.foraged, GoalCounter.casts])
        XCTAssertEqual(Set(GoalCatalog.all.map(\.id)).count, GoalCatalog.all.count, "unique ids")
        for goal in GoalCatalog.all {
            switch goal.requirement {
            case .count(let counter, _): XCTAssertTrue(counters.contains(counter), "\(goal.id) counts \(counter)")
            case .animals(let species, _): XCTAssertNotNil(AnimalCatalog.species(species))
            case .penRepaired(let pen): XCTAssertNotNil(PenCatalog.pen(pen))
            case .money, .level: break
            }
        }
    }

    func testTreeAndPenJobsNeedTheFarmerThere() {
        var sim = Simulation(state: .newGame(seed: 8))
        sim.modify { $0.progress.level = 5; $0.money = 5000 }
        let coop = PenCatalog.pen("coop")!
        XCTAssertEqual(sim.perform(.repair, on: coop).outcome, .failed(.tooFar))
        sim.stand(at: Ranching.workSpot(coop))
        XCTAssertFalse(Obstacles(map: map, state: sim.state).isBlocked(TileCoord(containing: Ranching.workSpot(coop))),
                       "the gate spot is walkable")
        XCTAssertEqual(sim.perform(.repair, on: coop).outcome, .repaired(penID: "coop"))
    }
}
