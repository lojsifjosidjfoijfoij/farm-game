import SwiftUI
import CoreText

/// The in-game HUD's look: wooden frames with paper inside, dark ink type
/// (Fredoka), pixel-art icons, a wooden tool tray with paper slots and
/// painted board buttons. Everything is pixel art at 2 points per art pixel,
/// the world's pixel size at the normal zoom (art: `art/hud/make_hud.py`).
/// Menus and celebrations keep their own look (`GameStyle`).
enum HUD {
    /// Ink on paper.
    static let text = Color(red: 0.29, green: 0.18, blue: 0.1)
    static let textSoft = Color(red: 0.48, green: 0.36, blue: 0.25)
    static let paper = Color(red: 0.95, green: 0.89, blue: 0.75)
    static let paperShade = Color(red: 0.85, green: 0.78, blue: 0.61)
    /// The frames' dark outline (also the edge around white text).
    static let edge = Color(red: 0.23, green: 0.14, blue: 0.09)
    /// The thing in hand, and the main button.
    static let accent = Color(red: 0.886, green: 0.478, blue: 0.086)
    static let xp = Color(red: 0.35, green: 0.66, blue: 0.23)
    static let gold = Color(red: 0.94, green: 0.72, blue: 0.23)
    static let goldEdge = Color(red: 0.54, green: 0.35, blue: 0.04)
    /// Warnings that must read on paper (debt, low fuel, due today).
    static let danger = Color(red: 0.78, green: 0.22, blue: 0.16)

    /// One art pixel, in points. Icons are 12 art pixels: 24 points.
    static let pixel: CGFloat = 2
    static let iconSize: CGFloat = 24

    static func font(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        guard hasFredoka else { return .system(size: size, weight: weight, design: .rounded) }
        let name = weight == .black ? "Fredoka-Bold"
            : (weight == .heavy || weight == .bold) ? "Fredoka-SemiBold" : "Fredoka-Medium"
        return .custom(name, size: size)
    }

    static func number(_ size: CGFloat) -> Font {
        font(size, .black).monospacedDigit()
    }

    /// Fredoka ships in the app (SIL Open Font License, Resources/Fonts).
    /// Registered once at launch; until then, or without it, the HUD uses
    /// the system's rounded font.
    nonisolated(unsafe) private static var hasFredoka = false

    static func registerFont() {
        let url = Bundle.main.url(forResource: "Fredoka", withExtension: "ttf")
            ?? Bundle.main.url(forResource: "Fredoka", withExtension: "ttf", subdirectory: "Fonts")
        if let url {
            _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        hasFredoka = UIFont(name: "Fredoka-SemiBold", size: 12) != nil
    }
}

extension View {
    /// A dark edge around white text (on orange buttons and badges).
    func hudOutline() -> some View {
        shadow(color: HUD.edge, radius: 0, x: 0, y: 1.5)
            .shadow(color: HUD.edge, radius: 0, x: 1, y: 0)
            .shadow(color: HUD.edge, radius: 0, x: -1, y: 0)
            .shadow(color: HUD.edge, radius: 0, x: 0, y: -1)
    }

    /// Paper in a wooden frame behind HUD content.
    func hudPanel(horizontal: CGFloat = 14, vertical: CGFloat = 10) -> some View {
        padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(PixelFrame(.panel))
    }
}

/// A stretchable pixel-art frame: the corners stay put, the edges and the
/// middle repeat (so planks and paper keep their texture at any size).
struct PixelFrame: View {
    enum Kind: String {
        case panel = "ui_hud_panel"
        case wood = "ui_hud_wood"
        case slot = "ui_hud_slot"
        case slotSelected = "ui_hud_slot_selected"
        case button = "ui_hud_button"
        case buttonQuiet = "ui_hud_button_quiet"
        case leather = "ui_hud_leather"

        /// The fixed border, in art pixels (see `art/hud/make_hud.py`).
        var border: CGFloat {
            switch self {
            case .panel, .wood, .leather: 5
            case .slot, .slotSelected: 3
            case .button, .buttonQuiet: 6
            }
        }
    }

    let kind: Kind

    init(_ kind: Kind) { self.kind = kind }

    var body: some View {
        let inset = kind.border * HUD.pixel
        Image(kind.rawValue)
            .interpolation(.none)
            .resizable(capInsets: EdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset), resizingMode: .tile)
    }
}

/// A pixel-art icon from the catalog (12 art pixels, shown at 2 points per pixel).
struct HUDIcon: View {
    let name: String
    var size: CGFloat = HUD.iconSize

    var body: some View {
        ItemIcon(name: name, size: size)
    }
}

/// A pixel-art bar filling from the left (XP, energy, fuel, the tutorial):
/// a dark outline, a paper track, the fill with a darker bottom row.
struct HUDBar: View {
    let fraction: Double
    var color: Color = HUD.xp

    var body: some View {
        GeometryReader { proxy in
            let p = HUD.pixel
            let inner = max(0, proxy.size.width - 2 * p)
            // Whole art pixels only, so the bar steps like pixel art.
            let filled = (inner * CGFloat(max(0, min(1, fraction))) / p).rounded() * p
            ZStack(alignment: .topLeading) {
                Rectangle().fill(HUD.edge)
                Rectangle().fill(HUD.paperShade).padding(p)
                VStack(spacing: 0) {
                    Rectangle().fill(color)
                    Rectangle().fill(color).overlay(Color.black.opacity(0.22)).frame(height: p)
                }
                .frame(width: filled, height: max(0, proxy.size.height - 2 * p))
                .offset(x: p, y: p)
                .opacity(fraction > 0.001 ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.5), value: fraction)
        }
    }
}

/// A square HUD button: paper in a wooden frame, a pixel icon in the middle.
/// Pressing pushes it down a pixel (scaling would smear the pixels).
struct HUDButtonStyle: ButtonStyle {
    var size: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(PixelFrame(.panel))
            .offset(y: configuration.isPressed ? HUD.pixel : 0)
    }
}

/// The main board button ("Sell at the market", Tom's "Next"): painted
/// orange (or plain wood when it can't be used yet), white lettering, and a
/// darker bottom edge it presses into.
struct HUDBoardButtonStyle: ButtonStyle {
    var quiet = false
    var height: CGFloat = 44
    var fontSize: CGFloat = 17

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(HUD.font(fontSize, .black))
            .foregroundStyle(.white)
            .shadow(color: HUD.edge, radius: 0, x: 0, y: HUD.pixel)
            .padding(.horizontal, 18)
            .padding(.bottom, 4)  // sit above the darker bottom edge
            .frame(height: height)
            .background(PixelFrame(quiet ? .buttonQuiet : .button))
            .offset(y: pressed ? HUD.pixel : 0)
    }
}
