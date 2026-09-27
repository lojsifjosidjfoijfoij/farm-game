import SwiftUI
import AcresCore

/// The goal ladder: what to aim for next, how far along you are, and the
/// rewards waiting to be claimed.
struct GoalsView: View {
    let game: GameController

    var body: some View {
        NavigationStack {
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
            .background(Theme.parchment)
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { game.showsGoals = false }
                }
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
                    Label("\(game.dailyState.streak)-day streak", systemImage: "flame.fill")
                        .font(Theme.label(13, weight: .bold))
                        .foregroundStyle(Color(red: 0.9, green: 0.45, blue: 0.2))
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
                Image(systemName: game.dailyState.bonusClaimed ? "checkmark.seal.fill" : "gift.fill")
                    .foregroundStyle(Theme.gold)
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
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.gold.opacity(0.6), lineWidth: 1.5))
        }
    }

    private func choreRow(_ chore: ChoreProgress) -> some View {
        HStack(spacing: 10) {
            Image(systemName: chore.chore.claimed ? "checkmark.circle.fill" : (chore.isDone ? "star.circle.fill" : "circle"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(chore.chore.claimed ? Theme.leaf : (chore.isDone ? Theme.gold : Theme.inkSoft))
            VStack(alignment: .leading, spacing: 4) {
                Text(chore.chore.title)
                    .font(Theme.label(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .strikethrough(chore.chore.claimed)
                if !chore.isDone {
                    ProgressView(value: chore.fraction)
                        .tint(Theme.leaf)
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
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.parchmentDark.opacity(0.55)))
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
                    Label("Claim reward", systemImage: "gift.fill")
                        .font(Theme.label(16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.gold))
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 8) {
                    ProgressView(value: goal.fraction)
                        .tint(Theme.leaf)
                    Text("\(goal.current)/\(goal.target)")
                        .font(Theme.number(13))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.parchmentDark.opacity(0.55)))
    }
}
