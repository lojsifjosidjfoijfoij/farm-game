import Foundation

/// What happened while the player was away. Drives the "While you were away" screen.
public struct OfflineReport: Equatable, Sendable {
    /// Wall-clock time between the last save and now (never negative).
    public var awayDuration: TimeInterval
    /// How much of that was actually simulated (capped).
    public var simulatedDuration: TimeInterval
    /// True if the absence exceeded `Balance.offlineCatchUpCap`.
    public var wasCapped: Bool
    /// True if the device clock appears to have been set backwards.
    public var clockWentBackwards: Bool
    /// True if the player "slept" and a fresh morning began.
    public var startedNewDay: Bool
    public var dateBefore: CalendarDate
    public var dateAfter: CalendarDate
    public var events: [SimEvent]

    /// Whether the absence is long enough to be worth a welcome-back screen.
    public func isWorthShowing(balance: Balance) -> Bool {
        awayDuration >= balance.welcomeBackMinimumAway || clockWentBackwards
    }
}

/// Applies the passage of real time while the game was closed.
///
/// The rules (agreed design, "two clocks"):
/// 1. **Growth runs on real time.** Everything with a duration (crops, animal
///    products, trees, machines, workers) is simulated for the full real
///    absence, up to `Balance.offlineCatchUpCap` (3 days). Beyond the cap,
///    time is simply not simulated.
/// 2. **The calendar does not run offline.** A short absence (under
///    `Balance.offlineNewDayThreshold`) leaves the time of day unchanged.
/// 3. **A long absence starts a new morning.** The player wakes at 06:00 of
///    the next game day — at most one day is skipped, so seasons pass through
///    play, not wall-clock time, and day-based deadlines stay fair.
/// 4. **Clock tampering is harmless.** If the device clock went backwards the
///    elapsed time is treated as zero; forwards is bounded by the cap.
public enum OfflineCatchUp {

    public static func run(
        _ simulation: inout Simulation,
        lastSeen: Date,
        now: Date
    ) -> OfflineReport {
        let balance = simulation.balance
        let rawElapsed = now.timeIntervalSince(lastSeen)
        let clockWentBackwards = rawElapsed < -1  // tolerate sub-second jitter
        let away = max(0, rawElapsed.isFinite ? rawElapsed : 0)
        let simulated = min(away, balance.offlineCatchUpCap)
        let dateBefore = simulation.state.clock.date(daysPerSeason: balance.daysPerSeason)

        var events = simulation.advance(by: simulated, mode: .offline)

        let startsNewDay = away >= balance.offlineNewDayThreshold
        if startsNewDay {
            events += simulation.startNextMorning()
            // Time away is time asleep: the farmer wakes rested, at home.
            let energy = balance.energyMax
            simulation.modify { state in
                state.farmer.energy = energy
                if !state.farmer.inTruck { state.farmer.position = HomeValleyMap.farmhouseDoor }
            }
        }
        if away >= balance.welcomeBackMinimumAway {
            simulation.modify { $0.stats.returns += 1 }
        }

        return OfflineReport(
            awayDuration: away,
            simulatedDuration: simulated,
            wasCapped: away > balance.offlineCatchUpCap,
            clockWentBackwards: clockWentBackwards,
            startedNewDay: startsNewDay,
            dateBefore: dateBefore,
            dateAfter: simulation.state.clock.date(daysPerSeason: balance.daysPerSeason),
            events: events
        )
    }
}
