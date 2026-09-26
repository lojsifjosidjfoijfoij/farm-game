import Foundation

/// Something noteworthy that happened during a simulation step. Collected so
/// the UI can react (sounds, toasts) and so offline catch-up can summarise
/// what happened while the player was away.
public enum SimEvent: Equatable, Sendable {
    /// A new game day began (at 06:00).
    case newDay(CalendarDate)
    /// A new season began. Always accompanied by a `.newDay`.
    case newSeason(Season, year: Int)
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
    func step(_ state: inout GameState, _ context: inout StepContext)
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
        ClockSystem(),
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
        var remaining = seconds
        let maxStep = max(balance.simulationMaxStep, 0.001)
        while remaining > 1e-9 {
            let dt = min(remaining, maxStep)
            var context = StepContext(dt: dt, mode: mode, balance: balance)
            for system in systems {
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
