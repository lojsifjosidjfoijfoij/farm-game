import Foundation
import AcresCore

/// A coin change floating up from the money counter.
struct MoneyFloat: Identifiable, Equatable {
    let id: UUID
    let amount: Int
}

/// "Level 5!" and what it opens up.
struct LevelUpCard: Identifiable, Equatable {
    let level: Int
    let unlocks: [String]
    var id: Int { level }
}

/// One step on the level roadmap.
struct RoadmapStep: Identifiable {
    let level: Int
    let unlocks: [String]
    var id: Int { level }
}

extension GameController {
    func addMoneyFloat(_ delta: Int) {
        guard delta != 0 else { return }
        let float = MoneyFloat(id: UUID(), amount: delta)
        moneyFloats.append(float)
        moneyFloatTimers[float.id] = 1.4
        if moneyFloats.count > 3 {
            let dropped = moneyFloats.removeFirst()
            moneyFloatTimers[dropped.id] = nil
        }
    }

    func tickMoneyFloats(_ dt: TimeInterval) {
        var expired: [UUID] = []
        for (id, left) in moneyFloatTimers {
            if left - dt <= 0 { expired.append(id) } else { moneyFloatTimers[id] = left - dt }
        }
        guard !expired.isEmpty else { return }
        for id in expired { moneyFloatTimers[id] = nil }
        moneyFloats.removeAll { expired.contains($0.id) }
    }

    func dismissLevelUp() {
        levelUpCard = nil
    }

    /// The next levels and what each one opens up (skipping empty ones).
    var roadmap: [RoadmapStep] {
        (level + 1...level + 12).compactMap { next in
            let unlocks = Self.unlocks(at: next, balance: balance)
            return unlocks.isEmpty ? nil : RoadmapStep(level: next, unlocks: unlocks)
        }
    }

    /// Experience still needed for the next level.
    var xpToNextLevel: Int {
        let progress = simulation.state.progress
        return max(0, balance.xpToNextLevel(from: progress.level) - progress.xp)
    }
}
