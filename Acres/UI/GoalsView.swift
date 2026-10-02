import SwiftUI
import AcresCore

/// The goal ladder: what to aim for next, how far along you are, and the
/// rewards waiting to be claimed.
struct GoalsView: View {
    let game: GameController

    var body: some View {
        MenuSheet(title: "Goals & chores", icon: "ui_icon_goals", onClose: { game.showsGoals = false }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !game.todaysChores.isEmpty {
                        chores
                    }
                    Text("Goals")
                        .font(Theme.title(20))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 4)
                    Text("Finish a goal to earn its reward. New goals open as you go.")
                        .font(Theme.label(14))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(game.openGoals) { goal in
                        row(goal)
                    }
                    if game.openGoals.isEmpty {
                        Text("Every goal is done. More are coming with the next update!")
                            .font(Theme.label(15))
                            .foregroundStyle(Theme.ink)
                    }
                    Text("\(game.claimedGoalCount) of \(GoalCatalog.all.count) goals complete")
                        .font(Theme.label(13))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.top, 6)
                }
                .padding(16)
            }
        }
    }

    // MARK: Today's chores

    private var chores: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's chores")
                    .font(Theme.title(20))
                Spacer()
                if game.dailyState.streak > 0 {
                    PaperTag(text: "\(game.dailyState.streak)-day streak", symbol: "flame.fill",
                             tint: Color(red: 0.75, green: 0.32, blue: 0.1))
                }
            }
            .foregroundStyle(Theme.ink)
            Text("New chores every morning. Do all three for a bonus, and keep the streak going for a bigger one.")
                .font(Theme.label(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(game.todaysChores) { chore in
                choreRow(chore)
            }
            let allClaimed = game.todaysChores.allSatisfy { $0.chore.claimed }
            HStack {
                MenuIcon(symbol: game.dailyState.bonusClaimed ? "checkmark.seal.fill" : "gift.fill")
                Text(game.dailyState.bonusClaimed ? "Bonus claimed. See you tomorrow!" : "All three: bonus \(game.dailyBonus) coins")
                    .font(Theme.label(14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if game.canClaimDailyBonus {
                    ActionCapsule(title: "Claim", enabled: true, tint: Theme.gold) { game.claimDailyBonus() }
                        .pulsing(true)
                } else if !allClaimed {
                    Text("\(game.todaysChores.filter(\.isDone).count)/\(game.todaysChores.count)")
                        .font(Theme.number(13))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .card()
        }
    }

    private func choreRow(_ chore: ChoreProgress) -> some View {
        HStack(spacing: 10) {
            ZStack {
                if chore.chore.claimed {
                    MenuIcon(symbol: "checkmark.circle.fill")
                } else if chore.isDone {
                    MenuIcon(symbol: "star.fill")
                } else {
                    PixelFrame(.slot).frame(width: 20, height: 20)
                }
            }
            .frame(width: HUD.iconSize, height: HUD.iconSize)
            VStack(alignment: .leading, spacing: 4) {
                Text(chore.chore.title)
                    .font(Theme.label(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .strikethrough(chore.chore.claimed)
                if !chore.isDone {
                    HUDBar(fraction: chore.fraction)
                        .frame(height: 10)
                }
            }
            Spacer()
            if chore.isDone && !chore.chore.claimed {
                ActionCapsule(title: "+\(chore.chore.coins)", enabled: true, tint: Theme.gold) { game.claimChore(chore.chore.counter) }
            } else {
                Text(chore.chore.claimed ? "+\(chore.chore.coins)" : "\(chore.current)/\(chore.chore.target)")
                    .font(Theme.number(13))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .card()
    }

    private func row(_ goal: GoalProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(goal.goal.title)
                    .font(Theme.title(18))
                    .foregroundStyle(Theme.ink)
                Spacer()
                HStack(spacing: 4) {
                    CoinIcon(size: 14)
                    Text("\(goal.goal.coins)")
                        .font(Theme.number(14))
                        .foregroundStyle(Theme.ink)
                }
            }
            Text(goal.goal.detail)
                .font(Theme.label(14))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if goal.isComplete {
                Button {
                    game.claimGoal(goal.id)
                } label: {
                    IconLabel("Claim reward", symbol: "gift.fill")
                        .font(Theme.display(16))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CandyButtonStyle(tint: .gold))
            } else {
                HStack(spacing: 8) {
                    HUDBar(fraction: goal.fraction)
                        .frame(height: 10)
                    Text("\(goal.current)/\(goal.target)")
                        .font(Theme.number(13))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .card()
    }
}
