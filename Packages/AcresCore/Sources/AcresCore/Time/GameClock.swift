import Foundation

/// Game-time units for content. One game day is 24 real minutes at normal
/// speed (one game minute per real second), like Big Ambitions: long enough
/// for a working day, short enough that things happen.
public enum GameTime {
    public static let day: TimeInterval = 24 * 60
    public static let hour: TimeInterval = 60

    public static func days(_ count: Double) -> TimeInterval { count * day }
}

/// The days of the week. Day 0 of the game is a Monday.
public enum Weekday: Int, CaseIterable, Sendable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    public var name: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }

    public var short: String { String(name.prefix(3)) }
}

/// The four seasons. Each lasts `Balance.daysPerSeason` in-game days.
public enum Season: Int, Codable, CaseIterable, Sendable {
    case spring, summer, autumn, winter

    public var name: String {
        switch self {
        case .spring: "Spring"
        case .summer: "Summer"
        case .autumn: "Autumn"
        case .winter: "Winter"
        }
    }

    public var next: Season { Season(rawValue: (rawValue + 1) % 4)! }
}

/// Coarse part of the day, used for lighting, music and HUD icons.
public enum DayPhase: String, Codable, CaseIterable, Sendable {
    case morning   // 06:00–10:00
    case day       // 10:00–17:00
    case evening   // 17:00–21:00
    case night     // 21:00–06:00

    /// `hour` is a wall-clock hour in 0..<24.
    public static func at(hour: Double) -> DayPhase {
        switch hour {
        case 6..<10: .morning
        case 10..<17: .day
        case 17..<21: .evening
        default: .night
        }
    }
}

/// A calendar date derived from a day index. Not stored; always computed.
public struct CalendarDate: Equatable, Hashable, Sendable, CustomStringConvertible {
    /// Days since the very first morning of the game (0-based).
    public let dayIndex: Int
    /// 1-based year.
    public let year: Int
    public let season: Season
    /// 1-based day within the season.
    public let dayOfSeason: Int

    public init(dayIndex: Int, daysPerSeason: Int) {
        precondition(daysPerSeason > 0)
        let day = max(0, dayIndex)
        let seasonIndex = day / daysPerSeason
        self.dayIndex = day
        self.year = seasonIndex / 4 + 1
        self.season = Season(rawValue: seasonIndex % 4)!
        self.dayOfSeason = day % daysPerSeason + 1
    }

    public var weekday: Weekday { Weekday(rawValue: dayIndex % 7)! }

    /// 1-based week number since the start of the game.
    public var week: Int { dayIndex / 7 + 1 }

    public var description: String { "\(season.name) \(dayOfSeason), Year \(year)" }
}

/// The in-game calendar clock.
///
/// A game day runs from 06:00 to 06:00 the next morning (the farmer's day,
/// not midnight-to-midnight), so "the next day" always begins at sunrise.
///
/// Stored as a single number — in-game minutes since Year 1, Spring 1, 06:00 —
/// which makes saving, comparing and fast-forwarding trivial.
///
/// Note: the calendar only runs while the game is being played. Growth and
/// production run on *real* time (`GameState.worldTime`). See `OfflineCatchUp`.
public struct GameClock: Codable, Equatable, Sendable {
    public static let minutesPerDay: Double = 24 * 60
    /// The wall-clock hour at which each game day begins.
    public static let dayStartHour: Double = 6

    /// In-game minutes since the first morning. Never negative.
    public private(set) var totalMinutes: Double

    public init(totalMinutes: Double = 0) {
        self.totalMinutes = max(0, totalMinutes)
    }

    /// Convenience for tests and debug tools.
    public init(dayIndex: Int, hour: Double) {
        var minuteOfDay = (hour - Self.dayStartHour) * 60
        if minuteOfDay < 0 { minuteOfDay += Self.minutesPerDay }
        self.init(totalMinutes: Double(dayIndex) * Self.minutesPerDay + minuteOfDay)
    }

    /// 0-based index of the current game day.
    public var dayIndex: Int { Int((totalMinutes / Self.minutesPerDay).rounded(.down)) }

    /// Minutes since this game day's 06:00 start, in 0..<1440.
    public var minuteOfDay: Double {
        totalMinutes - Double(dayIndex) * Self.minutesPerDay
    }

    /// Wall-clock hour in 0..<24, fractional (e.g. 18.5 = 6:30 PM).
    public var hourOfDay: Double {
        (Self.dayStartHour + minuteOfDay / 60).truncatingRemainder(dividingBy: 24)
    }

    /// Whole wall-clock hour, 0...23.
    public var hour: Int { Int(hourOfDay.rounded(.down)) % 24 }

    /// Whole minute within the hour, 0...59.
    public var minute: Int { Int((hourOfDay * 60).rounded(.down)) % 60 }

    public var phase: DayPhase { .at(hour: hourOfDay) }

    public func date(daysPerSeason: Int) -> CalendarDate {
        CalendarDate(dayIndex: dayIndex, daysPerSeason: daysPerSeason)
    }

    /// Moves the clock forward. Negative values are ignored: time never runs backwards.
    public mutating func advance(minutes: Double) {
        guard minutes > 0, minutes.isFinite else { return }
        totalMinutes += minutes
    }

    /// In-game minutes until the next 06:00.
    public var minutesUntilNextMorning: Double { Self.minutesPerDay - minuteOfDay }

    /// Jumps to 06:00 at the start of the next game day ("you slept").
    public mutating func jumpToNextMorning() {
        totalMinutes = Double(dayIndex + 1) * Self.minutesPerDay
    }
}
