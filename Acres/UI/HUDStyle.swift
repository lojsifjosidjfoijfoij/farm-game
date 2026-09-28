import SwiftUI

/// The in-game HUD's look (design: the "C2 · Slate, slimmer" board on the
/// Acres HUD canvas). Slim, see-through dark slate so the farm shows through;
/// white rounded type with a thin dark edge; bright icons that overlap the
/// ends of their bars; one orange accent for the thing in hand and the main
/// button. Menus and celebrations keep their own look (`GameStyle`).
enum HUD {
    static let slate = Color(red: 0.11, green: 0.14, blue: 0.13)
    /// Bars, chips and round buttons.
    static let panel = slate.opacity(0.62)
    /// Cards with more to read (Tom, a tapped tile, the seed tray).
    static let panelStrong = slate.opacity(0.86)
    static let text = Color.white
    static let textSoft = Color.white.opacity(0.72)
    static let accent = Color(red: 0.886, green: 0.478, blue: 0.086)
    static let xp = Color(red: 0.48, green: 0.75, blue: 0.26)
    static let gold = Color(red: 0.97, green: 0.77, blue: 0.19)
    static let goldEdge = Color(red: 0.54, green: 0.35, blue: 0.04)
    /// Warnings that must read on slate (debt, low fuel, due today).
    static let danger = Color(red: 1, green: 0.47, blue: 0.4)
    /// The dark edge around white numbers.
    static let edge = Color(red: 0.06, green: 0.1, blue: 0.08)
    static let track = Color.black.opacity(0.35)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded).monospacedDigit()
    }
}

extension View {
    /// A thin dark edge around white text, so it reads over any part of the farm.
    func hudOutline() -> some View {
        shadow(color: HUD.edge, radius: 0, x: 0, y: 1.5)
            .shadow(color: HUD.edge, radius: 0, x: 1, y: 0)
            .shadow(color: HUD.edge, radius: 0, x: -1, y: 0)
            .shadow(color: HUD.edge, radius: 0, x: 0, y: -1)
    }
}

/// A flat bar filling from the left (XP, energy, fuel, the tutorial).
struct HUDBar: View {
    let fraction: Double
    var color: Color = HUD.xp

    var body: some View {
        GeometryReader { proxy in
            let clamped = CGFloat(max(0, min(1, fraction)))
            ZStack(alignment: .leading) {
                Capsule().fill(HUD.track)
                Capsule()
                    .fill(color)
                    .frame(width: max(proxy.size.height, proxy.size.width * clamped))
                    .opacity(fraction > 0.001 ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.5), value: fraction)
        }
    }
}

/// A slim bar with its icon overlapping the left end: coins, energy, level.
struct HUDMeter<Icon: View, Content: View>: View {
    var height: CGFloat = 24
    /// How far the bar tucks under the icon.
    var overlap: CGFloat = 14
    @ViewBuilder let icon: Icon
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            icon.zIndex(1)
            content
                .padding(.leading, overlap + 6)
                .padding(.trailing, 10)
                .frame(height: height)
                .background(Capsule().fill(HUD.panel))
                .padding(.leading, -overlap)
        }
    }
}

/// The level in a flat gold star, its number edged in dark.
struct HUDStar: View {
    let level: Int
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            StarShape().fill(HUD.gold)
            StarShape().stroke(HUD.goldEdge, lineWidth: 2.5)
            Text("\(level)")
                .font(HUD.number(size * (level >= 10 ? 0.32 : 0.4)))
                .foregroundStyle(.white)
                .hudOutline()
                .offset(y: size * 0.04)
        }
        .frame(width: size, height: size)
    }
}

/// A flat gold coin.
struct HUDCoin: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle().fill(HUD.gold)
            Circle().strokeBorder(HUD.goldEdge, lineWidth: size * 0.08)
            Circle().strokeBorder(Color(red: 0.84, green: 0.6, blue: 0.11), lineWidth: size * 0.07).padding(size * 0.24)
        }
        .frame(width: size, height: size)
    }
}

/// A round see-through button (phone, bed, basket, map).
struct HUDRoundButtonStyle: ButtonStyle {
    var size: CGFloat = 46

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(Circle().fill(HUD.panel))
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// The main pill button ("Sell at the market", Tom's "Next"): a flat
/// colour with a slightly darker bottom edge that it presses into.
struct HUDPillButtonStyle: ButtonStyle {
    var tint: Color = HUD.accent
    var height: CGFloat = 44
    var fontSize: CGFloat = 17

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(HUD.font(fontSize, .black))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1.5)
            .padding(.horizontal, 16)
            .frame(height: height)
            .background(
                ZStack {
                    Capsule().fill(tint)
                    Capsule().fill(Color.black.opacity(0.2))
                    Capsule().fill(tint).padding(.bottom, pressed ? 1 : 3)
                }
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
            )
            .scaleEffect(pressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
    }
}
