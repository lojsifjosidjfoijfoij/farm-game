import Foundation

/// The complete simulated state of one farm. Pure value type, fully Codable.
///
/// SAVE COMPATIBILITY RULES (read before changing anything in here):
/// 1. Any change to a stored property of GameState or its nested types is a
///    save-format change: bump `SaveFile.currentVersion` and add a migration
///    in `SaveMigrator.standard`, plus a fixture test for the old version.
/// 2. Never store derived values (e.g. "crop is ready"); store the inputs
///    (planted at, growth duration) and derive at read time.
/// 3. Timestamps are `worldTime` seconds, never wall-clock `Date`s, so the
///    simulation is deterministic and immune to the device clock changing.
public struct GameState: Codable, Equatable, Sendable {

    /// Real-time seconds this world has been simulated for (online + offline).
    /// This is the timeline all growth and production runs on.
    public var worldTime: TimeInterval

    /// The in-game calendar (runs only while playing; see `OfflineCatchUp`).
    public var clock: GameClock

    /// Coins.
    public var money: Int

    public var progress: FarmerProgress

    /// The player's truck. Its location decides which property the player can
    /// interact with ("you farm where your truck is parked").
    public var truck: TruckState

    /// Source of all simulation randomness.
    public var rng: SeededRandom

    public var stats: PlayStats

    /// Tilled farmland and the crops growing in it. (v2)
    public var plots: FarmPlots

    /// Farm storage plus the seed pouch. (v2)
    public var inventory: Inventory

    /// IDs from `PropertyCatalog` the player owns, sorted. (v2)
    public var ownedProperties: [String]

    public init(
        worldTime: TimeInterval,
        clock: GameClock,
        money: Int,
        progress: FarmerProgress,
        truck: TruckState,
        rng: SeededRandom,
        stats: PlayStats,
        plots: FarmPlots = FarmPlots(),
        inventory: Inventory = Inventory(),
        ownedProperties: [String] = [PropertyCatalog.homeFarm.id]
    ) {
        self.worldTime = worldTime
        self.clock = clock
        self.money = money
        self.progress = progress
        self.truck = truck
        self.rng = rng
        self.stats = stats
        self.plots = plots
        self.inventory = inventory
        self.ownedProperties = ownedProperties
    }

    /// A brand-new game: Year 1, Spring 1, 06:00, a little money, a few seeds and an old truck.
    public static func newGame(seed: UInt64, balance: Balance = .standard) -> GameState {
        GameState(
            worldTime: 0,
            clock: GameClock(totalMinutes: 0),
            money: balance.startingMoney,
            progress: FarmerProgress(level: 1, xp: 0),
            truck: TruckState(position: HomeValleyMap.truckParkingSpot, heading: .pi),
            rng: SeededRandom(seed: seed),
            stats: PlayStats(),
            plots: FarmPlots(),
            inventory: Inventory(items: balance.startingItems),
            ownedProperties: [PropertyCatalog.homeFarm.id]
        )
    }
}

/// Farmer level and experience. (Levels and unlocks arrive in Phase 7.)
public struct FarmerProgress: Codable, Equatable, Sendable {
    public var level: Int
    public var xp: Int

    public init(level: Int, xp: Int) {
        self.level = level
        self.xp = xp
    }
}

/// Where the truck is and which way it faces.
public struct TruckState: Codable, Equatable, Sendable {
    /// Position in tile units.
    public var position: Vec2
    /// Heading in radians, 0 = east, counter-clockwise (π = west).
    public var heading: Double

    public init(position: Vec2, heading: Double) {
        self.position = position
        self.heading = heading
    }
}

/// Lifetime statistics, handy for achievements and for debugging saves.
public struct PlayStats: Codable, Equatable, Sendable {
    /// Real seconds spent with the game open.
    public var playSeconds: TimeInterval = 0
    /// Real seconds simulated while the game was closed.
    public var offlineSeconds: TimeInterval = 0
    /// Number of times the player came back after an absence.
    public var returns: Int = 0

    public init(playSeconds: TimeInterval = 0, offlineSeconds: TimeInterval = 0, returns: Int = 0) {
        self.playSeconds = playSeconds
        self.offlineSeconds = offlineSeconds
        self.returns = returns
    }
}
