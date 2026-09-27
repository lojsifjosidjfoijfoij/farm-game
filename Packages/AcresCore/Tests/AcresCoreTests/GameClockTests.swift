import XCTest
@testable import AcresCore

final class GameClockTests: XCTestCase {

    func testNewGameStartsSpringDayOneAtSixInTheMorning() {
        let clock = GameClock()
        let date = clock.date(daysPerSeason: 7)
        XCTAssertEqual(date.year, 1)
        XCTAssertEqual(date.season, .spring)
        XCTAssertEqual(date.dayOfSeason, 1)
        XCTAssertEqual(clock.hour, 6)
        XCTAssertEqual(clock.minute, 0)
        XCTAssertEqual(clock.phase, .morning)
    }

    func testHourWrapsPastMidnightWithinTheSameGameDay() {
        // 18 game-hours after 06:00 is midnight, still the same farmer's day.
        let clock = GameClock(totalMinutes: 18 * 60)
        XCTAssertEqual(clock.dayIndex, 0)
        XCTAssertEqual(clock.hour, 0)
        XCTAssertEqual(clock.phase, .night)

        let late = GameClock(dayIndex: 3, hour: 2.5)  // 02:30 at the end of day 3
        XCTAssertEqual(late.dayIndex, 3)
        XCTAssertEqual(late.hour, 2)
        XCTAssertEqual(late.minute, 30)
    }

    func testCalendarRollsOverSeasonsAndYears() {
        XCTAssertEqual(CalendarDate(dayIndex: 6, daysPerSeason: 7).description, "Spring 7, Year 1")
        XCTAssertEqual(CalendarDate(dayIndex: 7, daysPerSeason: 7).description, "Summer 1, Year 1")
        XCTAssertEqual(CalendarDate(dayIndex: 21, daysPerSeason: 7).season, .winter)
        XCTAssertEqual(CalendarDate(dayIndex: 28, daysPerSeason: 7).description, "Spring 1, Year 2")
    }

    func testJumpToNextMorningFromLateNightLandsAtSixAM() {
        var clock = GameClock(dayIndex: 4, hour: 3)  // 03:00, end of day 4
        clock.jumpToNextMorning()
        XCTAssertEqual(clock.dayIndex, 5)
        XCTAssertEqual(clock.hour, 6)
        XCTAssertEqual(clock.minute, 0)
    }

    func testTimeNeverRunsBackwards() {
        var clock = GameClock(totalMinutes: 100)
        clock.advance(minutes: -50)
        clock.advance(minutes: .nan)
        XCTAssertEqual(clock.totalMinutes, 100)
        XCTAssertEqual(GameClock(totalMinutes: -10).totalMinutes, 0)
    }

    func testDayPhases() {
        XCTAssertEqual(DayPhase.at(hour: 6), .morning)
        XCTAssertEqual(DayPhase.at(hour: 12), .day)
        XCTAssertEqual(DayPhase.at(hour: 18), .evening)
        XCTAssertEqual(DayPhase.at(hour: 23), .night)
        XCTAssertEqual(DayPhase.at(hour: 3), .night)
    }

    func testAGameDayLastsTwentyFourRealMinutesByDefault() {
        XCTAssertEqual(Balance.standard.gameMinutesPerRealSecond, 1, accuracy: 1e-9, "one game minute per real second")
        XCTAssertEqual(Balance.standard.gameMinutesPerRealSecond * 24 * 60, GameClock.minutesPerDay, accuracy: 1e-9)
    }
}
