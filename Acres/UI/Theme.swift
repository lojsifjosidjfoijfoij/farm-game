import SwiftUI
import UIKit
import AcresCore

/// Colours and fonts for the menus: paper and ink, and the HUD's Fredoka type
/// (`HUD.font`). Friendly and readable. (Buttons, cards, ribbons: `GameStyle`.)
enum Theme {
    static let parchment = Color(red: 0.965, green: 0.937, blue: 0.867)
    static let parchmentDark = Color(red: 0.91, green: 0.866, blue: 0.77)
    static let ink = Color(red: 0.29, green: 0.227, blue: 0.157)
    static let inkSoft = Color(red: 0.29, green: 0.227, blue: 0.157).opacity(0.65)
    static let border = Color(red: 0.55, green: 0.42, blue: 0.28).opacity(0.35)
    static let gold = Color(red: 0.9, green: 0.68, blue: 0.2)
    static let leaf = Color(red: 0.4, green: 0.56, blue: 0.29)
    static let leafDark = Color(red: 0.3, green: 0.45, blue: 0.22)
    /// Warnings: debt, low fuel, due today.
    static let danger = Color(red: 0.8, green: 0.3, blue: 0.25)

    static func number(_ size: CGFloat) -> Font {
        HUD.number(size)
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        HUD.font(size, weight)
    }

    static func title(_ size: CGFloat) -> Font {
        HUD.font(size, .black)
    }

    static func seasonSymbol(_ season: Season) -> String {
        switch season {
        case .spring: "camera.macro"
        case .summer: "sun.max.fill"
        case .autumn: "leaf.fill"
        case .winter: "snowflake"
        }
    }

    static func seasonColor(_ season: Season) -> Color {
        switch season {
        case .spring: Color(red: 0.86, green: 0.52, blue: 0.62)
        case .summer: Color(red: 0.93, green: 0.66, blue: 0.16)
        case .autumn: Color(red: 0.8, green: 0.4, blue: 0.16)
        case .winter: Color(red: 0.42, green: 0.62, blue: 0.82)
        }
    }

    /// Sun, sunset or moon for the clock.
    static func clockSymbol(hour: Int) -> String {
        switch hour {
        case 6..<8: "sunrise.fill"
        case 8..<18: "sun.max.fill"
        case 18..<21: "sunset.fill"
        default: "moon.stars.fill"
        }
    }

    static func phaseSymbol(_ phase: DayPhase) -> String {
        switch phase {
        case .morning: "sunrise.fill"
        case .day: "sun.max.fill"
        case .evening: "sunset.fill"
        case .night: "moon.stars.fill"
        }
    }
}

/// An image that uses real art from the asset catalog when present, and an
/// SF Symbol placeholder otherwise.
struct GameIcon: View {
    let asset: String
    let fallbackSymbol: String
    var tint: Color = Theme.ink
    var size: CGFloat = 20

    var body: some View {
        if UIImage(named: asset) != nil {
            Image(asset)
                .interpolation(.none)  // pixel art: crisp pixels
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: fallbackSymbol)
                .font(.system(size: size * 0.85, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
        }
    }
}

/// The pixel coin (a drawn one if the art is missing).
struct CoinIcon: View {
    var size: CGFloat = 22

    var body: some View {
        if UIImage(named: "ui_icon_coin") != nil {
            Image("ui_icon_coin").interpolation(.none).resizable().scaledToFit().frame(width: size, height: size)
        } else {
            ZStack {
                Circle().fill(
                    LinearGradient(colors: [Color(red: 1, green: 0.86, blue: 0.45), Color(red: 0.85, green: 0.6, blue: 0.15)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().strokeBorder(Color(red: 0.62, green: 0.42, blue: 0.1).opacity(0.7), lineWidth: size * 0.08)
                Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: size * 0.06).padding(size * 0.18)
            }
            .frame(width: size, height: size)
        }
    }
}
