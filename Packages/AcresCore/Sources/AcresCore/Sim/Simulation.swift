import Foundation

/// Something noteworthy that happened during a simulation step. Collected so
/// the UI can react (sounds, toasts) and so offline catch-up can summarise
/// what happened while the player was away.
public enum SimEvent: Equatable, Sendable {
    /// A new game day began (at 06:00).
    case newDay(CalendarDate)
    /// A new season began. Always accompanied by a `.newDay`.
    case newSeason(Season, year: Int)
    /// A crop finished growing and is waiting to be harvested.
    case cropReady(TileCoord, cropID: String)
    /// The farmer reached a new level.
    case levelUp(Int)
    /// A young animal grew up (and is now hungry).
    case animalGrewUp(penID: String, animalID: Int)
    /// An animal's product (egg, milk, …) is ready to collect.
    case animalProductReady(penID: String, animalID: Int)
    /// A planted or regrowing tree reached full size.
    case treeGrown(TileCoord)
    /// A fruit tree has fruit to pick.
    case fruitReady(TileCoord)
    /// An accepted contract ran past its deadline.
    case contractFailed(id: Int, clientID: String)
    /// Monday morning: the week's bills were paid.
    case weeklyBills(week: Int, total: Int)
    /// A shelf in your shop sold its last item.
    case shelfSoldOut(itemID: String)
}

/// How a stretch of time is being simulated.
public enum AdvanceMode: Sendable {
    /// The game is open and being played: the calendar runs.
    case live
    /// Catching up on time the game was closed: real-time processes (growth,
    /// production) run, but the calendar is frozen. `OfflineCatchUp` decides
    /// separately whether a new morning begins.
    case offline
}

/// Per-step information handed to each system.
public struct StepContext {
    /// Real seconds covered by this step (≤ `Balance.simulationMaxStep`).
    public let dt: TimeInterval
    public let mode: AdvanceMode
    public let balance: Balance
    /// Events raised during this step, in order.
    public var events: [SimEvent] = []

    public init(dt: TimeInterval, mode: AdvanceMode, balance: Balance) {
        self.dt = dt
        self.mode = mode
        self.balance = balance
    }
}

/// One slice of game logic (clock, crops, animals, machines, …).
///
/// Contract: `step` must behave correctly for any `dt` up to
/// `Balance.simulationMaxStep`, and advancing in many small steps must give
/// the same result as advancing in fewer large ones (tests enforce this).
public protocol SimulationSystem: Sendable {
    /// True if `step` is exact for *any* `dt` and doesn't interact with other
    /// systems. Such systems get one call for the whole span instead of one
    /// per fixed step, which keeps long catch-ups cheap.
    var handlesAnyStepSize: Bool { get }
    func step(_ state: inout GameState, _ context: inout StepContext)
}

extension SimulationSystem {
    public var handlesAnyStepSize: Bool { false }
}

/// Owns the game state and advances it through time.
///
/// The same code path runs a 16 ms frame and a 3-day offline catch-up:
/// long advances are chopped into fixed-size steps.
public struct Simulation: Sendable {
    public private(set) var state: GameState
    public let balance: Balance
    private let systems: [any SimulationSystem]

    /// Systems in the order they run each step.
    public static let defaultSystems: [any SimulationSystem] = [
        CropSystem(),
        AnimalSystem(),
        TreeSystem(),
        FarmerSystem(),
        ClockSystem(),
        BusinessSystem(),
        StoreSystem(),
    ]

    public init(
        state: GameState,
        balance: Balance = .standard,
        systems: [any SimulationSystem] = Simulation.defaultSystems
    ) {
        self.state = state
        self.balance = balance
        self.systems = systems
    }

    /// Advances the world by `seconds` of real time. Returns the events raised.
    @discardableResult
    public mutating func advance(by seconds: TimeInterval, mode: AdvanceMode) -> [SimEvent] {
        guard seconds > 0, seconds.isFinite else { return [] }
        var events: [SimEvent] = []

        // Systems that are exact for any step size run once for the whole span.
        var bulkContext = StepContext(dt: seconds, mode: mode, balance: balance)
        for system in systems where system.handlesAnyStepSize {
            system.step(&state, &bulkContext)
        }
        events += bulkContext.events

        var remaining = seconds
        let maxStep = max(balance.simulationMaxStep, 0.001)
        while remaining > 1e-9 {
            let dt = min(remaining, maxStep)
            var context = StepContext(dt: dt, mode: mode, balance: balance)
            for system in systems where !system.handlesAnyStepSize {
                system.step(&state, &context)
            }
            state.worldTime += dt
            switch mode {
            case .live: state.stats.playSeconds += dt
            case .offline: state.stats.offlineSeconds += dt
            }
            events.append(contentsOf: context.events)
            remaining -= dt
        }
        return events
    }

    /// Starts the next game day at 06:00 (used after a long absence).
    @discardableResult
    public mutating func startNextMorning() -> [SimEvent] {
        let before = state.clock
        state.clock.jumpToNextMorning()
        return ClockSystem.transitions(from: before, to: state.clock, balance: balance)
    }

    /// Performs a farming action (plow, plant, water, harvest) on a tile.
    public mutating func perform(_ action: FarmAction, at tile: TileCoord, on map: WorldMap) -> FarmResult {
        Farming(map: map, balance: balance).perform(action, at: tile, in: &state)
    }

    /// Looks after a pen (repair, collect, water, feed).
    public mutating func perform(_ action: PenAction, on pen: PenDefinition) -> RanchResult {
        Ranching(balance: balance).perform(action, on: pen, in: &state)
    }

    /// Works a tree (chop, clear a stump, pick fruit, plant a sapling).
    public mutating func perform(_ action: TreeAction, at tile: TileCoord, on map: WorldMap) -> TreeResult {
        Forestry(map: map, balance: balance).perform(action, at: tile, in: &state)
    }

    /// Runs a trade (buy, sell, refuel, load) against the state; failures leave it unchanged.
    /// (Plain `throws` on purpose: closures don't infer typed throws.)
    public mutating func trade<T>(_ body: (Trading, inout GameState) throws -> T) -> Result<T, TradeFailure> {
        var copy = state
        do {
            let value = try body(Trading(balance: balance), &copy)
            state = copy
            return .success(value)
        } catch let failure as TradeFailure {
            return .failure(failure)
        } catch {
            preconditionFailure("Trading only throws TradeFailure: \(error)")
        }
    }

    /// Direct state access for player actions and debug tools. Keep uses
    /// narrow; gameplay rules belong in systems or dedicated action methods.
    public mutating func modify<T>(_ body: (inout GameState) throws -> T) rethrows -> T {
        try body(&state)
    }
}

/// Runs the in-game calendar while playing and reports day/season changes.
public struct ClockSystem: SimulationSystem {
    public init() {}

    public func step(_ state: inout GameState, _ context: inout StepContext) {
        guard context.mode == .live else { return }
        let before = state.clock
        state.clock.advance(minutes: context.dt * context.balance.gameMinutesPerRealSecond)
        context.events += Self.transitions(from: before, to: state.clock, balance: context.balance)
    }

    /// Events for every day boundary crossed between two clock readings.
    static func transitions(from before: GameClock, to after: GameClock, balance: Balance) -> [SimEvent] {
        guard after.dayIndex > before.dayIndex else { return [] }
        var events: [SimEvent] = []
        for day in (before.dayIndex + 1)...after.dayIndex {
            let date = CalendarDate(dayIndex: day, daysPerSeason: balance.daysPerSeason)
            events.append(.newDay(date))
            if date.dayOfSeason == 1 {
                events.append(.newSeason(date.season, year: date.year))
            }
        }
        return events
    }
}
