import SwiftUI
import AcresCore

// The look of menus, cards and celebrations: chunky rounded type, glossy
// "candy" buttons that press down, warm paper, gold ribbons. (The in-game
// HUD has its own slimmer look: `HUD`.)

extension Theme {
    static let wood = Color(red: 0.62, green: 0.42, blue: 0.24)
    static let woodDark = Color(red: 0.4, green: 0.26, blue: 0.14)
    static let woodLight = Color(red: 0.78, green: 0.58, blue: 0.36)
    static let cream = Color(red: 1, green: 0.97, blue: 0.9)
    static let sky = Color(red: 0.5, green: 0.76, blue: 0.93)
    static let skyDeep = Color(red: 0.28, green: 0.55, blue: 0.82)
    static let goldLight = Color(red: 1, green: 0.86, blue: 0.4)
    static let goldDark = Color(red: 0.74, green: 0.5, blue: 0.1)

    /// Big display text (titles on cards, ribbons, the logo).
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
}

// MARK: - Buttons

/// The colours of a candy button.
enum CandyTint {
    case green, gold, red, blue, wood, gray

    var top: Color {
        switch self {
        case .green: Color(red: 0.55, green: 0.8, blue: 0.3)
        case .gold: Color(red: 1, green: 0.82, blue: 0.3)
        case .red: Color(red: 0.95, green: 0.45, blue: 0.35)
        case .blue: Color(red: 0.45, green: 0.72, blue: 0.95)
        case .wood: Color(red: 0.78, green: 0.56, blue: 0.34)
        case .gray: Color(red: 0.72, green: 0.72, blue: 0.7)
        }
    }

    var bottom: Color {
        switch self {
        case .green: Color(red: 0.3, green: 0.6, blue: 0.16)
        case .gold: Color(red: 0.92, green: 0.6, blue: 0.1)
        case .red: Color(red: 0.78, green: 0.22, blue: 0.18)
        case .blue: Color(red: 0.2, green: 0.5, blue: 0.82)
        case .wood: Color(red: 0.55, green: 0.36, blue: 0.2)
        case .gray: Color(red: 0.55, green: 0.55, blue: 0.53)
        }
    }

    /// The darker "lip" under the button that it presses down onto.
    var lip: Color {
        switch self {
        case .green: Color(red: 0.2, green: 0.42, blue: 0.1)
        case .gold: Color(red: 0.7, green: 0.42, blue: 0.05)
        case .red: Color(red: 0.55, green: 0.14, blue: 0.12)
        case .blue: Color(red: 0.12, green: 0.34, blue: 0.6)
        case .wood: Color(red: 0.36, green: 0.22, blue: 0.12)
        case .gray: Color(red: 0.4, green: 0.4, blue: 0.38)
        }
    }

    /// The pressable look for a colour (theme colours map to their candy).
    static func matching(_ color: Color) -> CandyTint {
        if color == Theme.gold { return .gold }
        if color == Theme.danger { return .red }
        return .green
    }
}

/// A glossy, raised button that sinks onto its lip when pressed (menus and celebrations).
struct CandyButtonStyle: ButtonStyle {
    var tint: CandyTint = .green
    var cornerRadius: CGFloat = 14
    var lip: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .foregroundStyle(.white)
            .shadow(color: tint.lip.opacity(0.8), radius: 0, x: 0, y: 1.5)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(LinearGradient(colors: [tint.top, tint.bottom], startPoint: .top, endPoint: .bottom))
                    // Gloss on the upper half.
                    RoundedRectangle(cornerRadius: cornerRadius * 0.8, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.45), Color.white.opacity(0.05)],
                                             startPoint: .top, endPoint: .bottom))
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                        .padding(.bottom, 14)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(tint.lip.opacity(0.9), lineWidth: 1.5)
                }
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.lip)
                    .offset(y: pressed ? 1 : lip)
            )
            .offset(y: pressed ? lip - 1 : 0)
            .shadow(color: .black.opacity(pressed ? 0.12 : 0.25), radius: pressed ? 2 : 4, x: 0, y: pressed ? 1 : 3)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
    }
}

// MARK: - Surfaces

/// The paper that menus are written on: warm, with softly darker edges.
struct PaperBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.cream, Theme.parchment, Theme.parchmentDark], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color.clear, Theme.wood.opacity(0.14)], center: .center, startRadius: 180, endRadius: 620)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Ribbons, badges, titles

/// A ribbon with notched ends.
struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = min(rect.height * 0.35, 14)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + notch, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// Text on a gold (or other) ribbon: headings, banners, "LEVEL UP!".
struct RibbonTitle: View {
    let text: String
    var tint: CandyTint = .gold
    var size: CGFloat = 20

    var body: some View {
        Text(text)
            .font(Theme.display(size))
            .foregroundStyle(.white)
            .shadow(color: tint.lip, radius: 0, x: 0, y: 2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 34)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RibbonShape().fill(tint.lip).offset(y: 3)
                    RibbonShape().fill(LinearGradient(colors: [tint.top, tint.bottom], startPoint: .top, endPoint: .bottom))
                    RibbonShape().stroke(Color.white.opacity(0.35), lineWidth: 1.5).padding(3)
                }
            )
            .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 3)
    }
}

/// A five-pointed star.
struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.5
        var path = Path()
        for k in 0..<10 {
            let angle = CGFloat(k) * .pi / 5 - .pi / 2
            let radius = k % 2 == 0 ? outer : inner
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if k == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// The level, in a gold star (the level pill, the level-up card).
struct StarBadge: View {
    let level: Int
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            StarShape().fill(Theme.goldDark).offset(y: size * 0.05)
            StarShape().fill(LinearGradient(colors: [Theme.goldLight, Theme.gold], startPoint: .top, endPoint: .bottom))
            StarShape().stroke(Color.white.opacity(0.6), lineWidth: max(1, size * 0.03)).padding(size * 0.1)
            Text("\(level)")
                .font(.system(size: size * (level >= 10 ? 0.32 : 0.38), weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: Theme.goldDark, radius: 0, x: 0, y: 1.5)
                .offset(y: size * 0.03)
        }
        .frame(width: size, height: size)
    }
}

/// Big white display text with a dark outline (over busy backgrounds).
struct OutlinedTitle: View {
    let text: String
    var size: CGFloat = 30
    var outline: Color = Theme.woodDark

    var body: some View {
        Text(text)
            .font(Theme.display(size))
            .foregroundStyle(.white)
            .shadow(color: outline, radius: 0, x: 1.5, y: 1.5)
            .shadow(color: outline, radius: 0, x: -1.5, y: -1.5)
            .shadow(color: outline, radius: 0, x: 1.5, y: -1.5)
            .shadow(color: outline, radius: 0, x: -1.5, y: 1.5)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 3)
    }
}

/// Slowly turning rays of light behind a reward.
struct Sunburst: View {
    var color: Color = Theme.goldLight
    var rays = 14
    @State private var turn = false

    var body: some View {
        ZStack {
            ForEach(0..<rays, id: \.self) { k in
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.55), color.opacity(0)], startPoint: .center, endPoint: .top))
                    .frame(width: 26, height: 180)
                    .offset(y: -90)
                    .rotationEffect(.degrees(Double(k) * 360 / Double(rays)))
            }
        }
        .frame(width: 360, height: 360)
        .rotationEffect(.degrees(turn ? 360 : 0))
        .onAppear {
            withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) { turn = true }
        }
        .allowsHitTesting(false)
    }
}

/// The message that drops in at the top of the HUD: slim dark slate, white type.
struct BannerView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(HUD.font(14))
            .foregroundStyle(HUD.text)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(HUD.panelStrong))
    }
}

/// Tom, who ran the farm before you and shows you the ropes.
struct MentorPortrait: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.5, green: 0.71, blue: 0.85))
            Image(uiImage: AssetCatalog.shared.uiImage("ui_portrait_mentor"))
                .resizable()
                .scaledToFit()
                .clipShape(Circle())
            Circle().strokeBorder(Color.white, lineWidth: max(2, size * 0.045))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
    }
}
