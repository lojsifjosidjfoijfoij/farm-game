import XCTest
@testable import AcresCore

final class DailyTests: XCTestCase {

    let balance = Balance.standard
    var routine: DailyRoutine { DailyRoutine(balance: balance) }
    let map = HomeValleyMap.map

    private func sim(level: Int = 3) -> Simulation {
        var state = GameState.newGame(seed: 12)
        state.progress.level = level
        state.tutorial = .complete
        var sim = Simulation(state: state)
        sim.advance(by: 1, mode: .live)
        return sim
    }

    func testANewFarmGetsChoresAndASpecial() {
        let sim = sim()
        let daily = sim.state.daily
        XCTAssertEqual(daily.day, 0)
        XCTAssertEqual(daily.chores.count, 3)
        XCTAssertEqual(Set(daily.chores.map(\.counter)).count, 3, "three different chores")
        XCTAssertTrue(daily.chores.allSatisfy { $0.target > 0 && $0.coins > 0 && !$0.claimed })
        XCTAssertNotNil(daily.specialItem)
        XCTAssertTrue(Contracts.isObtainable(daily.specialItem!, level: 3))
    }

    func testChoresAreTheSameForTheSameDay() {
        var a = GameState.newGame(seed: 1)
        var b = GameState.newGame(seed: 999)
        routine.rollOver(&a, day: 5)
        routine.rollOver(&b, day: 5)
        XCTAssertEqual(a.daily.chores.map(\.counter), b.daily.chores.map(\.counter))
        XCTAssertEqual(a.daily.specialItem, b.daily.specialItem)
        XCTAssertEqual(a.rng, GameState.newGame(seed: 1).rng, "the game's own dice aren't used")
    }

    func testClaimingChoresAndTheBonus() {
        var sim = sim()
        let chores = sim.state.daily.chores
        let first = chores[0]
        XCTAssertNil(sim.modify { routine.claim(first.counter, state: &$0) }, "not done yet")
        let money = sim.state.money
        sim.modify { state in
            for chore in chores { state.goals.add(chore.counter, chore.target) }
        }
        XCTAssertTrue(sim.state.daily.allDone(in: sim.state))
        XCTAssertNil(sim.modify { routine.claimBonus(state: &$0) }, "claim the chores first")
        var total = 0
        for chore in chores {
            total += sim.modify { routine.claim(chore.counter, state: &$0) }?.coins ?? 0
        }
        XCTAssertEqual(total, chores.map(\.coins).reduce(0, +))
        XCTAssertNil(sim.modify { routine.claim(first.counter, state: &$0) }, "only once")
        let bonus = routine.bonus(sim.state)
        XCTAssertEqual(sim.modify { routine.claimBonus(state: &$0) }, bonus)
        XCTAssertNil(sim.modify { routine.claimBonus(state: &$0) })
        XCTAssertEqual(sim.state.money, money + total + bonus)
    }

    func testTheStreakGrowsWhenEveryChoreIsDoneAndResetsOtherwise() {
        var sim = sim()
        func finishToday() {
            let chores = sim.state.daily.chores
            sim.modify { state in
                for chore in chores { state.goals.add(chore.counter, chore.target) }
            }
        }
        finishToday()
        sim.advance(by: GameTime.day, mode: .live)
        XCTAssertEqual(sim.state.daily.day, 1)
        XCTAssertEqual(sim.state.daily.streak, 1)
        finishToday()
        sim.advance(by: GameTime.day, mode: .live)
        XCTAssertEqual(sim.state.daily.streak, 2)
        // A lazy day.
        sim.advance(by: GameTime.day, mode: .live)
        XCTAssertEqual(sim.state.daily.streak, 0)
        XCTAssertEqual(sim.state.daily.bestStreak, 2)
        XCTAssertFalse(sim.state.daily.bonusClaimed)
    }

    func testTheMarketSpecialPaysHalfAgainAsMuch() {
        var sim = sim()
        guard let special = sim.state.daily.specialItem else { return XCTFail() }
        let trading = Trading(balance: balance)
        let normal = MarketPricing.price(of: ItemCatalog.item(special)!, day: 0)
        XCTAssertTrue(trading.isSpecial(special, in: sim.state))
        XCTAssertEqual(trading.price(of: special, in: sim.state), Int((Double(normal) * 1.5).rounded()))
        let other = ItemCatalog.all.first { $0.category.isSellable && $0.id != special }!
        XCTAssertEqual(trading.price(of: other.id, in: sim.state), MarketPricing.price(of: other, day: 0))
        sim.advance(by: GameTime.day, mode: .live)
        XCTAssertEqual(sim.state.daily.day, 1)
    }

    func testWeatherIsFixedPerDayAndFollowsTheSeasons() {
        XCTAssertEqual(Weather.on(day: 0, balance: balance), .sunny)
        for day in 1..<200 {
            XCTAssertEqual(Weather.on(day: day, balance: balance), Weather.on(day: day, balance: balance))
        }
        let spring = (1..<7).map { Weather.on(day: $0, balance: balance) }
        XCTAssertFalse(spring.contains(.snow))
        let winters = (0..<20).flatMap { year in (21..<28).map { year * 28 + $0 } }.map { Weather.on(day: $0, balance: balance) }
        XCTAssertTrue(winters.contains(.snow))
        XCTAssertFalse(winters.contains(.rain))
        let all = (1..<400).map { Weather.on(day: $0, balance: balance) }
        let rain = Double(all.filter { $0 == .rain }.count) / Double(all.count)
        XCTAssertTrue((0.1...0.3).contains(rain), "rain on \(rain) of days")
    }

    func testRainWatersTheFields() {
        guard let rainy = (1..<60).first(where: { Weather.on(day: $0, balance: balance) == .rain }) else { return XCTFail() }
        var state = GameState.newGame(seed: 3)
        state.clock = GameClock(dayIndex: rainy, hour: 9)
        state.finance.lastProcessedDay = rainy
        state.daily.day = rainy
        state.contracts.nextID = 9
        let tile = TileCoord(20, 32)
        state.plots[tile] = Plot(tile: tile, crop: PlantedCrop(cropID: "wheat", plantedAt: 0))
        var sim = Simulation(state: state)
        sim.advance(by: 60, mode: .live)
        XCTAssertTrue(sim.state.plots[tile]!.isWet(at: sim.state.worldTime))

        // Sleeping through a rainy night: the crop grows wet all night.
        var night = state
        night.clock = GameClock(dayIndex: rainy, hour: 22)
        var sleeper = Simulation(state: night)
        _ = sleeper.sleep()
        let crop = sleeper.state.plots[tile]!.crop!
        XCTAssertEqual(crop.wateredGrowth, crop.growth, accuracy: 1)

        // Dry days don't water.
        guard let dry = (1..<60).first(where: { Weather.on(day: $0, balance: balance) == .sunny }) else { return XCTFail() }
        var sunny = state
        sunny.clock = GameClock(dayIndex: dry, hour: 9)
        sunny.finance.lastProcessedDay = dry
        sunny.daily.day = dry
        var sim2 = Simulation(state: sunny)
        sim2.advance(by: 60, mode: .live)
        XCTAssertFalse(sim2.state.plots[tile]!.isWet(at: sim2.state.worldTime))
    }
}
