import Foundation

/// Every tunable number in the game lives here.
///
/// Rule of thumb: if a designer might want to tweak it, it belongs in `Balance`,
/// not hard-coded in a system. Systems receive the balance through the
/// `Simulation`, so tests can run with modified values.
///
/// Changing numbers here never breaks a save file: saves store *state*
/// (timestamps, counts), never derived balancing values.
public struct Balance: Sendable, Equatable {

    // MARK: - Time

    /// Real seconds for one full in-game day (06:00 → 06:00) while playing.
    public var realSecondsPerGameDay: Double = 20 * 60

    /// In-game days per season. Four seasons make a year.
    public var daysPerSeason: Int = 7

    // MARK: - Offline progress

    /// The world never simulates more than this much real time in one catch-up.
    /// Anything beyond is simply lost (the player is told, gently).
    public var offlineCatchUpCap: TimeInterval = 3 * 24 * 60 * 60

    /// Absences at least this long start a fresh morning (06:00 of the next
    /// day). Shorter absences leave the calendar exactly where it was.
    /// See `OfflineCatchUp` for the full rules.
    public var offlineNewDayThreshold: TimeInterval = 60 * 60

    /// Only show the "While you were away" screen after at least this long.
    public var welcomeBackMinimumAway: TimeInterval = 60

    /// Largest single simulation step. Long advances are split into steps of
    /// at most this size so ordering effects (e.g. which barn fills storage
    /// first) stay correct during fast-forward. 3 days ≈ 4,300 steps.
    public var simulationMaxStep: TimeInterval = 60

    // MARK: - Farming

    /// Growth speed of crops in dry soil, relative to watered soil. Crops never
    /// stop growing (the world keeps living), but watering doubles the pace.
    public var dryGrowthRate: Double = 0.5

    /// How long soil stays wet after watering (real seconds; 20 min = one
    /// in-game day of play).
    public var soilWetDuration: TimeInterval = 20 * 60

    /// Items the farm can store (seeds don't count). Harvesting stops when full.
    public var storageCapacity: Int = 100

    /// What's in the seed pouch at the start of a new game.
    public var startingItems: [String: Int] = ["seeds_wheat": 12, "seeds_carrot": 8, "seeds_potato": 4]

    // MARK: - Progression

    /// Experience needed to go from `level` to `level + 1`.
    public func xpToNextLevel(from level: Int) -> Int {
        let l = Double(max(1, level) - 1)
        return 20 + Int((25 * pow(l, 1.5)).rounded())
    }

    // MARK: - Economy

    /// Coins in the pocket at the start of a new game.
    public var startingMoney: Int = 500

    // MARK: - Saving

    /// Seconds between autosaves while playing. The game also saves whenever
    /// it goes to the background.
    public var autosaveInterval: TimeInterval = 30

    // MARK: - Derived helpers

    /// In-game minutes that pass per real second while playing (1.2 by default).
    public var gameMinutesPerRealSecond: Double {
        GameClock.minutesPerDay / realSecondsPerGameDay
    }

    public init() {}

    /// The shipping balance.
    public static let standard = Balance()
}
