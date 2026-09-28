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

    /// Real seconds for one game day while playing: 24 minutes, so one game
    /// minute passes per real second (Big Ambitions pace). The clock drives
    /// the day and night, opening hours, sleep and the weekly rhythm.
    public var realSecondsPerGameDay: Double = GameTime.day

    /// Days per season: one week (7 × 24 min ≈ 2 h 50 min of play).
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

    /// How long soil stays wet after watering: a day, so you water once a day.
    public var soilWetDuration: TimeInterval = GameTime.day

    /// Items the farm can store (seeds and saplings don't count). Harvesting,
    /// collecting and chopping stop when full.
    public var storageCapacity: Int = 300

    /// What's in the seed pouch at the start of a new game.
    public var startingItems: [String: Int] = ["seeds_wheat": 12, "seeds_carrot": 8, "seeds_potato": 4]

    // MARK: - Animals (Phase 4)

    /// How long a filled water trough lasts: a day.
    public var troughWaterDuration: TimeInterval = GameTime.day

    /// Production speed of animals with an empty trough, relative to a full one.
    public var dryProductionRate: Double = 0.5

    /// Happiness gained per feeding with water in the trough (half when dry).
    public var happinessPerFeeding: Double = 0.2

    /// Happiness lost per game day while an adult animal waits to be fed.
    public var happinessDecayPerDay: Double = 0.3

    /// Happiness of a newly bought young animal.
    public var newAnimalHappiness: Double = 0.5

    /// Price of one sack of animal feed at the livestock market.
    public var feedPrice: Int = 6

    // MARK: - Trees (Phase 4)

    /// Time before a stump sprouts again into a sapling of the same kind.
    public var stumpRegrowSeconds: TimeInterval = GameTime.days(4)

    /// Experience for clearing away a stump.
    public var stumpRemovalXP: Int = 1

    // MARK: - The farmer (Phase 5)

    /// Full energy after a good night's sleep.
    public var energyMax: Double = 100

    /// Energy lost per game hour awake (a 16-hour day costs 24).
    public var energyDrainPerHour: Double = 1.5

    /// Energy gained per game hour of sleep (8 hours fills you up).
    public var energyPerSleepHour: Double = 12.5

    /// Energy each job costs.
    public var energyCost = EnergyCosts()

    /// How far the farmer can reach from where they stand (tiles).
    public var workReach: Double = 1.6

    /// Walking speed in tiles per second.
    public var walkSpeed: Double = 2.6

    /// Staying up until this hour, the farmer falls asleep on the spot.
    public var passOutHour: Int = 2

    // MARK: - Business (Phase 6)

    /// Property tax on each property, every Monday.
    public var propertyTaxPerWeek: Int = 100

    /// Orders on the contract board at once, and how many can be taken.
    public var contractOffersOnBoard: Int = 3
    public var maxActiveContracts: Int = 3

    /// Contracts pay this much over market value (plus a little for reputation).
    public var contractBonus: Double = 0.35

    /// Reputation gained per finished contract, lost per missed one.
    public var reputationPerContract: Int = 5
    public var reputationPerFailure: Int = 10

    /// Flat interest on bank loans.
    public var loanInterest: Double = 0.12

    /// The market's special of the day pays this much more.
    public var marketSpecialBonus: Double = 0.5

    // MARK: - Your shop (Phase 7)

    /// Rent for the corner shop, every Monday (the first payment covers the
    /// days until then).
    public var storeRentPerWeek: Int = 250
    public var storeUnlockLevel: Int = 3
    public var storeShelves: Int = 6
    public var storeShelfCapacity: Int = 25

    /// Customers per open hour for one shelf at the usual price, by kind of goods.
    public func storeDemand(_ category: ItemCategory) -> Double {
        switch category {
        case .crop: 1.6
        case .fruit: 1.2
        case .animalProduct: 1.0
        case .wood: 0.5
        case .artisan: 0.8
        case .feed, .seed, .sapling, .machine: 0
        }
    }

    /// How fast demand falls as the price goes up: `exp(-k × (factor - 1))`.
    /// With k = 0.8 the takings per hour peak at 1.25 × the usual price.
    public var storePriceSensitivity: Double = 0.8

    /// Prices are set between these multiples of an item's usual value.
    public var storePriceFactorRange: ClosedRange<Double> = 0.6...2.0

    /// Variety draws a crowd: each different item on the shelves beyond the
    /// first brings this many more customers, up to the maximum.
    public var storeTrafficPerItem: Double = 0.08
    public var storeTrafficMax: Double = 1.4

    // MARK: - Growing the farm (Phase 8)

    /// Farm storage by level (the storage shed, then silos), and what each
    /// next level costs and needs. Level 0 is `storageCapacity` (the first
    /// entry only documents it).
    public var storageLevels: [Int] = [300, 450, 650, 900]
    public var storageUpgradeCosts: [Int] = [1_500, 4_000, 9_000]
    public var storageUpgradeLevels: [Int] = [2, 4, 6]

    /// Truck bed size by level, and the upgrades.
    public var truckBedLevels: [Int] = [60, 90, 130]
    public var truckBedUpgradeCosts: [Int] = [2_000, 6_000]
    public var truckBedUpgradeLevels: [Int] = [3, 6]

    /// Farmhands: wage every Monday (the first one covers the days until
    /// then), the farmer level each hire needs, and how fast they work.
    public var workerWagePerWeek: Int = 350
    public var workerUnlockLevels: [Int] = [4, 6, 8]
    public var workerTasksPerHour: Double = 8
    public var workStartHour: Int = 8
    public var workEndHour: Int = 17

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
    public var truckCargoCapacity: Int = 60

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

/// Energy per job. A day's work on a small farm uses most of a night's sleep.
public struct EnergyCosts: Sendable, Equatable {
    public var plow: Double = 1.5
    public var plant: Double = 0.4
    public var water: Double = 0.4
    public var harvest: Double = 0.5
    public var pen: Double = 1.5
    public var chop: Double = 6
    public var clearStump: Double = 3
    public var pickFruit: Double = 1
    public var plantTree: Double = 1

    public init() {}

    public func cost(of kind: FarmAction.Kind) -> Double {
        switch kind {
        case .plow: plow
        case .plant: plant
        case .water: water
        case .harvest: harvest
        }
    }
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
