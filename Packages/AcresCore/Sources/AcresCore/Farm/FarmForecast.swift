import Foundation

/// Predicts when crops will be ready, assuming nobody waters them again.
/// Used for tile info, "while you were away" and harvest reminders.
public enum FarmForecast {

    /// Real seconds until the crop in `plot` is ripe (0 if ripe, nil if no crop).
    public static func secondsUntilReady(_ plot: Plot, now: TimeInterval, balance: Balance) -> TimeInterval? {
        guard let crop = plot.crop, let def = crop.definition else { return nil }
        let remaining = def.growthSeconds - crop.growth
        guard remaining > 0 else { return 0 }
        let wetLeft = max(0, plot.wetUntil - now)
        if remaining <= wetLeft { return remaining }
        guard balance.dryGrowthRate > 0 else { return .infinity }
        return wetLeft + (remaining - wetLeft) / balance.dryGrowthRate
    }

    /// Seconds until every growing crop is ripe (nil if nothing is growing).
    public static func secondsUntilAllReady(_ state: GameState, balance: Balance) -> TimeInterval? {
        state.plots.byTile.values
            .compactMap { secondsUntilReady($0, now: state.worldTime, balance: balance) }
            .filter { $0 > 0 }
            .max()
    }

    /// Per-crop overview of the farm right now.
    public struct CropStatus: Equatable, Sendable {
        public var cropID: String
        public var ready: Int
        public var growing: Int
        /// Growing crops in dry soil.
        public var thirsty: Int
        /// Seconds until the last growing one ripens (0 if none growing).
        public var secondsUntilAllReady: TimeInterval
    }

    /// Status per crop, in catalog order.
    public static func status(_ state: GameState, balance: Balance) -> [CropStatus] {
        var byCrop: [String: CropStatus] = [:]
        for plot in state.plots.byTile.values {
            guard let crop = plot.crop else { continue }
            var entry = byCrop[crop.cropID] ?? CropStatus(cropID: crop.cropID, ready: 0, growing: 0, thirsty: 0, secondsUntilAllReady: 0)
            if crop.isReady {
                entry.ready += 1
            } else {
                entry.growing += 1
                if !plot.isWet(at: state.worldTime) { entry.thirsty += 1 }
                let eta = secondsUntilReady(plot, now: state.worldTime, balance: balance) ?? 0
                entry.secondsUntilAllReady = max(entry.secondsUntilAllReady, eta)
            }
            byCrop[crop.cropID] = entry
        }
        return CropCatalog.all.compactMap { byCrop[$0.id] }
    }
}
