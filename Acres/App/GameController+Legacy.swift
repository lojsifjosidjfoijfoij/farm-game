import Foundation
import AcresCore

/// A new farm rank to celebrate (the last one is the finale).
struct RankUpCard: Identifiable, Equatable {
    let rank: FarmRank
    /// The farmhouse was renovated with this rank.
    let renovated: Bool
    var id: Int { rank.id }
    var isFinale: Bool { rank.id == FarmRanks.finale.id }
}

/// The farm's story in numbers (for the finale card and the almanac).
struct FarmStats: Equatable {
    let days: Int
    let level: Int
    let netWorth: Int
    let harvested: Int
    let fishCaught: Int
    let foraged: Int
    let crafted: Int
    let ordersDone: Int
    let coinsEarned: Int
    let almanac: Double
    let bestStreak: Int
}

extension GameController {
    var netWorth: Int { NetWorth.of(simulation.state, balance: balance) }
    var farmRank: FarmRank { FarmRanks.rank(rankIndex) }
    var nextFarmRank: FarmRank? { FarmRanks.next(after: rankIndex) }
    var farmhouseTier: Int { farmRank.farmhouseTier }

    var farmStats: FarmStats {
        let state = simulation.state
        let goals = state.goals
        return FarmStats(
            days: state.clock.dayIndex + 1, level: state.progress.level, netWorth: netWorth,
            harvested: goals.count(GoalCounter.harvested), fishCaught: goals.count(GoalCounter.fishCaught),
            foraged: goals.count(GoalCounter.foraged), crafted: goals.count(GoalCounter.crafted),
            ordersDone: goals.count(GoalCounter.contractsCompleted),
            coinsEarned: goals.count(GoalCounter.coinsFromSales) + goals.count(GoalCounter.coinsFromShop),
            almanac: Almanac.completion(state.almanac), bestStreak: state.daily.bestStreak)
    }

    /// The farm moved up: the card (and the farmhouse, which the scene redraws).
    func rankedUp(to index: Int) {
        let rank = FarmRanks.rank(index)
        // (Runs before the copy of the rank is refreshed, so `rankIndex` is still the old one.)
        let renovated = FarmRanks.rank(rankIndex).farmhouseTier < rank.farmhouseTier || (rankUpCard?.renovated ?? false)
        rankIndex = index
        rankUpCard = RankUpCard(rank: rank, renovated: renovated)
        Sound.play(.achievement)
        Haptics.success()
        save()
    }

    func dismissRankUp() {
        rankUpCard = nil
    }

    /// New almanac entries: one line for the lot.
    func discovered(_ items: [String]) {
        if items.count == 1, let item = ItemCatalog.item(items[0]) {
            showMessage("📖 New in your almanac: \(item.name.lowercased())!")
        } else {
            showMessage("📖 \(items.count) new entries in your almanac!")
        }
        Sound.play(.notification, volume: 0.5)
    }

    /// Almanac sets finished but not claimed yet (for the badge on the phone).
    var claimableAlmanacSets: [AlmanacSet] {
        Almanac.sets.filter { !almanac.claimedSets.contains($0.id) && Almanac.isComplete($0, almanac) }
    }

    func claimAlmanacSet(_ id: String) {
        guard let result = simulation.claimAlmanacSet(id), let set = Almanac.set(id) else { return }
        Haptics.success()
        Sound.play(.coins)
        showBanner("\(set.name) complete! +\(result.coins) coins, +\(set.xp) XP")
        handle(result.events)
        refreshBusiness()
        refreshDisplay()
        save()
    }
}
