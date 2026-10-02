import XCTest
@testable import AcresCore

final class StoreTests: XCTestCase {

    let balance = Balance.standard
    var keeping: Storekeeping { Storekeeping(balance: balance) }
    let store = StoreDefinition.corner

    /// Wednesday (day 2), 08:00, level 3, the truck parked at the shop.
    private func sim(rented: Bool = false, level: Int = 3) -> Simulation {
        var state = GameState.newGame(seed: 31)
        state.clock = GameClock(dayIndex: 2, hour: 8)
        state.finance.lastProcessedDay = 2
        state.contracts.nextID = 50
        state.progress.level = level
        state.money = 1_000
        state.truck.position = store.zone.center
        state.farmer.inTruck = true
        if rented {
            state.store.isRented = true
            state.store.shelves = (0..<balance.storeShelves).map { _ in Shelf() }
        }
        return Simulation(state: state)
    }

    /// Runs the calendar forward by game hours.
    private func play(_ sim: inout Simulation, hours: Double) -> [SimEvent] {
        sim.advance(by: hours * 60 / balance.gameMinutesPerRealSecond, mode: .live)
    }

    // MARK: Renting

    func testRentingNeedsTheLevelTheMoneyAndBeingThere() {
        var away = sim()
        away.modify { $0.farmer.inTruck = false; $0.farmer.position = HomeValleyMap.farmhouseDoor }
        XCTAssertEqual(away.store { try $0.rent(state: &$1) }, .failure(.notAtStore))

        var early = sim(level: 2)
        XCTAssertEqual(early.store { try $0.rent(state: &$1) }, .failure(.locked(level: 3)))

        var broke = sim()
        broke.modify { $0.money = 100 }
        XCTAssertEqual(broke.store { try $0.rent(state: &$1) }, .failure(.notEnoughMoney))

        var shop = sim()
        // Wednesday: the first payment covers five days until Monday.
        let first = Int((250.0 * 5 / 7).rounded(.up))
        XCTAssertEqual(shop.store { try $0.rent(state: &$1) }, .success(first))
        XCTAssertEqual(shop.state.money, 1_000 - first)
        XCTAssertTrue(shop.state.store.isRented)
        XCTAssertEqual(shop.state.store.shelves.count, balance.storeShelves)
        XCTAssertEqual(shop.state.finance.thisWeek.expenses[LedgerCategory.rent], first)
        XCTAssertEqual(shop.state.goals.count(GoalCounter.shopRented), 1)
        XCTAssertEqual(shop.store { try $0.rent(state: &$1) }, .failure(.alreadyRented))
    }

    func testRentIsPaidWithTheMondayBills() {
        var sim = sim(rented: true)
        XCTAssertTrue(Bank.weeklyBills(sim.state, balance: balance).contains { $0.category == LedgerCategory.rent })
        let money = sim.state.money
        sim.modify { $0.clock = GameClock(dayIndex: 6, hour: 23) }
        let events = sim.advance(by: 8 * 60 / balance.gameMinutesPerRealSecond, mode: .live)
        let tax = balance.propertyTaxPerWeek
        XCTAssertTrue(events.contains(.weeklyBills(week: 2, total: tax + balance.storeRentPerWeek)))
        XCTAssertEqual(sim.state.money, money - tax - balance.storeRentPerWeek)
    }

    func testEndingTheLeaseNeedsEmptyShelves() {
        var sim = sim(rented: true)
        sim.modify { $0.store.shelves[0] = Shelf(itemID: "carrot", stock: 3) }
        XCTAssertEqual(sim.store { try $0.endLease(state: &$1) }.map { _ in 0 }, .failure(.shelvesNotEmpty))
        sim.modify { $0.store.shelves[0].stock = 0 }
        XCTAssertEqual(sim.store { try $0.endLease(state: &$1) }.map { _ in 0 }, .success(0))
        XCTAssertFalse(sim.state.store.isRented)
        XCTAssertFalse(Bank.weeklyBills(sim.state, balance: balance).contains { $0.category == LedgerCategory.rent })
    }

    // MARK: Shelves

    func testStockingFillsShelvesFromTheTruck() {
        var sim = sim(rented: true)
        sim.modify { $0.truck.cargo.add("carrot", 30); $0.truck.cargo.add("egg", 10); $0.truck.cargo.add("animal_feed", 5) }
        XCTAssertEqual(sim.store { try $0.stock("carrot", state: &$1) }, .success(30))
        XCTAssertEqual(sim.state.store.shelves[0], Shelf(itemID: "carrot", stock: 25))
        XCTAssertEqual(sim.state.store.shelves[1], Shelf(itemID: "carrot", stock: 5))
        XCTAssertEqual(sim.state.truck.cargo.count("carrot"), 0)
        XCTAssertEqual(sim.store { try $0.stock("egg", count: 4, state: &$1) }, .success(4))
        XCTAssertEqual(sim.state.store.shelves[2], Shelf(itemID: "egg", stock: 4))
        XCTAssertEqual(sim.store { try $0.stock("animal_feed", state: &$1) }, .failure(.notSellable))
        XCTAssertEqual(sim.store { try $0.stock("milk", state: &$1) }, .failure(.nothingToStock))

        // Restocking tops up the shelves that already hold the item.
        sim.modify { $0.truck.cargo.add("carrot", 22) }
        XCTAssertEqual(sim.store { try $0.stock("carrot", state: &$1) }, .success(22))
        XCTAssertEqual(sim.state.store.shelves[1].stock, 25)
        XCTAssertEqual(sim.state.store.shelves[3], Shelf(itemID: "carrot", stock: 2))
    }

    func testStockingNeedsTheTruckAndARentedShop() {
        var notRented = sim()
        notRented.modify { $0.truck.cargo.add("carrot", 5) }
        XCTAssertEqual(notRented.store { try $0.stock("carrot", state: &$1) }, .failure(.notRented))

        var onFoot = sim(rented: true)
        onFoot.modify { state in
            state.truck.cargo.add("carrot", 5)
            state.truck.position = HomeValleyMap.truckParkingSpot
            state.farmer.inTruck = false
            state.farmer.position = self.store.zone.center
        }
        XCTAssertEqual(onFoot.store { try $0.stock("carrot", state: &$1) }, .failure(.truckNotHere))
    }

    func testStockingFromTheBagAndTakingBackIntoIt() {
        var sim = sim(rented: true)
        sim.modify { state in
            state.truck.position = HomeValleyMap.truckParkingSpot
            state.farmer.inTruck = false
            state.farmer.position = self.store.zone.center
            state.farmer.bag.add("carrot", 4)
        }
        XCTAssertEqual(sim.store { try $0.stock("carrot", state: &$1) }, .success(4))
        XCTAssertEqual(sim.state.farmer.bagCount, 0)
        XCTAssertEqual(sim.store { try $0.takeBack(shelf: 0, state: &$1) }, .success(4), "back into the bag (the truck's at the farm)")
        XCTAssertEqual(sim.state.farmer.bag.count("carrot"), 4)
    }

    func testStockAllAndFullShelves() {
        var sim = sim(rented: true)
        sim.modify { $0.truck.cargo.add("pumpkin", 60); $0.truck.cargo.add("wheat", 100) }
        // Pumpkins (most valuable) first: 25 + 25 + 10; wheat fills the other three shelves.
        XCTAssertEqual(sim.store { try $0.stockAll(state: &$1) }, .success(135))
        XCTAssertEqual(sim.state.store.shelves.map(\.itemID), ["pumpkin", "pumpkin", "pumpkin", "wheat", "wheat", "wheat"])
        XCTAssertEqual(sim.state.truck.cargo.count("wheat"), 25)
        XCTAssertEqual(sim.store { try $0.stockAll(state: &$1) }, .failure(.shelvesFull))
    }

    func testAnEmptyShelfKeepsItsPriceForTheSameGoods() {
        var sim = sim(rented: true)
        sim.modify { state in
            state.store.shelves[0] = Shelf(itemID: "egg", stock: 0, priceFactor: 1.5)
            state.truck.cargo.add("egg", 3)
            state.truck.cargo.add("milk", 3)
        }
        _ = sim.store { try $0.stock("milk", state: &$1) }
        XCTAssertEqual(sim.state.store.shelves[1].itemID, "milk", "never-used shelves are taken first")
        _ = sim.store { try $0.stock("egg", state: &$1) }
        XCTAssertEqual(sim.state.store.shelves[0], Shelf(itemID: "egg", stock: 3, priceFactor: 1.5))
    }

    func testTakingGoodsBackIntoTheTruck() {
        var sim = sim(rented: true)
        sim.modify { $0.store.shelves[2] = Shelf(itemID: "apple", stock: 20) }
        XCTAssertEqual(sim.store { try $0.takeBack(shelf: 2, state: &$1) }, .success(20))
        XCTAssertEqual(sim.state.truck.cargo.count("apple"), 20)
        XCTAssertEqual(sim.state.store.shelves[2].stock, 0)
        XCTAssertEqual(sim.store { try $0.takeBack(shelf: 2, state: &$1) }, .failure(.nothingToStock))
        XCTAssertEqual(sim.store { try $0.takeBack(shelf: 9, state: &$1) }, .failure(.unknownShelf))

        let capacity = balance.truckCargoCapacity
        sim.modify { $0.truck.cargo.add("wheat", capacity - 20); $0.store.shelves[0] = Shelf(itemID: "egg", stock: 5) }
        XCTAssertEqual(sim.store { try $0.takeBack(shelf: 0, state: &$1) }, .failure(.cargoFull))
    }

    func testPricesMoveInFivePercentStepsWithinLimits() {
        var sim = sim(rented: true)
        _ = sim.store { try $0.setPrice(shelf: 0, factor: 1.32, state: &$1) }
        XCTAssertEqual(sim.state.store.shelves[0].priceFactor, 1.3, accuracy: 1e-9)
        _ = sim.store { try $0.setPrice(shelf: 0, factor: 5, state: &$1) }
        XCTAssertEqual(sim.state.store.shelves[0].priceFactor, balance.storePriceFactorRange.upperBound)
        _ = sim.store { try $0.setPrice(shelf: 0, factor: 0.1, state: &$1) }
        XCTAssertEqual(sim.state.store.shelves[0].priceFactor, balance.storePriceFactorRange.lowerBound)
        XCTAssertEqual(keeping.unitPrice("pumpkin", factor: 1), 395, "the middle of 360…430")
        XCTAssertEqual(keeping.unitPrice("wheat", factor: 0.6), 7, "12 × 0.6")
    }

    // MARK: Customers

    func testCustomersBuyOnlyWhileTheShopIsOpen() {
        var sim = sim(rented: true)
        sim.modify { $0.store.shelves[0] = Shelf(itemID: "carrot", stock: 25) }
        let money = sim.state.money
        _ = play(&sim, hours: 1)  // 08:00 → 09:00: closed
        XCTAssertEqual(sim.state.store.shelves[0].stock, 25)

        _ = play(&sim, hours: 2)  // 09:00 → 11:00: 2 × 1.6 = 3.2 customers
        XCTAssertEqual(sim.state.store.shelves[0].stock, 22)
        let price = keeping.unitPrice("carrot")
        XCTAssertEqual(sim.state.money, money + 3 * price)
        XCTAssertEqual(sim.state.store.today, StoreDay(day: 2, coins: 3 * price, items: 3, sales: ["carrot": 3]))
        XCTAssertEqual(sim.state.finance.thisWeek.income[LedgerCategory.shopSales], 3 * price)
        XCTAssertEqual(sim.state.goals.count(GoalCounter.coinsFromShop), 3 * price)

        _ = play(&sim, hours: 12)  // until 23:00: sales stop at 18:00 (9 open hours in all)
        XCTAssertEqual(sim.state.store.shelves[0].stock, 25 - Int(1.6 * 9))

        // The next morning's takings start from zero.
        _ = play(&sim, hours: 8)
        XCTAssertEqual(sim.state.store.today.day, 3)
        XCTAssertEqual(sim.state.store.today.items, 0)
    }

    func testTheShopIsShutWhileTheGameIsClosed() {
        var sim = sim(rented: true)
        sim.modify { $0.store.shelves[0] = Shelf(itemID: "carrot", stock: 25); $0.clock = GameClock(dayIndex: 2, hour: 12) }
        sim.advance(by: 3 * 3600, mode: .offline)
        XCTAssertEqual(sim.state.store.shelves[0].stock, 25)
    }

    func testHigherPricesSellSlowerButTakingsPeakAboveTheUsualPrice() {
        func itemsPerDay(at factor: Double) -> Int {
            var sim = sim(rented: true)
            sim.modify { $0.store.shelves[0] = Shelf(itemID: "potato", stock: 25, priceFactor: factor) }
            _ = play(&sim, hours: 12)
            return sim.state.store.today.items
        }
        XCTAssertGreaterThan(itemsPerDay(at: 0.8), itemsPerDay(at: 1))
        XCTAssertGreaterThan(itemsPerDay(at: 1), itemsPerDay(at: 2))

        // Coins per open hour.
        func takings(at factor: Double) -> Double {
            let shelf = Shelf(itemID: "potato", stock: 25, priceFactor: factor)
            let store = StoreState(isRented: true, shelves: [shelf])
            return keeping.salesPerHour(shelf, in: store) * Double(keeping.unitPrice("potato", factor: factor))
        }
        let best = takings(at: 1.25)
        for factor in [0.6, 0.8, 1.0, 1.5, 1.75, 2.0] {
            XCTAssertGreaterThan(best, takings(at: factor), "× \(factor)")
        }
    }

    func testVarietyBringsMoreCustomers() {
        var one = StoreState(isRented: true, shelves: [Shelf(itemID: "carrot", stock: 5)])
        XCTAssertEqual(keeping.traffic(one), 1)
        one.shelves += [Shelf(itemID: "carrot", stock: 5), Shelf(itemID: "egg", stock: 5), Shelf(itemID: "apple", stock: 0)]
        XCTAssertEqual(keeping.traffic(one), 1 + balance.storeTrafficPerItem, accuracy: 1e-9, "sold-out shelves don't count")
        let many = StoreState(isRented: true, shelves: ["carrot", "egg", "milk", "apple", "log", "wheat"].map { Shelf(itemID: $0, stock: 1) })
        XCTAssertEqual(keeping.traffic(many), balance.storeTrafficMax, accuracy: 1e-9)
    }

    func testSellingOutRaisesAnEvent() {
        var sim = sim(rented: true)
        sim.modify { $0.store.shelves[0] = Shelf(itemID: "egg", stock: 2, priceFactor: 1, progress: 0) }
        let events = play(&sim, hours: 6)
        XCTAssertTrue(events.contains(.shelfSoldOut(itemID: "egg")))
        XCTAssertEqual(sim.state.store.shelves[0], Shelf(itemID: "egg", stock: 0, priceFactor: 1, progress: 0))
    }

    func testFrameSizeDoesNotChangeSales() {
        var frames = sim(rented: true)
        frames.modify { $0.store.shelves[0] = Shelf(itemID: "carrot", stock: 25); $0.store.shelves[1] = Shelf(itemID: "egg", stock: 25) }
        var chunks = frames
        for _ in 0..<(4 * 60 * 30) { frames.advance(by: 1.0 / 30, mode: .live) }  // 4 game hours at 30 fps
        chunks.advance(by: 4 * 60, mode: .live)
        XCTAssertEqual(frames.state.store.today.items, chunks.state.store.today.items)
        XCTAssertEqual(frames.state.store.shelves.map(\.stock), chunks.state.store.shelves.map(\.stock))
    }

    func testOpeningMinutesAcrossDays() {
        let day = GameClock.minutesPerDay
        XCTAssertEqual(StoreSystem.openMinutes(from: 0, to: day, store: store), 9 * 60)
        XCTAssertEqual(StoreSystem.openMinutes(from: 120, to: 240, store: store), 60, "08:00–10:00")
        XCTAssertEqual(StoreSystem.openMinutes(from: 600, to: day + 240, store: store), 120 + 60, "16:00 → next day 10:00")
        XCTAssertEqual(StoreSystem.openMinutes(from: 300, to: 300, store: store), 0)
    }

    func testTheShopLotIsDrivableAndReachable() {
        let map = HomeValleyMap.map
        XCTAssertFalse(TruckPhysics(map: map, tuning: balance.driving).collides(store.zone.center))
        XCTAssertNotNil(Pathfinder.path(on: map, from: HomeValleyMap.truckParkingSpot, to: store.zone.center))
        XCTAssertEqual(Place.near(store.zone.center), .store(store))
        XCTAssertFalse(map.isBlocked(TileCoord(containing: store.door - Vec2(0, 1))), "customers can reach the door")
    }
}
