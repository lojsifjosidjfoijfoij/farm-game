import Foundation

/// Farmer experience and levels. (Unlocks tied to levels arrive in Phase 7.)
public enum Progression {

    /// Adds experience, levelling up as often as needed. `progress.xp` is the
    /// experience earned *within* the current level.
    public static func addXP(_ amount: Int, to state: inout GameState, balance: Balance) -> [SimEvent] {
        guard amount > 0 else { return [] }
        var events: [SimEvent] = []
        state.progress.xp += amount
        while state.progress.xp >= balance.xpToNextLevel(from: state.progress.level) {
            state.progress.xp -= balance.xpToNextLevel(from: state.progress.level)
            state.progress.level += 1
            events.append(.levelUp(state.progress.level))
        }
        return events
    }

    /// 0…1 progress toward the next level, for the HUD bar.
    public static func levelFraction(_ progress: FarmerProgress, balance: Balance) -> Double {
        let needed = balance.xpToNextLevel(from: progress.level)
        return needed > 0 ? min(1, Double(progress.xp) / Double(needed)) : 0
    }
}
