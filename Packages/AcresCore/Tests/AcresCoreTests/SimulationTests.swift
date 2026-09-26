import XCTest
@testable import AcresCore

/// A stand-in production system used to verify that the simulation gives the
/// same result no matter how time is chopped up, including storage limits.
/// (Phase 2+ systems follow the same pattern and get the same tests.)
private struct TestProducer: SimulationSystem {
    /// Seconds per unit produced.
    let interval: TimeInterval = 90
    let capacity = 100

    func step(_ state: inout GameState, _ context: inout StepContext) {
        // Test-only: borrows `money` as the storage counter and `progress.xp`
        // as integer milliseconds of progress toward the next unit.
        guard state.money < capacity else { return }  // storage full: production stops
        var progressMs = state.progress.xp + Int((context.dt * 1000).rounded())
        let intervalMs = Int(interval * 1000)
        while progressMs >= intervalMs && state.money < capacity {
            progressMs -= intervalMs
            state.money += 1
        }
        state.progress.xp = state.money >= capacity ? 0 : progressMs
    }
}

final class SimulationTests: XCTestCase {

    private func makeState() -> GameState {
        var state = GameState.newGame(seed: 42)
        state.money = 0
        return state
    }

    func testLivePlayRunsTheCalendar() {
        var sim = Simulation(state: makeState())
        let events = sim.advance(by: 20 * 60, mode: .live)  // one game day
        XCTAssertEqual(sim.state.clock.dayIndex, 1)
        XCTAssertEqual(sim.state.clock.hour, 6)
        XCTAssertEqual(sim.state.worldTime, 20 * 60, accuracy: 1e-6)
        XCTAssertEqual(sim.state.stats.playSeconds, 20 * 60, accuracy: 1e-6)
        XCTAssertEqual(events, [.newDay(CalendarDate(dayIndex: 1, daysPerSeason: 7))])
    }

    func testOfflineModeFreezesTheCalendarButNotTheWorld() {
        var sim = Simulation(state: makeState())
        sim.advance(by: 5 * 3600, mode: .offline)
        XCTAssertEqual(sim.state.clock.totalMinutes, 0)
        XCTAssertEqual(sim.state.worldTime, 5 * 3600, accuracy: 1e-6)
        XCTAssertEqual(sim.state.stats.offlineSeconds, 5 * 3600, accuracy: 1e-6)
    }

    func testSeasonChangesAfterSevenDaysOfPlay() {
        var sim = Simulation(state: makeState())
        let events = sim.advance(by: 7 * 20 * 60, mode: .live)
        XCTAssertTrue(events.contains(.newSeason(.summer, year: 1)))
        XCTAssertEqual(events.filter { if case .newDay = $0 { true } else { false } }.count, 7)
        XCTAssertEqual(sim.state.clock.date(daysPerSeason: 7).season, .summer)
    }

    func testOneBigAdvanceEqualsManySmallOnes() {
        let systems: [any SimulationSystem] = [ClockSystem(), TestProducer()]
        var big = Simulation(state: makeState(), systems: systems)
        var small = Simulation(state: makeState(), systems: systems)

        big.advance(by: 3 * 3600, mode: .live)
        for _ in 0..<(3 * 3600) {
            small.advance(by: 1, mode: .live)
        }

        XCTAssertEqual(big.state.money, small.state.money)
        XCTAssertEqual(big.state.money, 100, "3h at 1 per 90s would be 120, but storage caps at 100")
        XCTAssertEqual(big.state.clock.totalMinutes, small.state.clock.totalMinutes, accuracy: 1e-6)
        XCTAssertEqual(big.state.worldTime, small.state.worldTime, accuracy: 1e-6)
    }

    func testProductionMatchesExpectedRateBeforeStorageFills() {
        var sim = Simulation(state: makeState(), systems: [TestProducer()])
        sim.advance(by: 45 * 60, mode: .offline)  // 2700 s / 90 s = 30 units
        XCTAssertEqual(sim.state.money, 30)
    }

    func testThreeDayCatchUpIsFast() {
        var sim = Simulation(state: makeState(), systems: [ClockSystem(), TestProducer()])
        let start = Date()
        sim.advance(by: 3 * 24 * 3600, mode: .offline)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.0)
    }

    func testSimulationIsDeterministic() {
        var a = Simulation(state: .newGame(seed: 7))
        var b = Simulation(state: .newGame(seed: 7))
        a.advance(by: 12_345, mode: .live)
        b.advance(by: 12_345, mode: .live)
        XCTAssertEqual(a.state, b.state)
    }

    func testIgnoresNonsenseDurations() {
        var sim = Simulation(state: makeState())
        XCTAssertEqual(sim.advance(by: -5, mode: .live), [])
        XCTAssertEqual(sim.advance(by: .infinity, mode: .live), [])
        XCTAssertEqual(sim.state.worldTime, 0)
    }

    func testSeededRandomIsStableAndRoundTripsLargeStates() throws {
        var rng = SeededRandom(seed: 123)
        let first = (0..<3).map { _ in rng.next() }
        var again = SeededRandom(seed: 123)
        XCTAssertEqual(first, (0..<3).map { _ in again.next() })

        let big = SeededRandom(seed: .max - 3)
        let data = try JSONEncoder().encode(big)
        XCTAssertEqual(try JSONDecoder().decode(SeededRandom.self, from: data), big)

        XCTAssertEqual(SeededRandom.stableHash("acres"), SeededRandom.stableHash("acres"))
        XCTAssertNotEqual(SeededRandom.stableHash("acres"), SeededRandom.stableHash("acre"))
    }
}
