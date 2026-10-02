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

/// The card a celebration is written on: paper in a wooden frame.
struct RewardPaper: View {
    var body: some View {
        PixelFrame(.panel)
            .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 6)
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
        .buttonStyle(CandyButtonStyle(tint: .green))
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
                            MenuIcon(symbol: "lock.open.fill")
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
                Rectangle()  // square pixels, so they fall without smearing
                    .fill(Self.colors[i % Self.colors.count])
                    .frame(width: 8, height: 8)
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
        MenuSheet(title: "What's next", icon: "ui_icon_level", onClose: { game.showsRoadmap = false }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            StarBadge(level: game.level, size: 36)
                            Text("Level \(game.level)")
                                .font(Theme.title(24))
                        }
                        HUDBar(fraction: game.levelProgress)
                            .frame(height: 12)
                        Text("\(game.xpToNextLevel) XP to level \(game.level + 1). XP comes from harvests, animals, orders, goals and chores.")
                            .font(Theme.label(13))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Theme.ink)
                    .card()
                    ForEach(game.roadmap) { step in
                        HStack(alignment: .top, spacing: 12) {
                            StarBadge(level: step.level, size: 36)
                                .opacity(step.level == game.level + 1 ? 1 : 0.6)
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(step.unlocks, id: \.self) { unlock in
                                    Text(unlock.prefix(1).uppercased() + unlock.dropFirst())
                                        .font(Theme.label(15, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                }
                            }
                            Spacer()
                            if step.level == game.level + 1 {
                                PaperTag(text: "Next", symbol: "sparkles", tint: Theme.goldDark)
                            }
                        }
                        .card()
                    }
                }
                .padding(16)
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
            MenuIcon(symbol: card.renovated ? "house.fill" : "rosette", size: 48)
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
                IconLabel("Go and see the farmhouse!", symbol: "sparkles")
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
            MenuIcon(symbol: "trophy.fill", size: 48)
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
            MenuIcon(symbol: symbol)
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
