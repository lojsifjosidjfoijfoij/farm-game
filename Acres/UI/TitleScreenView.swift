import SwiftUI
import AcresCore

/// The first thing you see: the farm on a calm evening, in pixel art. Stars
/// twinkle, smoke curls from the chimney, fireflies drift over the meadow
/// and the windows glow. Quiet and warm, the way the game should feel. The
/// farm is already loaded behind it; a tap lifts it away.
struct TitleScreenView: View {
    let onPlay: () -> Void
    @State private var shown = false
    @State private var breathe = false

    /// Where things are in it, as fractions (printed by `make_title.py`).
    private static let chimney = CGPoint(x: 0.3575, y: 0.5713)
    private static let meadowTop: CGFloat = 0.6833
    private static let horizon: CGFloat = 0.625
    /// The sky at the very top, also the launch screen's colour.
    private static let night = Color(red: 0.043, green: 0.063, blue: 0.137)
    private static let cream = Color(red: 0.97, green: 0.91, blue: 0.76)

    var body: some View {
        GeometryReader { proxy in
            let layout = Layout(screen: proxy.size)
            ZStack {
                Self.night
                Image("ui_title_scene")
                    .interpolation(.none)
                    .resizable()
                    .frame(width: layout.width, height: layout.height)
                    .position(x: layout.origin.x + layout.width / 2, y: layout.origin.y + layout.height / 2)
                TimelineView(.animation) { timeline in
                    // (The app has its own `Canvas` for painting placeholders.)
                    SwiftUI.Canvas { context, _ in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        Self.drawStars(in: &context, layout, t)
                        Self.drawSmoke(in: &context, layout, t)
                        Self.drawFireflies(in: &context, layout, t)
                    }
                }
                .allowsHitTesting(false)

                logo
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.25)
                Text("Tap to play")
                    .font(HUD.font(17, .heavy))
                    .foregroundStyle(Self.cream)
                    .shadow(color: HUD.edge, radius: 0, x: 0, y: 2)
                    .opacity(breathe ? 0.9 : 0.4)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.9)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            Sound.play(.tap)
            Haptics.tap()
            onPlay()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Acres. Tap to play.")
        .accessibilityAddTraits(.isButton)
        .onAppear {
            withAnimation(.easeOut(duration: 1.6).delay(0.2)) { shown = true }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { breathe = true }
        }
    }

    private var logo: some View {
        VStack(spacing: 4) {
            Text("Acres")
                .font(HUD.font(68, .black))
                .foregroundStyle(Self.cream)
                .shadow(color: HUD.edge, radius: 0, x: 0, y: 4)
                .shadow(color: Color(red: 1, green: 0.7, blue: 0.35).opacity(0.35), radius: 18)
            Text("a little farm of your own")
                .font(HUD.font(15, .semibold))
                .foregroundStyle(Self.cream.opacity(0.75))
        }
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 8)
    }

    // MARK: The picture on screen

    /// Where the picture sits: whole points per art pixel (at least 2, so the
    /// pixels are even), filling the screen, held to the bottom so the farm
    /// stays in view and any cropping takes sky.
    struct Layout {
        /// The picture (`art/title/make_title.py`), in art pixels.
        static let art = CGSize(width: 480, height: 240)
        let pixel: CGFloat
        let width: CGFloat
        let height: CGFloat
        let origin: CGPoint

        init(screen: CGSize) {
            let fill = max(screen.width / Layout.art.width, screen.height / Layout.art.height)
            pixel = max(2, fill.rounded(.up))
            width = Layout.art.width * pixel
            height = Layout.art.height * pixel
            origin = CGPoint(x: (screen.width - width) / 2, y: screen.height - height)
        }

        /// A point in the picture (fractions), on screen, snapped to the art-pixel grid.
        func point(_ fx: CGFloat, _ fy: CGFloat, dx: CGFloat = 0, dy: CGFloat = 0) -> CGPoint {
            let ax = (fx * Layout.art.width + dx).rounded(.down)
            let ay = (fy * Layout.art.height + dy).rounded(.down)
            return CGPoint(x: origin.x + ax * pixel, y: origin.y + ay * pixel)
        }

        func square(at p: CGPoint, size: CGFloat = 1) -> Path {
            Path(CGRect(x: p.x, y: p.y, width: size * pixel, height: size * pixel))
        }
    }

    /// Repeatable "random" numbers, so the stars and fireflies keep their places.
    private static func hash(_ k: Int, _ salt: Int) -> CGFloat {
        let v = sin(Double(k * 127 + salt * 311) * 12.9898) * 43758.5453
        return CGFloat(v - v.rounded(.down))
    }

    /// A few extra stars that slowly brighten and fade.
    private static func drawStars(in context: inout GraphicsContext, _ layout: Layout, _ t: TimeInterval) {
        for k in 0..<18 {
            let p = layout.point(hash(k, 1), 0.04 + hash(k, 2) * (horizon - 0.2))
            let glow = max(0, sin(t * (0.4 + Double(hash(k, 3)) * 0.8) + Double(hash(k, 4)) * 6.3))
            context.fill(layout.square(at: p), with: .color(Color(red: 0.92, green: 0.94, blue: 1).opacity(0.2 + 0.8 * glow)))
        }
    }

    /// Smoke from the chimney: puffs rising, drifting with the breeze, fading.
    private static func drawSmoke(in context: inout GraphicsContext, _ layout: Layout, _ t: TimeInterval) {
        for k in 0..<7 {
            let life = (t / 5 + Double(k) / 7).truncatingRemainder(dividingBy: 1)
            let rise = CGFloat(life) * 30
            let drift = CGFloat(life) * 8 + CGFloat(sin(t * 0.7 + Double(k))) * 1.5
            let size: CGFloat = life < 0.4 ? 2 : 3
            let p = layout.point(chimney.x, chimney.y, dx: drift - size / 2, dy: -rise - size)
            context.fill(layout.square(at: p, size: size),
                         with: .color(Color(red: 0.62, green: 0.65, blue: 0.76).opacity(0.5 * (1 - life))))
        }
    }

    /// Fireflies: tiny warm lights wandering over the meadow, blinking slowly.
    private static func drawFireflies(in context: inout GraphicsContext, _ layout: Layout, _ t: TimeInterval) {
        for k in 0..<14 {
            let phase = Double(hash(k, 5)) * 6.3
            let dx = CGFloat(sin(t * 0.23 + phase) * 14 + sin(t * 0.61 + phase * 2) * 5)
            let dy = CGFloat(cos(t * 0.19 + phase) * 6)
            let p = layout.point(0.04 + hash(k, 6) * 0.92, meadowTop + 0.04 + hash(k, 7) * 0.26, dx: dx, dy: dy)
            let blink = pow(max(0, sin(t * 0.9 + phase * 3)), 2)
            guard blink > 0.01 else { continue }
            let halo = CGPoint(x: p.x - layout.pixel, y: p.y - layout.pixel)
            context.fill(layout.square(at: halo, size: 3), with: .color(Color(red: 0.95, green: 0.9, blue: 0.45).opacity(0.22 * blink)))
            context.fill(layout.square(at: p), with: .color(Color(red: 1, green: 0.98, blue: 0.7).opacity(blink)))
        }
    }
}
