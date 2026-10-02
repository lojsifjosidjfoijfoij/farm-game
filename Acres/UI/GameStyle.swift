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

/// A small paper button in a list (prices, choices): a paper slot that
/// presses in a pixel.
struct SlotButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 4)
            .background(PixelFrame(configuration.isPressed ? .slotSelected : .slot))
            .offset(y: configuration.isPressed ? HUD.pixel : 0)
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

/// A thin ink line across a card (above a total).
struct PixelRule: View {
    var body: some View {
        Rectangle()
            .fill(HUD.edge.opacity(0.3))
            .frame(height: HUD.pixel)
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
                    HUDIcon(name: "ui_icon_close")
                }
                .buttonStyle(HUDButtonStyle(size: 40))
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(PixelFrame(.leather).ignoresSafeArea())  // under the notch too
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

/// "Are you sure?" on a paper card, instead of the system's grey sheet (and,
/// with no cancel button, a notice with just "OK").
struct PaperConfirm: ViewModifier {
    let title: String
    @Binding var isPresented: Bool
    var message: String?
    let confirmTitle: String
    var cancelTitle: String? = "Cancel"
    var destructive = false
    let action: () -> Void

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                ZStack {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture { if cancelTitle != nil { isPresented = false } }
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
                            if let cancelTitle {
                                Button(cancelTitle) { isPresented = false }
                                    .font(Theme.display(16))
                                    .buttonStyle(CandyButtonStyle(tint: .wood))
                            }
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

/// A question for `paperConfirm(_:)`, asked from deep inside a page (the
/// card covers the whole sheet, not just the part that asked).
struct ConfirmRequest {
    let title: String
    var message: String?
    let confirmTitle: String
    var destructive = false
    let action: () -> Void
}

extension View {
    func paperConfirm(_ title: String, isPresented: Binding<Bool>, message: String? = nil,
                      confirmTitle: String, cancelTitle: String? = "Cancel", destructive: Bool = false,
                      action: @escaping () -> Void) -> some View {
        modifier(PaperConfirm(title: title, isPresented: isPresented, message: message,
                              confirmTitle: confirmTitle, cancelTitle: cancelTitle, destructive: destructive, action: action))
    }

    func paperConfirm(_ request: Binding<ConfirmRequest?>) -> some View {
        let current = request.wrappedValue
        return paperConfirm(current?.title ?? "",
                            isPresented: Binding(get: { request.wrappedValue != nil },
                                                 set: { if !$0 { request.wrappedValue = nil } }),
                            message: current?.message, confirmTitle: current?.confirmTitle ?? "OK",
                            destructive: current?.destructive ?? false) {
            current?.action()
        }
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

// MARK: - Icons

/// The menus' little pictures: the pixel icon for a thing the farm has art
/// for (`art/hud/make_hud.py`), otherwise the system symbol in ink. Menus
/// name things by SF symbol (some come from the game: shops, clients,
/// tiles), and this table turns them into pixel art.
struct MenuIcon: View {
    let symbol: String
    /// Pixel icons are 12 art px; 24 pt (2 pt per art px) like the HUD, 12 for small tags.
    var size: CGFloat = HUD.iconSize
    var tint: Color = Theme.ink

    var body: some View {
        if let art = Self.art[symbol] {
            HUDIcon(name: art, size: size)
        } else {
            Image(systemName: symbol)
                .font(.system(size: size * 0.75, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
        }
    }

    static let art: [String: String] = [
        "lock.fill": "ui_icon_lock", "lock.open.fill": "ui_icon_unlock",
        "checkmark.seal.fill": "ui_icon_check", "checkmark.circle.fill": "ui_icon_check", "checkmark.circle": "ui_icon_check",
        "gift.fill": "ui_icon_gift",
        "star.fill": "ui_icon_level", "star.circle.fill": "ui_icon_level", "star.bubble.fill": "ui_icon_level",
        "sparkles": "ui_icon_sparkle", "flame.fill": "ui_icon_flame",
        "truck.pickup.side.fill": "ui_icon_truck", "truck.pickup.side": "ui_icon_truck",
        "storefront.fill": "ui_icon_shop", "storefront": "ui_icon_shop", "door.left.hand.open": "ui_icon_shop",
        "door.left.hand.closed": "ui_icon_lock",
        "building.columns.fill": "ui_icon_bank", "hammer.fill": "ui_icon_hammer",
        "trophy.fill": "ui_icon_trophy", "rosette": "ui_icon_rosette", "house.fill": "ui_icon_house",
        "shippingbox": "ui_icon_crate", "shippingbox.fill": "ui_icon_crate", "archivebox.fill": "ui_icon_crate",
        "tray.and.arrow.down.fill": "ui_icon_arrow_down", "arrow.down.circle.fill": "ui_icon_arrow_down",
        "arrow.up.bin.fill": "ui_icon_arrow_up", "arrow.up.bin": "ui_icon_arrow_up", "arrow.up.circle.fill": "ui_icon_arrow_up",
        "leaf": "ui_icon_leaf", "leaf.fill": "ui_icon_leaf", "leaf.arrow.triangle.circlepath": "ui_icon_leaf",
        "tree.fill": "ui_icon_tree", "drop.fill": "ui_icon_drop", "heart.fill": "ui_icon_heart",
        "doc.text.fill": "ui_icon_bill", "signpost.right.fill": "ui_icon_signpost",
        "square.grid.3x3.fill": "ui_icon_field", "square.dashed": "ui_icon_field",
        "fish.fill": "ui_icon_fish", "fork.knife": "ui_icon_bowl", "birthday.cake.fill": "ui_icon_bread",
        "hare.fill": "ui_icon_hen", "basket.fill": "ui_icon_inventory", "fuelpump.fill": "ui_icon_fuel",
        "location.fill": "ui_icon_map", "map.fill": "ui_icon_map", "book.closed.fill": "ui_icon_journal",
        "clock.fill": "ui_icon_clock", "clock.arrow.circlepath": "ui_icon_clock", "hourglass": "ui_icon_clock",
        "gearshape.fill": "ui_icon_settings", "person.fill": "ui_icon_worker",
        "hand.tap.fill": "ui_icon_hand", "speaker.wave.2.fill": "ui_icon_note",
        "calendar": "ui_icon_clock", "banknote.fill": "ui_icon_coin", "book.fill": "ui_icon_journal",
        "flag.fill": "ui_icon_goals", "checklist": "ui_icon_goals", "xmark": "ui_icon_close",
        "moon.stars.fill": "ui_icon_time_night", "moon.stars": "ui_icon_time_night", "moon.zzz.fill": "ui_icon_time_night",
        "sun.max.fill": "ui_icon_time_day", "sunrise.fill": "ui_icon_time_morning", "sunset.fill": "ui_icon_time_evening",
        "cloud.fill": "ui_icon_weather_cloudy", "cloud.rain.fill": "ui_icon_weather_rain", "cloud.snow.fill": "ui_icon_weather_snow",
        "camera.macro": "ui_icon_season_spring", "snowflake": "ui_icon_season_winter",
    ]
}

/// A pixel icon and a line of text (where a system `Label` would go).
struct IconLabel: View {
    let text: String
    let symbol: String
    var size: CGFloat = HUD.iconSize
    var spacing: CGFloat = 6

    init(_ text: String, symbol: String, size: CGFloat = HUD.iconSize, spacing: CGFloat = 6) {
        self.text = text
        self.symbol = symbol
        self.size = size
        self.spacing = spacing
    }

    var body: some View {
        HStack(spacing: spacing) {
            MenuIcon(symbol: symbol, size: size)
            Text(text)
        }
    }
}

/// A small paper tag: "Level 5" with a padlock, "Special", a count.
struct PaperTag: View {
    let text: String
    var symbol: String?
    var tint: Color = Theme.inkSoft

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { MenuIcon(symbol: symbol, size: 12) }
            Text(text)
                .font(Theme.label(12, weight: .bold))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(InsetPanel())
    }
}

/// A section heading on a page: the title, and a quiet note on the right.
struct PageHeading: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.title(18))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(Theme.label(12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.top, 6)
    }
}

/// A short note when a list is empty: a pixel icon and a line of ink.
struct PaperNote: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            MenuIcon(symbol: symbol)
            Text(text)
                .font(Theme.label(14))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InsetPanel())
    }
}
