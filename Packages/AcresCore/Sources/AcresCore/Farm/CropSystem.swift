import Foundation

/// Grows every planted crop. Growth runs on real time, online and offline:
/// full speed while the soil is wet, `Balance.dryGrowthRate` when dry.
/// Ripe crops simply wait; they never rot.
///
/// Exact for any step size: the wet part of a step is computed from
/// `wetUntil`, so a 3-day catch-up gives the same result as 60 fps play.
public struct CropSystem: SimulationSystem {
    public init() {}

    /// Growth is integrated exactly, so one call can cover a whole 3-day catch-up.
    public var handlesAnyStepSize: Bool { true }

    public func step(_ state: inout GameState, _ context: inout StepContext) {
        guard !state.plots.isEmpty else { return }
        let start = state.worldTime
        let dt = context.dt
        let dryRate = context.balance.dryGrowthRate
        var ripened: [(TileCoord, String)] = []

        state.plots.updateEach { plot in
            guard var crop = plot.crop, let def = CropCatalog.crop(crop.cropID),
                  crop.growth < def.growthSeconds else { return }
            let wetTime = min(max(plot.wetUntil - start, 0), dt)
            let gain = wetTime + (dt - wetTime) * dryRate
            crop.growth = min(def.growthSeconds, crop.growth + gain)
            crop.wateredGrowth += min(wetTime, gain)
            if crop.growth >= def.growthSeconds {
                ripened.append((plot.tile, def.id))
            }
            plot.crop = crop
        }

        guard !ripened.isEmpty else { return }
        // Dictionary order is random per launch; sort so events are deterministic.
        ripened.sort { $0.0.y != $1.0.y ? $0.0.y > $1.0.y : $0.0.x < $1.0.x }
        context.events += ripened.map { SimEvent.cropReady($0.0, cropID: $0.1) }
    }
}
