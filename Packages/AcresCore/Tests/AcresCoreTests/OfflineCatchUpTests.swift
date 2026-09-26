import XCTest
@testable import AcresCore

final class OfflineCatchUpTests: XCTestCase {

    private let lastSeen = Date(timeIntervalSince1970: 1_800_000_000)

    private func simulation(dayIndex: Int = 2, hour: Double = 14) -> Simulation {
        var state = GameState.newGame(seed: 1)
        state.clock = GameClock(dayIndex: dayIndex, hour: hour)
        return Simulation(state: state)
    }

    func testShortAbsenceLeavesTheCalendarAlone() {
        var sim = simulation()
        let before = sim.state.clock
        let report = OfflineCatchUp.run(&sim, lastSeen: lastSeen, now: lastSeen + 10 * 60)

        XCTAssertEqual(sim.state.clock, before)
        XCTAssertEqual(sim.state.worldTime, 600, accuracy: 1e-6)
        XCTAssertFalse(report.startedNewDay)
        XCTAssertFalse(report.wasCapped)
        XCTAssertEqual(report.events, [])
    }

    func testLongAbsenceWakesTheFarmerAtSixTheNextMorning() {
        var sim = simulation(dayIndex: 2, hour: 14)
        let report = OfflineCatchUp.run(&sim, lastSeen: lastSeen, now: lastSeen + 5 * 3600)

        XCTAssertEqual(sim.state.clock.dayIndex, 3)
        XCTAssertEqual(sim.state.clock.hour, 6)
        XCTAssertEqual(sim.state.clock.minute, 0)
        XCTAssertEqual(sim.state.worldTime, 5 * 3600, accuracy: 1e-6, "growth runs on the full real time")
        XCTAssertTrue(report.startedNewDay)
        XCTAssertEqual(report.events, [.newDay(CalendarDate(dayIndex: 3, daysPerSeason: 7))])
        XCTAssertEqual(sim.state.stats.returns, 1)
    }

    func testAtMostOneDayIsSkippedNoMatterHowLongTheAbsence() {
        var sim = simulation(dayIndex: 2, hour: 9)
        let report = OfflineCatchUp.run(&sim, lastSeen: lastSeen, now: lastSeen + 2.5 * 24 * 3600)
        XCTAssertEqual(sim.state.clock.dayIndex, 3)
        XCTAssertEqual(report.dateBefore.dayIndex, 2)
        XCTAssertEqual(report.dateAfter.dayIndex, 3)
    }

    func testAbsenceBeyondTheCapIsTruncated() {
        var sim = simulation()
        let tenDays: TimeInterval = 10 * 24 * 3600
        let report = OfflineCatchUp.run(&sim, lastSeen: lastSeen, now: lastSeen + tenDays)

        XCTAssertTrue(report.wasCapped)
        XCTAssertEqual(report.awayDuration, tenDays, accuracy: 1e-6)
        XCTAssertEqual(report.simulatedDuration, Balance.standard.offlineCatchUpCap, accuracy: 1e-6)
        XCTAssertEqual(sim.state.worldTime, Balance.standard.offlineCatchUpCap, accuracy: 1e-6)
    }

    func testClockSetBackwardsSimulatesNothing() {
        var sim = simulation()
        let before = sim.state
        let report = OfflineCatchUp.run(&sim, lastSeen: lastSeen, now: lastSeen - 3600)

        XCTAssertTrue(report.clockWentBackwards)
        XCTAssertEqual(report.awayDuration, 0)
        XCTAssertEqual(sim.state, before)
        XCTAssertTrue(report.isWorthShowing(balance: .standard))
    }

    func testNewMorningCanStartANewSeason() {
        var sim = simulation(dayIndex: 6, hour: 20)  // Spring 7, evening
        let report = OfflineCatchUp.run(&sim, lastSeen: lastSeen, now: lastSeen + 8 * 3600)
        XCTAssertEqual(report.dateAfter.season, .summer)
        XCTAssertEqual(report.dateAfter.dayOfSeason, 1)
        XCTAssertTrue(report.events.contains(.newSeason(.summer, year: 1)))
    }

    func testAfterMidnightTheNextMorningIsTheSameNight() {
        // 03:00 at the end of day 4: "next morning" is 06:00, three hours later.
        var sim = simulation(dayIndex: 4, hour: 3)
        _ = OfflineCatchUp.run(&sim, lastSeen: lastSeen, now: lastSeen + 2 * 3600)
        XCTAssertEqual(sim.state.clock.dayIndex, 5)
        XCTAssertEqual(sim.state.clock.hour, 6)
    }

    func testTinyAbsenceIsNotWorthAWelcomeScreen() {
        var sim = simulation()
        let report = OfflineCatchUp.run(&sim, lastSeen: lastSeen, now: lastSeen + 20)
        XCTAssertFalse(report.isWorthShowing(balance: .standard))
        XCTAssertEqual(sim.state.stats.returns, 0)
    }
}
