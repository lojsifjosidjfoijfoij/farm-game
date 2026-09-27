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
