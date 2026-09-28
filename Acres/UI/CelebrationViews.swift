import SwiftUI
import AcresCore

/// Holds a pop-up card on the short landscape screen: never too wide,
/// centred when it fits, scrolling when it's taller than the screen.
struct FittedCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .frame(maxWidth: 500)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
    }
}

/// "+120" drifting up and fading from the coin counter.
struct FloatingAmount: View {
    let amount: Int
    @State private var rise = false

    var body: some View {
        Text(amount > 0 ? "+\(amount)" : "−\(-amount)")
            .font(Theme.number(amount.magnitude >= 100 ? 18 : 15))
            .foregroundStyle(amount > 0 ? Theme.leafDark : Theme.danger)
            .shadow(color: .white.opacity(0.9), radius: 2)
            .offset(y: rise ? -34 : 0)
            .opacity(rise ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.3)) { rise = true }
            }
            .allowsHitTesting(false)
    }
}

/// The frame every celebration shares: rays of light and confetti behind,
/// cream paper with a gold rim, and a ribbon across the top edge.
struct RewardCard<Content: View>: View {
    let ribbon: String
    var tint: CandyTint = .gold
    var confetti = 1
    /// Rays, confetti and a buzz; off for quieter cards (welcome back, the weekly report).
    var celebrates = true
    @ViewBuilder let content: Content
    @State private var pop = false

    var body: some View {
        ZStack {
            if celebrates {
                Sunburst()
                    .scaleEffect(pop ? 1.1 : 0.3)
                    .opacity(pop ? 1 : 0)
                ForEach(0..<confetti, id: \.self) { _ in Confetti() }
            }
            VStack(spacing: 10) { content }
                .padding(.horizontal, 22)
                .padding(.top, 34)
                .padding(.bottom, 18)
                .frame(maxWidth: 440)
                .background(RewardPaper())
                .overlay(alignment: .top) {
                    RibbonTitle(text: ribbon, tint: tint, size: 22)
                        .fixedSize(horizontal: true, vertical: true)
                        .offset(y: -22)
                }
                .padding(.top, 22)
                .padding(.horizontal, 28)
                .scaleEffect(pop ? 1 : 0.7)
                .opacity(pop ? 1 : 0)
        }
        .onAppear {
            if celebrates { Haptics.success() }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { pop = true }
        }
    }
}

/// Cream card paper with a bright inner edge and a gold rim.
struct RewardPaper: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [Theme.cream, Theme.parchment, Theme.parchmentDark], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                .padding(5)
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Theme.goldLight, Theme.goldDark], startPoint: .top, endPoint: .bottom),
                              lineWidth: 4)
        }
        .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 8)
    }
}

/// The big green "carry on" button at the bottom of a celebration.
struct RewardButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(Theme.display(19))
                .frame(minWidth: 170)
                .padding(.vertical, 2)
        }
        .buttonStyle(CandyButtonStyle(tint: .green, cornerRadius: 18, lip: 5))
        .padding(.top, 4)
    }
}

/// Level up! The new level and everything it opens up.
struct LevelUpCardView: View {
    let card: LevelUpCard
    let onClose: () -> Void
    @State private var spin = false

    var body: some View {
        RewardCard(ribbon: "LEVEL UP!") {
            StarBadge(level: card.level, size: 84)
                .rotationEffect(.degrees(spin ? 0 : -120))
                .scaleEffect(spin ? 1 : 0.3)
                .shadow(color: Theme.goldLight.opacity(0.9), radius: 12, x: 0, y: 0)
            if card.unlocks.isEmpty {
                Text("You're getting good at this.")
                    .font(Theme.label(15, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NEW FOR YOU")
                        .font(Theme.display(12))
                        .foregroundStyle(Theme.wood)
                    ForEach(card.unlocks, id: \.self) { unlock in
                        HStack(spacing: 8) {
                            Image(systemName: "lock.open.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(LinearGradient(colors: [CandyTint.green.top, CandyTint.green.bottom],
                                                                         startPoint: .top, endPoint: .bottom)))
                            Text(unlock.prefix(1).uppercased() + unlock.dropFirst())
                                .font(Theme.label(15, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(InsetPanel())
            }
            RewardButton(title: "Great!", action: onClose)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.15)) { spin = true }
        }
    }
}

/// A shallow, darker well inside a card (lists of unlocks, stats).
struct InsetPanel: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.parchmentDark.opacity(0.7))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.wood.opacity(0.3), lineWidth: 1.5)
        }
    }
}

/// Paper confetti falling once across the screen.
struct Confetti: View {
    @State private var fall = false
    private static let colors: [Color] = [Theme.gold, Theme.leaf, Theme.danger, Color(red: 0.35, green: 0.55, blue: 0.85),
                                          Color(red: 0.95, green: 0.6, blue: 0.75)]

    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<36, id: \.self) { i in
                let x = CGFloat((i * 37) % 100) / 100 * proxy.size.width
                let delay = Double((i * 13) % 10) / 20
                RoundedRectangle(cornerRadius: 2)
                    .fill(Self.colors[i % Self.colors.count])
                    .frame(width: 8, height: 12)
                    .rotationEffect(.degrees(fall ? Double(180 + i * 40) : Double(i * 17)))
                    .position(x: x + (fall ? CGFloat((i % 7) - 3) * 14 : 0), y: fall ? proxy.size.height + 40 : -30)
                    .animation(.easeIn(duration: 2.2).delay(delay), value: fall)
            }
        }
        .allowsHitTesting(false)
        .onAppear { fall = true }
    }
}

/// What the next levels bring: the thing to look forward to.
struct LevelRoadmapView: View {
    let game: GameController

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Level \(game.level)")
                            .font(Theme.title(24))
                        ProgressView(value: game.levelProgress)
                            .tint(Theme.leaf)
                        Text("\(game.xpToNextLevel) XP to level \(game.level + 1). XP comes from harvests, animals, orders, goals and chores.")
                            .font(Theme.label(13))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Theme.ink)
                    .card()
                    ForEach(game.roadmap) { step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(step.level)")
                                .font(Theme.number(18))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(step.level == game.level + 1 ? Theme.gold : Theme.inkSoft))
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(step.unlocks, id: \.self) { unlock in
                                    Text(unlock.prefix(1).uppercased() + unlock.dropFirst())
                                        .font(Theme.label(15, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                }
                            }
                            Spacer()
                        }
                        .card()
                    }
                }
                .padding(16)
            }
            .background(PaperBackground())
            .navigationTitle("What's next")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { game.showsRoadmap = false }
                }
            }
        }
    }
}

/// The farm climbed a rank: its new title, and the farmhouse renovation if any.
struct RankUpCardView: View {
    let card: RankUpCard
    let next: FarmRank?
    let onClose: () -> Void
    @State private var pop = false

    var body: some View {
        RewardCard(ribbon: "NEW RANK!", tint: .green) {
            Image(systemName: card.renovated ? "house.fill" : "rosette")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [Theme.goldLight, Theme.goldDark], startPoint: .top, endPoint: .bottom))
                .shadow(color: Theme.goldDark.opacity(0.6), radius: 0, x: 0, y: 2)
                .rotationEffect(.degrees(pop ? 0 : -30))
                .scaleEffect(pop ? 1 : 0.4)
            Text("Your farm is now")
                .font(Theme.label(14, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            Text(card.rank.title)
                .font(Theme.display(28))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(card.rank.blurb)
                .font(Theme.label(14))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if card.renovated {
                Label("Go and see the farmhouse!", systemImage: "sparkles")
                    .font(Theme.label(14, weight: .bold))
                    .foregroundStyle(Theme.leafDark)
            }
            if let next {
                Text("Next: \(next.title) at a net worth of \(next.netWorth.formatted()) coins.")
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            RewardButton(title: "Wonderful!", action: onClose)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.15)) { pop = true }
        }
    }
}

/// The ending: the Valley's Finest Farm, and the story in numbers. Farming goes on.
struct FinaleCardView: View {
    let stats: FarmStats
    let onClose: () -> Void
    @State private var pop = false

    var body: some View {
        RewardCard(ribbon: "THE VALLEY'S FINEST FARM", confetti: 2) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 50, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [Theme.goldLight, Theme.goldDark], startPoint: .top, endPoint: .bottom))
                .shadow(color: Theme.goldDark.opacity(0.6), radius: 0, x: 0, y: 2)
                .scaleEffect(pop ? 1 : 0.4)
            Text("From a leaky roof and a field of weeds to the pride of the valley. The farmhouse has never looked better.")
                .font(Theme.label(14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 6) {
                    statRow("calendar", "Days farmed", "\(stats.days)")
                    statRow("star.fill", "Farmer level", "\(stats.level)")
                    statRow("banknote.fill", "Net worth", stats.netWorth.formatted())
                    statRow("leaf.fill", "Crops", stats.harvested.formatted())
                    statRow("fish.fill", "Fish caught", stats.fishCaught.formatted())
                }
                VStack(spacing: 6) {
                    statRow("tree.fill", "Wild finds", stats.foraged.formatted())
                    statRow("hammer.fill", "Goods made", stats.crafted.formatted())
                    statRow("shippingbox.fill", "Orders", stats.ordersDone.formatted())
                    statRow("book.fill", "Almanac", "\(Int((stats.almanac * 100).rounded()))%")
                    statRow("flame.fill", "Best streak", "\(stats.bestStreak) days")
                }
            }
            .padding(12)
            .background(InsetPanel())
            RewardButton(title: "Keep farming", action: onClose)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.15)) { pop = true }
        }
    }

    private func statRow(_ symbol: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.leafDark)
                .frame(width: 22)
            Text(title)
                .font(Theme.label(14))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            Text(value)
                .font(Theme.number(15))
                .foregroundStyle(Theme.ink)
        }
    }
}
