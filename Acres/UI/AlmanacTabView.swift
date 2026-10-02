import SwiftUI
import AcresCore

/// The farm journal's Almanac tab: the farm's rank in the valley (by net worth),
/// and the collection book of everything grown, caught, found and made,
/// page by page, each with a reward when it's full.
struct AlmanacTabView: View {
    let game: GameController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            rankCard
            almanacHeader
            ForEach(Almanac.sets) { set in
                setCard(set)
            }
        }
    }

    // MARK: Rank

    private var rankCard: some View {
        let rank = game.farmRank
        let worth = game.netWorth
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: rank.id == FarmRanks.finale.id ? "trophy.fill" : "rosette")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Farm rank")
                        .font(Theme.label(12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                    Text(rank.title)
                        .font(Theme.title(21))
                }
                Spacer()
            }
            Text(rank.blurb)
                .font(Theme.label(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Net worth")
                    .font(Theme.label(13, weight: .semibold))
                Spacer()
                CoinIcon(size: 15)
                Text(worth.formatted())
                    .font(Theme.number(16))
            }
            if let next = game.nextFarmRank {
                let span = Double(max(1, next.netWorth - rank.netWorth))
                ProgressView(value: min(1, max(0, Double(worth - rank.netWorth) / span)), total: 1)
                    .tint(Theme.gold)
                Text(nextText(next))
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button {
                    game.showsBusiness = false
                    game.rankUpCard = RankUpCard(rank: FarmRanks.finale, renovated: false)
                } label: {
                    Label("See your farm's story", systemImage: "book.closed.fill")
                        .font(Theme.label(14, weight: .semibold))
                        .foregroundStyle(Theme.leafDark)
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(Theme.ink)
        .card()
    }

    private func nextText(_ next: FarmRank) -> String {
        let renovation = next.farmhouseTier > game.farmRank.farmhouseTier ? " The farmhouse gets a makeover." : ""
        return "Next: \(next.title) at \(next.netWorth.formatted()) coins.\(renovation) Net worth counts coins, land, buildings, "
            + "machines, animals and goods, minus loans."
    }

    // MARK: Almanac

    private var almanacHeader: some View {
        let found = Almanac.entries.filter { game.almanac.has($0.id) }.count
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Almanac")
                    .font(Theme.title(19))
                Spacer()
                Text("\(found) of \(Almanac.entries.count) found")
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.inkSoft)
            }
            ProgressView(value: Double(found), total: Double(max(1, Almanac.entries.count)))
                .tint(Theme.leaf)
            Text("Everything you grow, catch, find in the wild or make goes in here. Fill a page for a reward.")
                .font(Theme.label(12))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.ink)
        .padding(.top, 4)
    }

    private func setCard(_ set: AlmanacSet) -> some View {
        let found = set.items.filter { game.almanac.has($0) }.count
        let claimed = game.almanac.claimedSets.contains(set.id)
        let complete = found == set.items.count
        let rows = stride(from: 0, to: set.items.count, by: 5).map { Array(set.items[$0..<min($0 + 5, set.items.count)]) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(set.name)
                        .font(Theme.label(15, weight: .semibold))
                    Text("\(found) of \(set.items.count) · reward \(set.coins) coins, \(set.xp) XP")
                        .font(Theme.label(11))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 4)
                if claimed {
                    Label("Done", systemImage: "checkmark.seal.fill")
                        .font(Theme.label(12, weight: .semibold))
                        .foregroundStyle(Theme.leafDark)
                } else if complete {
                    ActionCapsule(title: "Claim", enabled: true, tint: Theme.gold) { game.claimAlmanacSet(set.id) }
                }
            }
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    ForEach(rows[index], id: \.self) { item in
                        entry(item)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .card()
    }

    private func entry(_ item: String) -> some View {
        let known = game.almanac.has(item)
        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(known ? Theme.parchmentDark.opacity(0.5) : Theme.parchmentDark.opacity(0.9))
            ItemIcon(name: "item_\(item)", size: 36)
                .opacity(known ? 1 : 0.12)
            if !known {
                Text("?")
                    .font(Theme.title(20))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .frame(width: 48, height: 48)
        .accessibilityLabel(known ? (ItemCatalog.item(item)?.name ?? item) : "Not found yet")
    }
}
