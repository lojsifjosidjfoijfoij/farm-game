import SwiftUI
import AcresCore

/// The first thing you see: the valley at dawn, the logo, "Tap to play".
/// The farm is already loaded behind it; a tap lifts it away.
struct TitleScreenView: View {
    let onPlay: () -> Void
    @State private var drift = false
    @State private var pulse = false
    @State private var shown = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack {
                LinearGradient(colors: [Theme.skyDeep, Theme.sky, Color(red: 1, green: 0.9, blue: 0.72)],
                               startPoint: .top, endPoint: .bottom)

                // The sun, rising behind the hills.
                Sunburst(color: .white, rays: 16)
                    .opacity(0.45)
                    .position(x: w * 0.8, y: h * 0.3)
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.97, blue: 0.78), Theme.goldLight],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 74, height: 74)
                    .shadow(color: Theme.goldLight, radius: 24, x: 0, y: 0)
                    .position(x: w * 0.8, y: h * 0.3)

                // Clouds drifting by.
                ForEach(0..<4, id: \.self) { k in
                    TitleCloud()
                        .scaleEffect(k % 2 == 0 ? 1 : 0.7)
                        .position(x: w * [0.12, 0.42, 0.66, 0.95][k], y: h * [0.14, 0.24, 0.1, 0.2][k])
                        .offset(x: drift ? CGFloat(30 + k * 12) : CGFloat(-30 - k * 12))
                }

                // Far hills, then the farm on the near hill.
                HillsShape(crests: [0.55, 0.8, 0.6, 0.9, 0.7, 0.85])
                    .fill(LinearGradient(colors: [Color(red: 0.62, green: 0.8, blue: 0.48), Color(red: 0.48, green: 0.68, blue: 0.36)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w, height: h * 0.5)
                    .position(x: w / 2, y: h * 0.75)
                farm(w: w, h: h)
                HillsShape(crests: [0.75, 0.55, 0.62, 0.4, 0.5])
                    .fill(LinearGradient(colors: [Color(red: 0.5, green: 0.74, blue: 0.3), Color(red: 0.34, green: 0.56, blue: 0.2)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w, height: h * 0.34)
                    .position(x: w / 2, y: h * 0.83)
                FieldRows()
                    .frame(width: w * 0.26, height: h * 0.12)
                    .position(x: w * 0.74, y: h * 0.86)

                // The logo.
                VStack(spacing: 2) {
                    OutlinedTitle(text: "Acres", size: 76)
                    RibbonTitle(text: "A little farm of your own", tint: .green, size: 15)
                        .fixedSize(horizontal: true, vertical: true)
                }
                .scaleEffect(shown ? 1 : 0.6)
                .opacity(shown ? 1 : 0)
                .position(x: w / 2, y: h * 0.34)

                Text("Tap to play")
                    .font(Theme.display(22))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.woodDark, radius: 0, x: 0, y: 2)
                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 2)
                    .scaleEffect(pulse ? 1.06 : 0.96)
                    .opacity(pulse ? 1 : 0.6)
                    .position(x: w / 2, y: h * 0.88)
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
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) { shown = true }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) { drift = true }
        }
    }

    /// The farmhouse, the barn and a few trees, on the far hill.
    private func farm(w: CGFloat, h: CGFloat) -> some View {
        let catalog = AssetCatalog.shared
        return ZStack {
            Image(uiImage: catalog.uiImage("tree_oak_summer")).resizable().scaledToFit()
                .frame(height: h * 0.26).position(x: w * 0.08, y: h * 0.56)
            Image(uiImage: catalog.uiImage("building_barn")).resizable().scaledToFit()
                .frame(height: h * 0.25).position(x: w * 0.36, y: h * 0.6)
            Image(uiImage: catalog.uiImage("building_farmhouse_t1")).resizable().scaledToFit()
                .frame(height: h * 0.27).position(x: w * 0.2, y: h * 0.6)
            Image(uiImage: catalog.uiImage("tree_apple_summer")).resizable().scaledToFit()
                .frame(height: h * 0.2).position(x: w * 0.48, y: h * 0.63)
            Image(uiImage: catalog.uiImage("tree_pine_summer")).resizable().scaledToFit()
                .frame(height: h * 0.24).position(x: w * 0.9, y: h * 0.6)
        }
        .allowsHitTesting(false)
    }
}

/// A soft white cloud made of puffs.
struct TitleCloud: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.white).frame(width: 44, height: 44).offset(x: -26, y: 6)
            Circle().fill(Color.white).frame(width: 58, height: 58).offset(x: 0, y: -4)
            Circle().fill(Color.white).frame(width: 40, height: 40).offset(x: 28, y: 8)
            Capsule().fill(Color.white).frame(width: 110, height: 30).offset(y: 14)
        }
        .opacity(0.9)
        .shadow(color: Theme.skyDeep.opacity(0.3), radius: 6, x: 0, y: 4)
        .allowsHitTesting(false)
    }
}

/// A rolling line of hills along the bottom of its frame.
struct HillsShape: Shape {
    /// Crest heights (0…1 of the frame), spread evenly from left to right.
    var crests: [CGFloat]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard crests.count > 1 else { return path }
        let step = rect.width / CGFloat(crests.count - 1)
        func point(_ k: Int) -> CGPoint {
            CGPoint(x: rect.minX + CGFloat(k) * step, y: rect.maxY - crests[k] * rect.height)
        }
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: point(0))
        for k in 1..<crests.count {
            let from = point(k - 1), to = point(k)
            path.addCurve(to: to, control1: CGPoint(x: from.x + step / 2, y: from.y),
                          control2: CGPoint(x: to.x - step / 2, y: to.y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A little plowed field with sprouts, on the near hill.
struct FieldRows: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.6, green: 0.42, blue: 0.26), Color(red: 0.46, green: 0.3, blue: 0.18)],
                                     startPoint: .top, endPoint: .bottom))
            VStack(spacing: 5) {
                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: 9) {
                        ForEach(0..<8, id: \.self) { _ in
                            Circle()
                                .fill(Color(red: 0.45, green: 0.72, blue: 0.26))
                                .frame(width: 7, height: 7)
                        }
                    }
                }
            }
        }
        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 2)
        .allowsHitTesting(false)
    }
}
