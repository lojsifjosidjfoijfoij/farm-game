import Foundation
import AcresCore

/// A chore and how far along it is (for the HUD and the goals sheet).
struct ChoreProgress: Equatable, Identifiable {
    let chore: DailyChore
    let current: Int
    var id: String { chore.id }
    var isDone: Bool { current >= chore.target }
    var fraction: Double { Double(current) / Double(max(1, chore.target)) }
}

extension GameController {
    var routine: DailyRoutine { DailyRoutine(balance: balance) }

    /// Copies today's chores and their progress (only when they change).
    func refreshDaily() {
        let state = simulation.state
        if dailyState != state.daily { dailyState = state.daily }
        let chores = state.daily.chores.map { ChoreProgress(chore: $0, current: $0.progress(in: state)) }
        if chores != todaysChores { todaysChores = chores }
    }

    /// A chore or the all-done bonus is waiting to be claimed.
    var choresClaimable: Bool {
        todaysChores.contains { $0.isDone && !$0.chore.claimed } || canClaimDailyBonus
    }

    var canClaimDailyBonus: Bool {
        !dailyState.bonusClaimed && !todaysChores.isEmpty && todaysChores.allSatisfy { $0.chore.claimed }
    }

    var dailyBonus: Int { routine.bonus(simulation.state) }

    func claimChore(_ counter: String) {
        guard let claim = simulation.modify({ routine.claim(counter, state: &$0) }) else { return }
        Haptics.success()
        Sound.play(.coin)
        showMessage("Chore done! +\(claim.coins) coins")
        handle(claim.events)
        afterDaily()
    }

    func claimDailyBonus() {
        guard let coins = simulation.modify({ routine.claimBonus(state: &$0) }) else { return }
        Haptics.success()
        Sound.play(.achievement)
        let streak = dailyState.streak
        showBanner("All of today's chores done! +\(coins) coins" + (streak > 0 ? " · \(streak + 1)-day streak going 🔥" : ""))
        afterDaily()
    }

    private func afterDaily() {
        refreshDisplay()
        refreshDaily()
        save()
    }

    /// "Market special: carrots +50%. Rain today: the fields water themselves."
    var todayNews: String {
        let state = simulation.state
        var parts: [String] = []
        if let special = state.daily.specialItem, let item = ItemCatalog.item(special) {
            parts.append("Market special: \(item.plural) +\(Int((balance.marketSpecialBonus * 100).rounded()))%.")
        }
        switch state.weather(balance) {
        case .rain: parts.append("Rain today: the fields water themselves.")
        case .snow: parts.append("Snow today. 🌨")
        case .cloudy, .sunny: break
        }
        if state.tomorrowsWeather(balance) == .rain { parts.append("Rain is forecast for tomorrow.") }
        return parts.joined(separator: " ")
    }

    static func symbol(for weather: Weather, hour: Int) -> String {
        switch weather {
        case .sunny: hour >= 20 || hour < 6 ? "moon.stars.fill" : "sun.max.fill"
        case .cloudy: "cloud.fill"
        case .rain: "cloud.rain.fill"
        case .snow: "cloud.snow.fill"
        }
    }
}
