import SwiftUI
import AcresCore

/// The farm journal's Village tab: projects the farm can pay for, a bit at a
/// time. Each one lasts and gives the farm a perk.
struct VillageTabView: View {
    let game: GameController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaperNote(symbol: "building.columns.fill",
                      text: "The village has plans it can't pay for alone. Give coins and goods when you can spare them: "
                        + "each finished project helps the whole valley, and your farm with it.")
            ForEach(game.villageProjects) { project in
                card(project)
            }
        }
    }

    @ViewBuilder
    private func card(_ project: VillageProject) -> some View {
        let finished = game.village.finished.contains(project.id)
        let locked = game.level < project.unlockLevel
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                MenuIcon(symbol: finished ? "checkmark.seal.fill" : (locked ? "lock.fill" : "hammer.fill"), size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(project.name)
                        .font(Theme.title(19))
                    if locked {
                        Text("From level \(project.unlockLevel)")
                            .font(Theme.label(12, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Spacer()
                if finished { PaperTag(text: "Done", symbol: "checkmark.circle.fill", tint: Theme.leaf) }
            }
            Text(project.blurb)
                .font(Theme.label(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            IconLabel(project.reward, symbol: "gift.fill")
                .font(Theme.label(13, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            if !finished && !locked {
                progress(project)
            }
        }
        .foregroundStyle(Theme.ink)
        .card()
        .opacity(locked ? 0.7 : 1)
    }

    @ViewBuilder
    private func progress(_ project: VillageProject) -> some View {
        HUDBar(fraction: game.villageFraction(project), color: HUD.gold)
            .frame(height: 12)
        let coinsLeft = game.villageCoinsNeeded(project)
        HStack {
            CoinIcon(size: 20)
            Text(coinsLeft == 0 ? "Coins: all given" : "\(coinsLeft.formatted()) coins to go")
                .font(Theme.label(14, weight: .semibold))
            Spacer()
        }
        if coinsLeft > 0 {
            HStack(spacing: 8) {
                ForEach(chunks(coinsLeft), id: \.self) { amount in
                    Button {
                        game.giveToVillage(project.id, coins: amount)
                    } label: {
                        Text(amount == coinsLeft ? "All \(amount.formatted())" : amount.formatted())
                            .font(Theme.display(14))
                    }
                    .buttonStyle(CandyButtonStyle(tint: .gold))
                    .disabled(game.money < amount)
                }
            }
        }
        let goods = game.villageGoodsNeeded(project)
        ForEach(goods, id: \.item) { need in
            if let item = ItemCatalog.item(need.item) {
                HStack(spacing: 8) {
                    ItemIcon(name: item.icon, size: 26)
                    Text(need.needed == 0 ? "\(item.name): all given" : "\(item.name): \(need.needed) to go")
                        .font(Theme.label(14))
                    Spacer()
                    if need.needed > 0 {
                        Text("you have \(need.have)")
                            .font(Theme.label(12))
                            .foregroundStyle(need.have > 0 ? Theme.ink : Theme.inkSoft)
                    }
                }
            }
        }
        if goods.contains(where: { $0.needed > 0 }) {
            Button {
                game.giveGoodsToVillage(project.id)
            } label: {
                IconLabel("Send what I have", symbol: "shippingbox.fill")
                    .font(Theme.display(15))
            }
            .buttonStyle(CandyButtonStyle(tint: .green))
            .disabled(!goods.contains { $0.needed > 0 && $0.have > 0 })
        }
        if game.villageIsReady(project) {
            Button {
                game.finishVillageProject(project.id)
            } label: {
                IconLabel("Open it!", symbol: "sparkles")
                    .font(Theme.display(16))
            }
            .buttonStyle(CandyButtonStyle(tint: .gold))
        }
    }

    /// Sensible amounts to give at once.
    private func chunks(_ left: Int) -> [Int] {
        let steps = [500, 2_500, 10_000].filter { $0 < left }
        return Array(steps.suffix(2)) + [left]
    }
}
