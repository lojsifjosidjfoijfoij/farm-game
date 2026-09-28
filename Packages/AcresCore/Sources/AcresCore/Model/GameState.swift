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

    /// How far the new-player tutorial has come. (v3)
    public var tutorial: TutorialState

    /// Pens and the animals living in them. (v4)
    public var ranch: Ranch

    /// Trees the player planted, chopped or cleared. (v4)
    public var woodland: Woodland

    /// The farmer: where they are, how rested, whether they're driving. (v5)
    public var farmer: FarmerState

    /// Progress toward goals, and which rewards were claimed. (v5)
    public var goals: GoalState

    /// Orders from clients: on offer and accepted, plus reputation. (v6)
    public var contracts: ContractBoard

    /// The books: weekly ledger and any bank loan. (v6)
    public var finance: Finance

    /// The corner shop, once rented: shelves, prices and takings. (v7)
    public var store: StoreState

    /// Upgrades, machines and farmhands. (v8)
    public var estate: EstateState

    /// Today's chores, the streak and the market special. (v9)
    public var daily: DailyState

    /// Today's wild finds already picked. (v11)
    public var forage: ForageState

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
        ownedProperties: [String] = [PropertyCatalog.homeFarm.id],
        tutorial: TutorialState = .new,
        ranch: Ranch = Ranch(),
        woodland: Woodland = Woodland(),
        farmer: FarmerState = FarmerState(),
        goals: GoalState = GoalState(),
        contracts: ContractBoard = ContractBoard(),
        finance: Finance = Finance(),
        store: StoreState = StoreState(),
        estate: EstateState = EstateState(),
        daily: DailyState = DailyState(),
        forage: ForageState = ForageState()
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
        self.tutorial = tutorial
        self.ranch = ranch
        self.woodland = woodland
        self.farmer = farmer
        self.goals = goals
        self.contracts = contracts
        self.finance = finance
        self.store = store
        self.estate = estate
        self.daily = daily
        self.forage = forage
    }

    /// Where the farmer is: in the truck, or on foot.
    public var farmerPosition: Vec2 { farmer.inTruck ? truck.position : farmer.position }

    /// A brand-new game: Year 1, Spring 1, 06:00, a little money, a few seeds and an old truck.
    public static func newGame(seed: UInt64, balance: Balance = .standard) -> GameState {
        GameState(
            worldTime: 0,
            clock: GameClock(totalMinutes: 0),
            money: balance.startingMoney,
            progress: FarmerProgress(level: 1, xp: 0),
            truck: TruckState(position: HomeValleyMap.truckParkingSpot, heading: .pi, fuel: balance.driving.fuelCapacity),
            rng: SeededRandom(seed: seed),
            stats: PlayStats(),
            plots: FarmPlots(),
            inventory: Inventory(items: balance.startingItems),
            ownedProperties: [PropertyCatalog.homeFarm.id],
            tutorial: .new,
            ranch: Ranch(),
            woodland: Woodland(),
            farmer: FarmerState(position: HomeValleyMap.farmhouseDoor, energy: balance.energyMax),
            goals: GoalState(),
            contracts: ContractBoard(),
            finance: Finance(),
            store: StoreState(),
            estate: EstateState(),
            daily: DailyState(),
            forage: ForageState()
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

/// The player's truck: where it is, which way it faces, fuel and cargo.
public struct TruckState: Codable, Equatable, Sendable {
    /// Position in tile units.
    public var position: Vec2
    /// Heading in radians, 0 = east, counter-clockwise (π = west).
    public var heading: Double
    /// Fuel units left. (v3)
    public var fuel: Double
    /// Goods loaded in the bed, to sell at markets. (v3)
    public var cargo: Inventory

    public init(position: Vec2, heading: Double, fuel: Double = 100, cargo: Inventory = Inventory()) {
        self.position = position
        self.heading = heading
        self.fuel = fuel
        self.cargo = cargo
    }

    /// Items in the bed.
    public var cargoCount: Int { cargo.items.values.reduce(0, +) }
}

/// The farmer. On foot they walk to jobs; in the truck they drive.
public struct FarmerState: Codable, Equatable, Sendable {
    /// Where they stand (tile units). Ignored while in the truck.
    public var position: Vec2
    /// 0…`Balance.energyMax`. Work and hours awake use it up; sleep refills it.
    public var energy: Double
    public var inTruck: Bool

    public init(position: Vec2 = HomeValleyMap.farmhouseDoor, energy: Double = 100, inTruck: Bool = false) {
        self.position = position
        self.energy = energy
        self.inTruck = inTruck
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
