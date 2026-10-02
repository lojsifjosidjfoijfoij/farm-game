import SwiftUI
import AcresCore

// The look of every menu, card and celebration, in the same wood-and-paper
// pixel art as the HUD (`HUD`): paper pages, cards with an ink-brown edge,
// painted board buttons that press down a pixel, cloth ribbons, a leather
// header on every sheet. Art: `art/hud/make_hud.py`.

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
        HUD.font(size, .black)
    }
}

/// A stretchable pixel-art picture from the catalog by name (fixed corners,
/// tiled edges and middle), for the menu pieces that come in colours.
struct PixelArtFrame: View {
    let name: String
    /// The fixed border, in art pixels.
    let border: CGFloat

    var body: some View {
        let inset = border * HUD.pixel
        Image(name)
            .interpolation(.none)
            .resizable(capInsets: EdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset), resizingMode: .tile)
    }
}

// MARK: - Buttons

/// The colours of a board button or a ribbon.
enum CandyTint {
    case green, gold, red, blue, wood, gray

    var name: String {
        switch self {
        case .green: "green"
        case .gold: "gold"
        case .red: "red"
        case .blue: "blue"
        case .wood: "wood"
        case .gray: "gray"
        }
    }

    /// The paint's darker shade (text shadows on it).
    var lip: Color {
        switch self {
        case .green: Color(red: 0.24, green: 0.48, blue: 0.15)
        case .gold: Color(red: 0.66, green: 0.44, blue: 0.05)
        case .red: Color(red: 0.6, green: 0.16, blue: 0.13)
        case .blue: Color(red: 0.16, green: 0.35, blue: 0.6)
        case .wood: Color(red: 0.43, green: 0.26, blue: 0.13)
        case .gray: Color(red: 0.43, green: 0.41, blue: 0.37)
        }
    }

    /// The pressable look for a colour (theme colours map to their paint).
    static func matching(_ color: Color) -> CandyTint {
        if color == Theme.gold { return .gold }
        if color == Theme.danger { return .red }
        return .green
    }
}

/// A painted board button: an outline, a lit top edge and a darker bottom it
/// presses into (menus and celebrations; the HUD's is `HUDBoardButtonStyle`).
struct CandyButtonStyle: ButtonStyle {
    var tint: CandyTint = .green

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .foregroundStyle(.white)
            .shadow(color: tint.lip, radius: 0, x: 0, y: HUD.pixel)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(PixelArtFrame(name: "ui_board_" + tint.name, border: 6))
            .offset(y: pressed ? HUD.pixel : 0)
    }
}

// MARK: - Surfaces

/// The paper every menu is written on: pixel-art paper, tiled.
struct PaperBackground: View {
    var body: some View {
        Image("ui_paper")
            .interpolation(.none)
            .resizable(capInsets: EdgeInsets(), resizingMode: .tile)
            .ignoresSafeArea()
    }
}

extension View {
    /// A card on the menu paper: lighter paper with an ink-brown edge.
    func card() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PixelArtFrame(name: "ui_card", border: 4))
    }
}

/// A sunken panel of darker paper (a list inside a card).
struct InsetPanel: View {
    var body: some View {
        PixelArtFrame(name: "ui_inset", border: 3)
    }
}

// MARK: - Sheets

/// Every full-screen menu: a stitched leather band with the title and a
/// close button, over paper pages. (No stock navigation bars, so every page
/// looks like part of the farm.)
struct MenuSheet<Accessory: View, Content: View>: View {
    let title: String
    var icon: String?
    let onClose: () -> Void
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    init(title: String, icon: String? = nil, onClose: @escaping () -> Void,
         @ViewBuilder accessory: () -> Accessory, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.onClose = onClose
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let icon { HUDIcon(name: icon) }
                Text(title)
                    .font(HUD.font(20, .black))
                    .foregroundStyle(Color(red: 0.98, green: 0.92, blue: 0.78))
                    .shadow(color: HUD.edge, radius: 0, x: 0, y: HUD.pixel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                accessory
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(HUD.text)
                }
                .buttonStyle(HUDButtonStyle(size: 40))
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(PixelFrame(.leather))
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(PaperBackground())
    }
}

extension MenuSheet where Accessory == EmptyView {
    init(title: String, icon: String? = nil, onClose: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.onClose = onClose
        self.accessory = EmptyView()
        self.content = content()
    }
}

/// A coin count for a sheet's header.
struct HeaderCoins: View {
    let amount: Int

    var body: some View {
        HStack(spacing: 6) {
            HUDIcon(name: "ui_icon_coin")
            Text(amount, format: .number)
                .font(HUD.number(16))
                .foregroundStyle(HUD.text)
        }
        .hudPanel(horizontal: 10, vertical: 6)
    }
}

/// Paper tabs along the top of a page; the open one stands up a little.
struct PaperTabs<Tab: Hashable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    let title: (Tab) -> String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs, id: \.self) { tab in
                let selected = tab == selection
                Button {
                    selection = tab
                    Haptics.selection()
                } label: {
                    Text(title(tab))
                        .font(HUD.font(14, selected ? .black : .heavy))
                        .foregroundStyle(HUD.text)
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(PixelFrame(selected ? .slotSelected : .slot))
                        .offset(y: selected ? -HUD.pixel : 0)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
    }
}

/// An on/off switch in pixel art: a wooden track, green when on, with a paper knob.
struct PaperToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
            Haptics.selection()
        } label: {
            HStack(spacing: 12) {
                configuration.label
                Spacer(minLength: 8)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Rectangle().fill(HUD.edge)
                    Rectangle()
                        .fill(configuration.isOn ? HUD.xp : HUD.paperShade)
                        .padding(HUD.pixel)
                    Rectangle()
                        .fill(HUD.paper)
                        .overlay(Rectangle().stroke(HUD.edge, lineWidth: HUD.pixel))
                        .frame(width: 22, height: 22)
                        .padding(HUD.pixel * 2)
                }
                .frame(width: 52, height: 30)
                .animation(.easeOut(duration: 0.15), value: configuration.isOn)
            }
        }
        .buttonStyle(.plain)
    }
}

/// "Are you sure?" on a paper card, instead of the system's grey sheet.
struct PaperConfirm: ViewModifier {
    let title: String
    @Binding var isPresented: Bool
    var message: String?
    let confirmTitle: String
    var destructive = false
    let action: () -> Void

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                ZStack {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture { isPresented = false }
                    VStack(spacing: 12) {
                        Text(title)
                            .font(Theme.display(19))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                        if let message {
                            Text(message)
                                .font(Theme.label(14))
                                .foregroundStyle(Theme.inkSoft)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 12) {
                            Button("Cancel") { isPresented = false }
                                .font(Theme.display(16))
                                .buttonStyle(CandyButtonStyle(tint: .wood))
                            Button(confirmTitle) {
                                isPresented = false
                                action()
                            }
                            .font(Theme.display(16))
                            .buttonStyle(CandyButtonStyle(tint: destructive ? .red : .green))
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 20)
                    .frame(maxWidth: 380)
                    .background(PixelFrame(.panel))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isPresented)
    }
}

extension View {
    func paperConfirm(_ title: String, isPresented: Binding<Bool>, message: String? = nil,
                      confirmTitle: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        modifier(PaperConfirm(title: title, isPresented: isPresented, message: message,
                              confirmTitle: confirmTitle, destructive: destructive, action: action))
    }
}

// MARK: - Ribbons, badges, titles

/// Text on a cloth ribbon: headings, banners, "LEVEL UP!".
struct RibbonTitle: View {
    let text: String
    var tint: CandyTint = .gold
    var size: CGFloat = 20

    var body: some View {
        Text(text)
            .font(Theme.display(size))
            .foregroundStyle(.white)
            .shadow(color: tint.lip, radius: 0, x: 0, y: HUD.pixel)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 34)
            .padding(.top, 6)
            .padding(.bottom, 14)  // the tails hang below the band
            .background(PixelArtFrame(name: "ui_ribbon_" + tint.name, border: 9))
    }
}

/// The level, on the pixel star (the level-up card, the roadmap).
struct StarBadge: View {
    let level: Int
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            HUDIcon(name: "ui_icon_level", size: size)
            Text("\(level)")
                .font(HUD.number(size * (level >= 10 ? 0.3 : 0.36)))
                .foregroundStyle(.white)
                .hudOutline()
                .offset(y: size * 0.06)
        }
        .frame(width: size, height: size)
    }
}

/// Big cream display text with a dark edge (over busy backgrounds).
struct OutlinedTitle: View {
    let text: String
    var size: CGFloat = 30
    var outline: Color = HUD.edge

    var body: some View {
        Text(text)
            .font(Theme.display(size))
            .foregroundStyle(Color(red: 0.98, green: 0.93, blue: 0.8))
            .shadow(color: outline, radius: 0, x: 2, y: 2)
            .shadow(color: outline, radius: 0, x: -2, y: -2)
            .shadow(color: outline, radius: 0, x: 2, y: -2)
            .shadow(color: outline, radius: 0, x: -2, y: 2)
    }
}

/// Slowly turning rays of light behind a reward (flat, in two tones).
struct Sunburst: View {
    var color: Color = Theme.goldLight
    var rays = 14
    @State private var turn = false

    var body: some View {
        ZStack {
            ForEach(0..<rays, id: \.self) { k in
                Rectangle()
                    .fill(color.opacity(k % 2 == 0 ? 0.32 : 0.18))
                    .frame(width: 24, height: 170)
                    .offset(y: -85)
                    .rotationEffect(.degrees(Double(k) * 360 / Double(rays)))
            }
        }
        .frame(width: 360, height: 360)
        .rotationEffect(.degrees(turn ? 360 : 0))
        .onAppear {
            withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) { turn = true }
        }
        .allowsHitTesting(false)
    }
}

/// The message that drops in at the top of the HUD: paper in a wooden frame, ink type.
struct BannerView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(HUD.font(14))
            .foregroundStyle(HUD.text)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .hudPanel(horizontal: 16, vertical: 10)
    }
}

/// Tom, who ran the farm before you and shows you the ropes: his portrait
/// on a sky-blue square in a paper frame.
struct MentorPortrait: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            PixelFrame(.slot)
            Color(red: 0.5, green: 0.71, blue: 0.85).padding(6)
            Image(uiImage: AssetCatalog.shared.uiImage("ui_portrait_mentor"))
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(6)
        }
        .frame(width: size, height: size)
    }
}
