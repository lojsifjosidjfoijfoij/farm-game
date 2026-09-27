import Foundation

/// The farmer gets tired while awake (only while playing: time away is
/// spent sleeping, see `OfflineCatchUp`). Linear, so exact for any step size.
public struct FarmerSystem: SimulationSystem {
    public init() {}

    public var handlesAnyStepSize: Bool { true }

    public func step(_ state: inout GameState, _ context: inout StepContext) {
        guard context.mode == .live else { return }
        let hours = context.dt * context.balance.gameMinutesPerRealSecond / 60
        state.farmer.energy = max(0, state.farmer.energy - hours * context.balance.energyDrainPerHour)
    }
}

/// What a night's sleep did.
public struct SleepReport: Equatable, Sendable {
    public var hoursSlept: Double
    public var energyBefore: Double
    public var energyAfter: Double
    /// True if the farmer dropped where they stood instead of going to bed.
    public var passedOut: Bool
    public var events: [SimEvent]
}

extension Simulation {
    /// Sleeps until 06:00: the world runs through the night (crops grow,
    /// animals produce), energy refills, and the farmer wakes at the farmhouse.
    @discardableResult
    public mutating func sleep(passedOut: Bool = false) -> SleepReport {
        let before = state.farmer.energy
        let minutes = state.clock.minutesUntilNextMorning
        let events = advance(by: minutes / balance.gameMinutesPerRealSecond, mode: .live)
        let hours = minutes / 60
        let after = min(balance.energyMax, before + hours * balance.energyPerSleepHour)
        modify { state in
            state.farmer.energy = after
            state.farmer.inTruck = false
            state.farmer.position = HomeValleyMap.farmhouseDoor
            state.goals.add(GoalCounter.slept)
        }
        return SleepReport(hoursSlept: hours, energyBefore: before, energyAfter: after, passedOut: passedOut, events: events)
    }

    /// True between the pass-out hour and dawn: the farmer can't stay up any longer.
    public var isTooLateToStayUp: Bool {
        let hour = state.clock.hour
        return hour >= balance.passOutHour && hour < Int(GameClock.dayStartHour)
    }
}
