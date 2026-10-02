import XCTest
@testable import AcresCore

final class DrivingTests: XCTestCase {

    let map = HomeValleyMap.map
    var physics: TruckPhysics { TruckPhysics(map: map, tuning: Balance.standard.driving) }

    private func drive(_ truck: inout TruckState, _ motion: inout TruckMotion, toward direction: Vec2, seconds: Double) -> [DriveEvent] {
        var events: [DriveEvent] = []
        for _ in 0..<Int(seconds * 60) {
            events += physics.step(&truck, &motion, input: DriveInput(direction: direction, throttle: 1), dt: 1.0 / 60)
        }
        return events
    }

    func testTheParkedTruckIsNotStuck() {
        XCTAssertFalse(physics.collides(HomeValleyMap.truckParkingSpot))
    }

    func testTruckAcceleratesTowardTheStick() {
        var truck = TruckState(position: Vec2(80, 24), heading: 0)  // on the village street
        var motion = TruckMotion()
        _ = drive(&truck, &motion, toward: Vec2(1, 0), seconds: 2)
        XCTAssertGreaterThan(truck.position.x, 85)
        XCTAssertEqual(truck.position.y, 24, accuracy: 0.3)
        XCTAssertEqual(motion.speed, Balance.standard.driving.maxSpeedAsphalt, accuracy: 0.01)
    }

    func testTruckTurnsToFaceTheStickAndStopsWhenReleased() {
        var truck = TruckState(position: Vec2(80, 24), heading: 0)
        var motion = TruckMotion()
        _ = drive(&truck, &motion, toward: Vec2(-1, 0), seconds: 1.5)
        XCTAssertEqual(abs(TruckPhysics.angleDifference(truck.heading, .pi)), 0, accuracy: 0.05)
        for _ in 0..<120 { physics.step(&truck, &motion, input: .idle, dt: 1.0 / 60) }
        XCTAssertTrue(motion.isStopped)
    }

    func testRoadsAreFasterThanGrass() {
        let tuning = Balance.standard.driving
        XCTAssertGreaterThan(tuning.maxSpeed(on: .asphalt), tuning.maxSpeed(on: .gravel))
        XCTAssertGreaterThan(tuning.maxSpeed(on: .gravel), tuning.maxSpeed(on: .grass))
    }

    func testTruckBumpsIntoTheFarmhouseInsteadOfDrivingThrough() {
        // Drive north from the yard straight at the farmhouse.
        var truck = TruckState(position: Vec2(21, 33.5), heading: .pi / 2)
        var motion = TruckMotion()
        let events = drive(&truck, &motion, toward: Vec2(0, 1), seconds: 3)
        XCTAssertLessThan(truck.position.y, 36.2)
        XCTAssertFalse(physics.collides(truck.position))
        XCTAssertTrue(events.contains { if case .bump = $0 { true } else { false } } || motion.speed < 1)
    }

    func testTruckStaysOnTheMap() {
        var truck = TruckState(position: Vec2(2, 2), heading: .pi)
        var motion = TruckMotion()
        _ = drive(&truck, &motion, toward: Vec2(-1, -1), seconds: 3)
        XCTAssertGreaterThanOrEqual(truck.position.x, 0.45)
        XCTAssertGreaterThanOrEqual(truck.position.y, 0.45)
    }

    func testDrivingUsesFuelAndAnEmptyTankOnlySlowsYouDown() {
        var truck = TruckState(position: Vec2(62, 24), heading: 0, fuel: 1)
        var motion = TruckMotion()
        let events = drive(&truck, &motion, toward: Vec2(1, 0), seconds: 4)
        XCTAssertEqual(truck.fuel, 0)
        XCTAssertTrue(events.contains(.ranOutOfFuel))
        let x = truck.position.x
        _ = drive(&truck, &motion, toward: Vec2(1, 0), seconds: 1)
        XCTAssertGreaterThan(truck.position.x, x + 1, "still moving")
        XCTAssertLessThan(motion.speed, Balance.standard.driving.maxSpeedAsphalt * 0.4)
    }

    func testDirectionIndex() {
        XCTAssertEqual(TruckPhysics.directionIndex(for: 0), 0)
        XCTAssertEqual(TruckPhysics.directionIndex(for: .pi / 2), 4)
        XCTAssertEqual(TruckPhysics.directionIndex(for: .pi), 8)
        XCTAssertEqual(TruckPhysics.directionIndex(for: -.pi / 2), 12)
        XCTAssertEqual(TruckPhysics.directionIndex(for: 2 * .pi - 0.01), 0)
    }

    func testEveryShopCanBeReachedFromTheFarm() {
        for shop in ShopCatalog.all {
            let path = Pathfinder.path(on: map, from: HomeValleyMap.truckParkingSpot, to: shop.zone.center)
            XCTAssertNotNil(path, "no route to \(shop.name)")
            for point in path ?? [] {
                XCTAssertFalse(map.isBlocked(TileCoord(containing: point)), "route to \(shop.name) crosses an obstacle")
            }
        }
    }

    func testAutopilotDrivesToTheMarket() {
        let market = ShopCatalog.first(.market)!
        var truck = TruckState(position: HomeValleyMap.truckParkingSpot, heading: .pi)
        var motion = TruckMotion()
        var pilot = Autopilot(path: Pathfinder.path(on: map, from: truck.position, to: market.zone.center)!)
        var seconds = 0.0
        while let input = pilot.input(for: truck), seconds < 90 {
            physics.step(&truck, &motion, input: input, dt: 1.0 / 30)
            seconds += 1.0 / 30
        }
        XCTAssertLessThan(seconds, 90, "arrived in time")
        XCTAssertTrue(market.zone.contains(truck.position), "ended at \(truck.position)")
        print("Farm → market by autopilot: \(Int(seconds)) s")
    }

    func testShopZonesAreDrivable() {
        for shop in ShopCatalog.all {
            XCTAssertFalse(physics.collides(shop.zone.center), "\(shop.name) zone center is blocked")
        }
    }
}

final class TradingTests: XCTestCase {

    /// A new game; with a position, the farmer has driven there by day.
    private func sim(at position: Vec2? = nil) -> Simulation {
        var state = GameState.newGame(seed: 5)
        state.clock = GameClock(dayIndex: 0, hour: 10)
        if let position {
            state.truck.position = position
            state.farmer.inTruck = true
        }
        return Simulation(state: state)
    }

    func testBuyingSeedsNeedsTheShopMoneyAndLevel() {
        var away = sim()
        XCTAssertEqual(away.trade { try $0.buySeeds("wheat", count: 1, state: &$1) }, .failure(.notAtShop(.seedShop)))

        var shop = sim(at: HomeValleyMap.seedShopZone.center)
        let before = shop.state.money
        XCTAssertEqual(shop.trade { try $0.buySeeds("wheat", count: 10, state: &$1) }, .success(40))
        XCTAssertEqual(shop.state.money, before - 40)
        XCTAssertEqual(shop.state.inventory.count("seeds_wheat"), 22)
        XCTAssertEqual(shop.trade { try $0.buySeeds("pumpkin", count: 1, state: &$1) }, .failure(.locked(level: 6)))
        shop.modify { $0.money = 3 }
        XCTAssertEqual(shop.trade { try $0.buySeeds("wheat", count: 1, state: &$1) }, .failure(.notEnoughMoney))
    }

    func testSellingFromTheTruckAtTheMarket() {
        var market = sim(at: HomeValleyMap.marketZone.center)
        XCTAssertEqual(market.trade { try $0.sellAll(state: &$1) }, .failure(.nothingToSell))
        market.modify { $0.truck.cargo.add("wheat", 5); $0.truck.cargo.add("carrot", 2) }
        let money = market.state.money
        let price = Trading(balance: .standard).price(of: "wheat", in: market.state)!
        XCTAssertEqual(market.trade { try $0.sell("wheat", count: 2, state: &$1) }, .success(price * 2))
        guard case .success(let rest) = market.trade({ try $0.sellAll(state: &$1) }) else { return XCTFail() }
        XCTAssertEqual(market.state.money, money + price * 2 + rest)
        XCTAssertEqual(market.state.truck.cargoCount, 0)
    }

    func testRefuelFillsAsFarAsMoneyAllows() {
        var gas = sim(at: HomeValleyMap.gasStationZone.center)
        XCTAssertEqual(gas.trade { try $0.refuel(state: &$1) }.map(\.cost), .failure(.tankFull))
        gas.modify { $0.truck.fuel = 20; $0.money = 10 }
        XCTAssertEqual(gas.trade { try $0.refuel(state: &$1) }.map(\.cost), .success(10))
        XCTAssertEqual(gas.state.truck.fuel, 40, accuracy: 1e-9)
        XCTAssertEqual(gas.state.money, 0)
    }

    func testLoadingAndUnloadingAtTheFarm() {
        var farm = sim()
        let bed = farm.balance.truckCargoCapacity
        farm.modify { $0.inventory.add("wheat", bed); $0.inventory.add("potato", 15) }
        guard case .success(let moved) = farm.trade({ try $0.loadAll(state: &$1) }) else { return XCTFail() }
        XCTAssertEqual(moved, bed, "the bed holds \(bed)")
        XCTAssertEqual(farm.state.truck.cargo.count("potato"), 15, "most valuable first")
        XCTAssertEqual(farm.trade { try $0.load("wheat", count: 1, state: &$1) }, .failure(.cargoFull))
        XCTAssertEqual(farm.trade { try $0.unload("potato", count: 5, state: &$1) }, .success(5))

        var away = sim(at: HomeValleyMap.marketZone.center)
        away.modify { $0.inventory.add("wheat", 3) }
        XCTAssertEqual(away.trade { try $0.load("wheat", count: 3, state: &$1) }, .failure(.notAtFarm))
    }

    func testFailedTradesChangeNothing() {
        var shop = sim(at: HomeValleyMap.seedShopZone.center)
        let before = shop.state
        _ = shop.trade { try $0.buySeeds("pumpkin", count: 1, state: &$1) }
        XCTAssertEqual(shop.state, before)
    }

    func testPricesStayInRangeAndChangeDaily() {
        for crop in CropCatalog.all {
            let prices = (0..<30).map { MarketPricing.price(of: crop, day: $0) }
            XCTAssertTrue(prices.allSatisfy(crop.sellPrice.contains))
            XCTAssertGreaterThan(Set(prices).count, 2, "\(crop.id) prices should vary")
            XCTAssertEqual(MarketPricing.price(of: crop, day: 3), MarketPricing.price(of: crop, day: 3))
        }
    }
}

final class TutorialTests: XCTestCase {

    func testTheTutorialWalksThroughTheCoreLoop() {
        var t = TutorialState.new
        XCTAssertFalse(t.handle(.plowed), "the welcome card comes first")
        XCTAssertTrue(t.handle(.next))
        XCTAssertEqual(t.step, .plow)
        t.handle(.plowed)
        XCTAssertEqual(t.step, .plowMore)
        for _ in 0..<TutorialState.rowLength { t.handle(.plowed) }
        XCTAssertEqual(t.step, .plant)
        for event: TutorialEvent in [.planted, .watered, .slept, .harvested, .claimedGoal, .loaded, .arrivedAtMarket, .sold,
                                     .boughtSeeds, .arrivedHome, .planted, .openedPhone, .acceptedOrder] {
            XCTAssertTrue(t.handle(event), "\(event) at \(t.step)")
        }
        XCTAssertEqual(t.step, .fieldsTour)
        XCTAssertFalse(t.handle(.planted), "a card step waits for its button")
        t.handle(.next)
        XCTAssertEqual(t.step, .finished)
        XCTAssertEqual(t.stepNumber, TutorialState.stepCount)
        t.handle(.next)
        XCTAssertFalse(t.isActive)
    }

    func testDoingALaterStepEarlySkipsAhead() {
        var t = TutorialState(step: .water)
        XCTAssertTrue(t.handle(.harvested), "harvesting without watering (or sleeping) still counts")
        XCTAssertEqual(t.step, .claimGoal)
        XCTAssertFalse(t.handle(.planted), "earlier steps don't go backwards, and replanting is far off")
        XCTAssertFalse(t.handle(.acceptedOrder), "nor does it jump far ahead")
        XCTAssertEqual(t.step, .claimGoal)
    }

    func testSavedStepNumbersNeverChange() {
        // Saves store the raw values: the old ones must mean the same steps forever.
        XCTAssertEqual(TutorialStep.sell.rawValue, 8)
        XCTAssertEqual(TutorialStep.done.rawValue, 11)
        XCTAssertEqual(Set(TutorialState.order), Set(TutorialStep.allCases), "every step is played")
        XCTAssertEqual(TutorialState.order.last, .done)
    }

    func testSendingArneHome() {
        var t = TutorialState.new
        t.skip()
        XCTAssertFalse(t.isActive)
        XCTAssertTrue(t.isRetired, "he won't drop by later either")
        XCTAssertFalse(t.handle(.next))
        XCTAssertNil(t.nextTopic(in: GameState.newGame(seed: 1)))
    }

    func testArneSaysLessAsTheFirstLoopGoesOn() {
        let details = TutorialState.order.map(\.detail)
        XCTAssertEqual(details.first, .walkthrough, "he walks you through the first moves")
        XCTAssertEqual(details, details.sorted(), "never more detail again once it has faded")
        XCTAssertEqual(TutorialStep.sleep.detail, .walkthrough, "the whole first day is walked through")
        XCTAssertEqual(TutorialStep.harvest.detail, .pointer)
        XCTAssertEqual(TutorialStep.acceptOrder.detail, .nudge)
    }

    func testArneDropsByWithWhatsNewThenSaysGoodbye() {
        var state = GameState.newGame(seed: 1)
        state.tutorial = TutorialState(step: .welcome)
        state.progress.level = 2
        XCTAssertNil(state.tutorial.nextTopic(in: state), "not during the first loop")

        state.tutorial = TutorialState(step: .done)
        state.progress.level = 1
        XCTAssertNil(state.tutorial.nextTopic(in: state), "nothing new at level 1")

        state.progress.level = 2
        var heard: [GuideTopic] = []
        while let topic = state.tutorial.nextTopic(in: state), topic != .farewell {
            heard.append(topic)
            state.tutorial.tell(topic)
        }
        XCTAssertEqual(heard, [.chores, .axe, .coop, .workshop], "one at a time, in order")
        XCTAssertNil(state.tutorial.nextTopic(in: state), "then he waits for level 3")

        state.progress.level = 4
        state.ranch["coop"].isRepaired = true
        state.store.isRented = true
        while let topic = state.tutorial.nextTopic(in: state), topic != .farewell {
            heard.append(topic)
            state.tutorial.tell(topic)
        }
        XCTAssertEqual(Array(heard.dropFirst(4)), [.fishing, .foraging, .almanac, .farmhand],
                       "the shop is skipped: the player rented it on their own")
        XCTAssertEqual(state.tutorial.nextTopic(in: state), .farewell)
        state.tutorial.tell(.farewell)
        XCTAssertTrue(state.tutorial.isRetired)
        XCTAssertNil(state.tutorial.nextTopic(in: state))
    }
}
