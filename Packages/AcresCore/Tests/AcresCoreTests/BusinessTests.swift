import XCTest
@testable import AcresCore

final class ContractTests: XCTestCase {

    let balance = Balance.standard
    var contracts: Contracts { Contracts(balance: balance) }

    /// A new game at 10:00 on day 0 with the first orders on the board.
    private func sim(seed: UInt64 = 21) -> Simulation {
        var state = GameState.newGame(seed: seed)
        state.clock = GameClock(dayIndex: 0, hour: 10)
        var sim = Simulation(state: state)
        sim.advance(by: 1, mode: .live)
        return sim
    }

    /// Parks the truck (with the farmer) at a client during opening hours.
    private func arrive(_ sim: inout Simulation, at client: ClientDefinition) {
        sim.modify { state in
            state.truck.position = client.zone.center
            state.farmer.inTruck = true
        }
    }

    private func contract(for client: String, _ items: [String: Int], reward: Int = 300, deadline: Int = 3) -> Contract {
        Contract(id: 900, clientID: client, items: items, reward: reward, xp: 12, deadlineDay: deadline, offeredDay: 0)
    }

    func testANewFarmGetsItsFirstOrders() {
        let sim = sim()
        let offers = sim.state.contracts.offers
        XCTAssertEqual(offers.count, balance.contractOffersOnBoard)
        for offer in offers {
            XCTAssertNotNil(offer.client)
            XCTAssertGreaterThan(offer.reward, 0)
            XCTAssertEqual(offer.reward % 5, 0)
            XCTAssertTrue((2...4).contains(offer.deadlineDay - offer.offeredDay))
            XCTAssertTrue(offer.items.values.allSatisfy { $0 >= 2 })
        }
        XCTAssertEqual(Set(offers.map(\.id)).count, offers.count, "unique ids")
    }

    func testOffersOnlyAskForWhatTheFarmCanMake() {
        for level in [1, 2, 3, 5, 8, 12] {
            for seed in 0..<20 {
                var state = GameState.newGame(seed: UInt64(seed))
                state.progress.level = level
                contracts.refreshOffers(&state)
                for offer in state.contracts.offers {
                    let client = offer.client!
                    for item in offer.items.keys {
                        XCTAssertTrue(Contracts.isObtainable(item, level: level), "\(item) at level \(level)")
                        XCTAssertTrue(client.wants.contains(item), "\(client.name) doesn't want \(item)")
                    }
                }
            }
        }
    }

    func testBetterReputationMeansBiggerOrders() {
        func averageReward(reputation: Int) -> Double {
            var total = 0
            var count = 0
            for seed in 0..<40 {
                var state = GameState.newGame(seed: UInt64(seed))
                state.progress.level = 4
                state.contracts.reputation = reputation
                contracts.refreshOffers(&state)
                total += state.contracts.offers.map(\.reward).reduce(0, +)
                count += state.contracts.offers.count
            }
            return Double(total) / Double(count)
        }
        XCTAssertGreaterThan(averageReward(reputation: 90), averageReward(reputation: 0) * 1.3)
    }

    func testOffersExpireFromTheBoardAfterTwoDays() {
        var state = GameState.newGame(seed: 3)
        contracts.refreshOffers(&state)
        let first = Set(state.contracts.offers.map(\.id))
        state.clock = GameClock(dayIndex: 1, hour: 6)
        contracts.refreshOffers(&state)
        XCTAssertEqual(Set(state.contracts.offers.map(\.id)), first, "still up the next day")
        state.clock = GameClock(dayIndex: 2, hour: 6)
        contracts.refreshOffers(&state)
        XCTAssertTrue(Set(state.contracts.offers.map(\.id)).isDisjoint(with: first), "gone after two days")
        XCTAssertEqual(state.contracts.offers.count, balance.contractOffersOnBoard)
    }

    func testAcceptingMovesAnOfferAndRestartsItsDeadline() {
        var sim = sim()
        sim.modify { state in
            state.clock = GameClock(dayIndex: 1, hour: 9)
        }
        let offer = sim.state.contracts.offers[0]
        let days = offer.deadlineDay - offer.offeredDay
        XCTAssertNoThrow(try sim.contracts { try $0.accept(offer.id, state: &$1) }.get())
        XCTAssertFalse(sim.state.contracts.offers.contains { $0.id == offer.id })
        XCTAssertEqual(sim.state.contracts.active.first?.deadlineDay, 1 + days)
        XCTAssertEqual(sim.contracts { try $0.accept(offer.id, state: &$1) }.map { _ in 0 }, .failure(.notFound))
    }

    func testThereIsALimitOnActiveContracts() {
        var sim = sim()
        sim.modify { state in
            state.contracts.active = (0..<self.balance.maxActiveContracts).map { index in
                var order = self.contract(for: "lumber_yard", ["log": 5])
                order.id = 500 + index
                return order
            }
        }
        let id = sim.state.contracts.offers[0].id
        XCTAssertEqual(sim.contracts { try $0.accept(id, state: &$1) }.map { _ in 0 }, .failure(.tooManyActive))
    }

    func testDeliveringFinishesAContractAndPays() {
        var sim = sim()
        let yard = ClientCatalog.client("lumber_yard")!
        sim.modify { state in
            state.contracts.active = [self.contract(for: "lumber_yard", ["log": 10], reward: 250)]
            state.truck.cargo.add("log", 6)
        }
        arrive(&sim, at: yard)
        let money = sim.state.money
        let reputation = sim.state.contracts.reputation

        guard case .success(let partial) = sim.contracts({ try $0.deliver(to: yard.id, state: &$1) }) else { return XCTFail() }
        XCTAssertEqual(partial.delivered, ["log": 6])
        XCTAssertTrue(partial.completed.isEmpty)
        XCTAssertEqual(sim.state.contracts.active.first?.remaining("log"), 4)
        XCTAssertEqual(sim.state.money, money, "paid only when finished")
        XCTAssertEqual(sim.contracts { try $0.deliver(to: yard.id, state: &$1) }.map(\.delivered), .failure(.nothingToDeliver))

        sim.modify { $0.truck.cargo.add("log", 9) }
        guard case .success(let rest) = sim.contracts({ try $0.deliver(to: yard.id, state: &$1) }) else { return XCTFail() }
        XCTAssertEqual(rest.delivered, ["log": 4])
        XCTAssertEqual(rest.completed.map(\.reward), [250])
        XCTAssertEqual(sim.state.truck.cargo.count("log"), 5, "extra logs stay on the truck")
        XCTAssertEqual(sim.state.money, money + 250)
        XCTAssertEqual(sim.state.finance.thisWeek.income[LedgerCategory.contracts], 250)
        XCTAssertTrue(sim.state.contracts.active.isEmpty)
        XCTAssertEqual(sim.state.contracts.completed, 1)
        XCTAssertEqual(sim.state.contracts.reputation, reputation + balance.reputationPerContract)
        XCTAssertEqual(sim.state.goals.count(GoalCounter.contractsCompleted), 1)
    }

    func testTheEarliestDeadlineIsServedFirst() {
        var sim = sim()
        let diner = ClientCatalog.client("rusty_spoon")!
        sim.modify { state in
            var late = self.contract(for: diner.id, ["carrot": 5], deadline: 4)
            late.id = 1
            var soon = self.contract(for: diner.id, ["carrot": 5], deadline: 2)
            soon.id = 2
            state.contracts.active = [late, soon]
            state.truck.cargo.add("carrot", 5)
        }
        arrive(&sim, at: diner)
        guard case .success(let result) = sim.contracts({ try $0.deliver(to: diner.id, state: &$1) }) else { return XCTFail() }
        XCTAssertEqual(result.completed.map(\.id), [2])
        XCTAssertEqual(sim.state.contracts.active.map(\.id), [1])
    }

    func testDeliveryNeedsTheTruckAtTheClientDuringOpeningHours() {
        var sim = sim()
        let bakery = ClientCatalog.client("hansens_bakery")!
        sim.modify { state in
            state.contracts.active = [self.contract(for: bakery.id, ["wheat": 5])]
            state.truck.cargo.add("wheat", 5)
        }
        XCTAssertEqual(sim.contracts { try $0.deliver(to: bakery.id, state: &$1) }.map(\.delivered), .failure(.notAtClient))

        // The farmer walked over, but the truck is still back at the farm.
        sim.modify { $0.farmer.inTruck = false; $0.farmer.position = bakery.zone.center }
        XCTAssertEqual(sim.contracts { try $0.deliver(to: bakery.id, state: &$1) }.map(\.delivered), .failure(.truckNotHere))

        arrive(&sim, at: bakery)
        sim.modify { $0.clock = GameClock(dayIndex: 0, hour: 18) }
        XCTAssertEqual(sim.contracts { try $0.deliver(to: bakery.id, state: &$1) }.map(\.delivered),
                       .failure(.closed(opens: bakery.opens)))
        let before = sim.state
        _ = sim.contracts { try $0.deliver(to: bakery.id, state: &$1) }
        XCTAssertEqual(sim.state, before, "failures change nothing")

        sim.modify { $0.clock = GameClock(dayIndex: 1, hour: 5) }
        XCTAssertEqual(sim.contracts { try $0.deliver(to: bakery.id, state: &$1) }.map(\.delivered), .success(["wheat": 5]),
                       "bakers start early")
    }

    func testLateContractsFailAndCostReputation() {
        var sim = sim()
        sim.modify { state in
            state.contracts.active = [self.contract(for: "lumber_yard", ["log": 50], deadline: 1)]
        }
        let reputation = sim.state.contracts.reputation
        // Day 1 is the deadline: still fine that morning.
        var events = sim.advance(by: GameTime.hour * 21, mode: .live)
        XCTAssertEqual(sim.state.clock.dayIndex, 1)
        XCTAssertFalse(events.contains { if case .contractFailed = $0 { true } else { false } })
        XCTAssertEqual(sim.state.contracts.active.count, 1)

        events = sim.advance(by: GameTime.day, mode: .live)
        XCTAssertEqual(sim.state.clock.dayIndex, 2)
        XCTAssertTrue(events.contains(.contractFailed(id: 900, clientID: "lumber_yard")))
        XCTAssertTrue(sim.state.contracts.active.isEmpty)
        XCTAssertEqual(sim.state.contracts.failed, 1)
        XCTAssertEqual(sim.state.contracts.reputation, max(0, reputation - balance.reputationPerFailure))
    }

    func testClientZonesAreDrivableAndReachable() {
        let map = HomeValleyMap.map
        let physics = TruckPhysics(map: map, tuning: balance.driving)
        for client in ClientCatalog.all {
            XCTAssertFalse(physics.collides(client.zone.center), "\(client.name) zone center is blocked")
            XCTAssertNotNil(Pathfinder.path(on: map, from: HomeValleyMap.truckParkingSpot, to: client.zone.center),
                            "no route to \(client.name)")
            for item in client.wants { XCTAssertNotNil(ItemCatalog.item(item), "\(client.name) wants \(item)") }
        }
    }

    func testPlacesDontOverlapAndTheClosestOneWins() {
        let places = Place.all
        XCTAssertEqual(Set(places.map(\.id)).count, places.count, "unique ids")
        for (index, place) in places.enumerated() {
            for other in places[(index + 1)...] {
                XCTAssertFalse(place.zone.intersects(other.zone), "\(place.name) overlaps \(other.name)")
            }
            XCTAssertEqual(Place.near(place.zone.center), place)
        }
        // Where the bank's and market's margins overlap, the closer zone wins.
        XCTAssertEqual(Place.near(Vec2(105.8, 26))?.id, "village_market")
        XCTAssertEqual(Place.near(Vec2(106.4, 26))?.id, "valley_bank")
        XCTAssertNil(Place.near(HomeValleyMap.truckParkingSpot))
    }
}

final class FinanceTests: XCTestCase {

    let balance = Balance.standard

    private func bankSim() -> Simulation {
        var state = GameState.newGame(seed: 9)
        state.clock = GameClock(dayIndex: 2, hour: 11)
        state.finance.lastProcessedDay = 2
        state.truck.position = HomeValleyMap.bankZone.center
        state.farmer.inTruck = true
        return Simulation(state: state)
    }

    func testMoneyInAndOutIsBookedByCategory() {
        var sim = Simulation(state: .newGame(seed: 2))
        sim.visit(HomeValleyMap.seedShopZone)
        _ = sim.trade { try $0.buySeeds("wheat", count: 5, state: &$1) }
        sim.visit(HomeValleyMap.marketZone)
        sim.modify { $0.truck.cargo.add("wheat", 3) }
        guard case .success(let earned) = sim.trade({ try $0.sellAll(state: &$1) }) else { return XCTFail() }
        let ledger = sim.state.finance.thisWeek
        XCTAssertEqual(ledger.expenses[LedgerCategory.seeds], 20)
        XCTAssertEqual(ledger.income[LedgerCategory.marketSales], earned)
        XCTAssertEqual(ledger.profit, earned - 20)
    }

    func testBillsArePaidEveryMondayAndTheBooksRoll() {
        var sim = Simulation(state: .newGame(seed: 4))
        sim.modify { $0.finance.earn(500, LedgerCategory.marketSales) }
        let money = sim.state.money
        // Sunday night → Monday morning.
        sim.modify { $0.clock = GameClock(dayIndex: 6, hour: 23) }
        let events = sim.advance(by: GameTime.hour * 8, mode: .live)
        let tax = balance.propertyTaxPerWeek * sim.state.ownedProperties.count
        XCTAssertTrue(events.contains(.weeklyBills(week: 2, total: tax)))
        XCTAssertEqual(sim.state.money, money - tax)
        XCTAssertEqual(sim.state.finance.lastWeek?.week, 1)
        XCTAssertEqual(sim.state.finance.lastWeek?.income[LedgerCategory.marketSales], 500)
        XCTAssertEqual(sim.state.finance.thisWeek.week, 2)
        XCTAssertEqual(sim.state.finance.thisWeek.expenses[LedgerCategory.propertyTax], tax)
        XCTAssertEqual(sim.state.finance.lastProcessedDay, 7)

        // Nothing more until next Monday.
        let later = sim.advance(by: GameTime.days(3), mode: .live)
        XCTAssertFalse(later.contains { if case .weeklyBills = $0 { true } else { false } })
    }

    func testBillsCanPutTheFarmInDebt() {
        var sim = Simulation(state: .newGame(seed: 4))
        sim.modify { $0.money = 30; $0.clock = GameClock(dayIndex: 6, hour: 23) }
        sim.advance(by: GameTime.hour * 8, mode: .live)
        XCTAssertLessThan(sim.state.money, 0)
        sim.visit(HomeValleyMap.seedShopZone)
        XCTAssertEqual(sim.trade { try $0.buySeeds("wheat", count: 1, state: &$1) }, .failure(.notEnoughMoney))
    }

    func testSleepingThroughSeveralDaysStillProcessesEachMorning() {
        var sim = Simulation(state: .newGame(seed: 6))
        let tax = balance.propertyTaxPerWeek * sim.state.ownedProperties.count
        let events = sim.advance(by: GameTime.days(15), mode: .live)
        XCTAssertEqual(events.filter { if case .weeklyBills = $0 { true } else { false } }.count, 2)
        XCTAssertEqual(sim.state.finance.lastProcessedDay, sim.state.clock.dayIndex)
        XCTAssertEqual(sim.state.finance.thisWeek.week, 3)
        XCTAssertEqual(sim.state.finance.thisWeek.expenses[LedgerCategory.propertyTax], tax)
    }

    func testSleepingIntoMondayPaysTheBills() {
        var sim = Simulation(state: .newGame(seed: 4))
        sim.modify { $0.clock = GameClock(dayIndex: 6, hour: 21) }
        sim.advance(by: 1, mode: .live)
        let report = sim.sleep()
        XCTAssertEqual(sim.state.clock.dayIndex, 7)
        XCTAssertTrue(report.events.contains { if case .weeklyBills = $0 { true } else { false } })
        XCTAssertEqual(sim.state.finance.lastProcessedDay, 7)
    }

    func testTakingAndRepayingALoan() {
        var sim = bankSim()
        XCTAssertEqual(Trading(balance: balance).loanOffers(sim.state).map(\.amount), [1_000])
        XCTAssertEqual(sim.trade { try $0.takeLoan(5_000, state: &$1) }.map(\.amount), .failure(.unknownItem), "level 4")

        let money = sim.state.money
        guard case .success(let loan) = sim.trade({ try $0.takeLoan(1_000, state: &$1) }) else { return XCTFail() }
        XCTAssertEqual(loan.balance, 1_120)
        XCTAssertEqual(loan.weeklyPayment, 280)
        XCTAssertEqual(sim.state.money, money + 1_000)
        XCTAssertEqual(sim.state.finance.thisWeek.income[LedgerCategory.loans], 1_000)
        XCTAssertEqual(sim.trade { try $0.takeLoan(1_000, state: &$1) }.map(\.amount), .failure(.alreadyHaveLoan))

        sim.modify { $0.money = 500 }
        XCTAssertEqual(sim.trade { try $0.repayLoan(state: &$1) }, .failure(.notEnoughMoney))
        sim.modify { $0.money = 2_000 }
        XCTAssertEqual(sim.trade { try $0.repayLoan(state: &$1) }, .success(1_120))
        XCTAssertNil(sim.state.finance.loan)
        XCTAssertEqual(sim.state.money, 880)
        XCTAssertEqual(sim.trade { try $0.repayLoan(state: &$1) }, .failure(.noLoan))
    }

    func testTheBankKeepsOfficeHours() {
        var sim = bankSim()
        sim.modify { $0.clock = GameClock(dayIndex: 2, hour: 17) }
        XCTAssertEqual(sim.trade { try $0.takeLoan(1_000, state: &$1) }.map(\.amount), .failure(.closed(opens: 9)))
        sim.modify { $0.truck.position = HomeValleyMap.marketZone.center; $0.clock = GameClock(dayIndex: 2, hour: 11) }
        XCTAssertEqual(sim.trade { try $0.takeLoan(1_000, state: &$1) }.map(\.amount), .failure(.notAtShop(.bank)))
    }

    func testLoansArePaidOffInWeeklyInstalments() {
        var sim = bankSim()
        _ = sim.trade { try $0.takeLoan(1_000, state: &$1) }
        let tax = balance.propertyTaxPerWeek * sim.state.ownedProperties.count
        var paid = 0
        var mondays = 0
        for _ in 0..<38 {
            let before = sim.state.money
            let events = sim.advance(by: GameTime.days(1), mode: .live)
            if events.contains(where: { if case .weeklyBills = $0 { true } else { false } }) {
                mondays += 1
                paid += before - sim.state.money - tax
            }
        }
        XCTAssertEqual(mondays, 5)
        XCTAssertEqual(paid, 1_120, "four instalments, then nothing")
        XCTAssertNil(sim.state.finance.loan)
    }
}
