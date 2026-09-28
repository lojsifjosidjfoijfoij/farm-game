import SwiftUI
import AcresCore

// The game's look: chunky rounded type, glossy "candy" buttons that press
// down, warm wood and paper, gold ribbons. One place, so every screen matches.

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

/// A glossy, raised button that sinks onto its lip when pressed.
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

/// A round wooden token: a wooden rim around a cream face.
struct TokenBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let rim = min(proxy.size.width, proxy.size.height) * 0.09
            ZStack {
                Circle().fill(Theme.woodDark).offset(y: 3)
                Circle().fill(LinearGradient(colors: [Theme.woodLight, Theme.wood], startPoint: .top, endPoint: .bottom))
                Circle().fill(LinearGradient(colors: [Theme.cream, Theme.parchment], startPoint: .top, endPoint: .bottom))
                    .padding(rim)
                Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 1.5).padding(rim + 1)
                Circle().strokeBorder(Theme.woodDark, lineWidth: 2)
            }
        }
        .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 3)
    }
}

/// A round wooden token button (bed, map, debug) that presses in.
struct TokenButtonStyle: ButtonStyle {
    var size: CGFloat = 54

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .frame(width: size, height: size)
            .background(TokenBackground())
            .offset(y: pressed ? 2 : 0)
            .scaleEffect(pressed ? 0.94 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
    }
}

// MARK: - Surfaces

/// A warm plank of wood with a little grain (the tool belt, headers).
struct WoodPlank: View {
    var cornerRadius: CGFloat = 20

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(LinearGradient(colors: [Theme.woodLight, Theme.wood, Theme.woodDark.opacity(0.95)],
                                     startPoint: .top, endPoint: .bottom))
            // Grain.
            VStack(spacing: 7) {
                ForEach(0..<5, id: \.self) { row in
                    Capsule()
                        .fill(Theme.woodDark.opacity(row % 2 == 0 ? 0.16 : 0.1))
                        .frame(height: 1.5)
                        .padding(.leading, CGFloat(row * 13 % 40))
                        .padding(.trailing, CGFloat(row * 29 % 50))
                }
            }
            .padding(.vertical, 8)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1.5)
                .padding(2)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Theme.woodDark, lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
    }
}

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

/// A glossy progress bar in a sunken track (XP, energy).
struct XPBar: View {
    let fraction: Double
    var top: Color = Color(red: 0.6, green: 0.86, blue: 0.3)
    var bottom: Color = Color(red: 0.32, green: 0.62, blue: 0.16)

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * CGFloat(max(0, min(1, fraction)))
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.woodDark.opacity(0.35))
                Capsule().strokeBorder(Theme.woodDark.opacity(0.35), lineWidth: 1)
                Capsule()
                    .fill(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom))
                    .frame(width: max(proxy.size.height, width))
                    .opacity(fraction > 0.001 ? 1 : 0)
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: max(0, width - proxy.size.height * 0.6), height: proxy.size.height * 0.28)
                    .offset(x: proxy.size.height * 0.3, y: -proxy.size.height * 0.2)
                    .opacity(fraction > 0.05 ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.5), value: fraction)
        }
    }
}

/// The big message that drops in at the top: cream paper with a gold rim.
struct BannerView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.title(16))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [Theme.cream, Theme.parchment], startPoint: .top, endPoint: .bottom))
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
                        .padding(3)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [Theme.goldLight, Theme.goldDark], startPoint: .top, endPoint: .bottom),
                                      lineWidth: 3)
                }
                .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 4)
            )
    }
}

/// Tom, who ran the farm before you and shows you the ropes.
struct MentorPortrait: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Theme.sky, Theme.skyDeep], startPoint: .top, endPoint: .bottom))
            Image(uiImage: AssetCatalog.shared.uiImage("ui_portrait_mentor"))
                .resizable()
                .scaledToFit()
                .clipShape(Circle())
            Circle().strokeBorder(LinearGradient(colors: [Theme.goldLight, Theme.goldDark], startPoint: .top, endPoint: .bottom),
                                  lineWidth: size * 0.07)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
    }
}
