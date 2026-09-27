import SwiftUI
import AcresCore

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

/// Level up! The new level and everything it opens up, over a shower of confetti.
struct LevelUpCardView: View {
    let card: LevelUpCard
    let onClose: () -> Void
    @State private var pop = false

    var body: some View {
        ZStack {
            Confetti()
            VStack(spacing: 12) {
                Text("Level \(card.level)!")
                    .font(Theme.title(34))
                    .foregroundStyle(Theme.ink)
                    .scaleEffect(pop ? 1 : 0.6)
                Image(systemName: "star.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Theme.gold)
                    .rotationEffect(.degrees(pop ? 0 : -40))
                if card.unlocks.isEmpty {
                    Text("You're getting good at this.")
                        .font(Theme.label(15))
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("New for you")
                            .font(Theme.label(13, weight: .bold))
                            .foregroundStyle(Theme.inkSoft)
                        ForEach(card.unlocks, id: \.self) { unlock in
                            Label(unlock.prefix(1).uppercased() + unlock.dropFirst(), systemImage: "lock.open.fill")
                                .font(Theme.label(16, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.parchmentDark.opacity(0.6)))
                }
                Button(action: onClose) {
                    Text("Great!")
                        .font(Theme.label(17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.leafDark))
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.parchment)
                    .shadow(color: .black.opacity(0.25), radius: 18, y: 6)
            )
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.gold, lineWidth: 3))
            .padding(.horizontal, 32)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { pop = true }
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
            .background(Theme.parchment)
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
