import Foundation

/// The content of the "While you were away" screen, as data (the UI picks
/// icons and wording). Built from the offline report plus the farm right now.
public struct AwaySummary: Equatable, Sendable {
    public enum Line: Equatable, Sendable {
        /// The device clock went backwards; nothing was simulated.
        case clockChanged
        case newSeason(Season)
        case newDay(CalendarDate)
        case cropsReady(cropID: String, count: Int)
        case cropsGrowing(cropID: String, count: Int, secondsLeft: TimeInterval)
        case thirstyCrops(count: Int)
        case storageFull(used: Int, capacity: Int)
        /// The absence was longer than the catch-up cap.
        case capped(TimeInterval)
        case nothingNew
    }

    public var awayDuration: TimeInterval
    public var lines: [Line]

    public static func make(report: OfflineReport, state: GameState, balance: Balance) -> AwaySummary {
        var lines: [Line] = []
        if report.clockWentBackwards { lines.append(.clockChanged) }
        for event in report.events {
            if case .newSeason(let season, _) = event { lines.append(.newSeason(season)) }
        }
        if report.startedNewDay { lines.append(.newDay(report.dateAfter)) }

        let status = FarmForecast.status(state, balance: balance)
        for crop in status where crop.ready > 0 {
            lines.append(.cropsReady(cropID: crop.cropID, count: crop.ready))
        }
        for crop in status where crop.growing > 0 {
            lines.append(.cropsGrowing(cropID: crop.cropID, count: crop.growing, secondsLeft: crop.secondsUntilAllReady))
        }
        let thirsty = status.reduce(0) { $0 + $1.thirsty }
        if thirsty > 0 { lines.append(.thirstyCrops(count: thirsty)) }
        let used = state.inventory.storageUsed
        if used >= balance.storageCapacity { lines.append(.storageFull(used: used, capacity: balance.storageCapacity)) }
        if report.wasCapped { lines.append(.capped(balance.offlineCatchUpCap)) }
        if lines.isEmpty { lines.append(.nothingNew) }
        return AwaySummary(awayDuration: report.awayDuration, lines: lines)
    }
}
