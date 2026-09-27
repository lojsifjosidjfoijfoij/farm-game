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

    /// Real seconds for one full day/night lighting cycle while playing.
    /// There is no clock to follow: days only drive the lighting, daily
    /// market prices and seasons.
    public var realSecondsPerGameDay: Double = 16 * 60

    /// Days per season (4 × 16 min ≈ one hour of play per season).
    public var daysPerSeason: Int = 4

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

    /// How long soil stays wet after watering (real seconds).
    public var soilWetDuration: TimeInterval = 10 * 60

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

    /// Items the truck bed holds.
    public var truckCargoCapacity: Int = 30

    /// Coins per unit of fuel (a full tank of 100 costs 50).
    public var fuelPrice: Double = 0.5

    // MARK: - Driving

    public var driving = DrivingTuning()

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

/// Feel of the truck. Speeds are in tiles per second.
public struct DrivingTuning: Sendable, Equatable {
    public var maxSpeedAsphalt: Double = 7.5
    public var maxSpeedGravel: Double = 6.2
    public var maxSpeedDirt: Double = 5.2
    public var maxSpeedGrass: Double = 4.2
    public var acceleration: Double = 6
    public var braking: Double = 10
    /// Deceleration when the stick is released.
    public var coastDrag: Double = 7
    /// Radians per second at speed (a bit slower when nearly stopped).
    public var turnRate: Double = 3.6
    /// How quickly the velocity follows the nose: lower = more drift.
    public var gripAsphalt: Double = 14
    public var gripGravel: Double = 5.5
    public var gripDirt: Double = 5
    public var gripGrass: Double = 7
    public var fuelCapacity: Double = 100
    /// Fuel used per tile driven (a full tank lasts ~1,000 tiles).
    public var fuelPerTile: Double = 0.1
    /// Out of fuel the truck limps along instead of stopping. Never punishing.
    public var outOfFuelSpeedFactor: Double = 0.35
    /// Radius of the truck's collision circle, in tiles.
    public var collisionRadius: Double = 0.45

    public init() {}

    public func maxSpeed(on terrain: Terrain) -> Double {
        switch terrain {
        case .asphalt: maxSpeedAsphalt
        case .gravel: maxSpeedGravel
        case .dirt: maxSpeedDirt
        case .grass: maxSpeedGrass
        }
    }

    public func grip(on terrain: Terrain) -> Double {
        switch terrain {
        case .asphalt: gripAsphalt
        case .gravel: gripGravel
        case .dirt: gripDirt
        case .grass: gripGrass
        }
    }
}
