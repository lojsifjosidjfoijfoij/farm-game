import SwiftUI
import AcresCore

/// Minimal heads-up display: money, level, date/time, inventory. Big touch
/// targets, everything reachable with one thumb.
struct HUDView: View {
    let game: GameController
    @State private var showsInventory = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    moneyPill
                    levelPill
                }
                Spacer(minLength: 12)
                datePill
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if let banner = game.banner {
                Text(banner)
                    .font(Theme.title(17))
                    .foregroundStyle(Theme.ink)
                    .hudPanel(cornerRadius: 18)
                    .padding(.top, 14)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()

            HStack(alignment: .bottom) {
                #if DEBUG
                debugButton
                #endif
                Spacer()
                inventoryButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .animation(.spring(duration: 0.4), value: game.banner)
        .sheet(isPresented: $showsInventory) {
            InventoryPlaceholderView()
                .presentationDetents([.medium])
        }
    }

    private var moneyPill: some View {
        HStack(spacing: 8) {
            CoinIcon(size: 22)
            Text(game.money, format: .number)
                .font(Theme.number(19))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText(value: Double(game.money)))
                .animation(.snappy, value: game.money)
        }
        .hudPanel()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(game.money) coins")
    }

    private var levelPill: some View {
        HStack(spacing: 8) {
            GameIcon(asset: "ui_icon_level", fallbackSymbol: "star.fill", tint: Theme.gold, size: 16)
            Text("Lv \(game.level)")
                .font(Theme.label(14, weight: .semibold))
                .foregroundStyle(Theme.ink)
            ProgressView(value: game.levelProgress)
                .tint(Theme.leaf)
                .frame(width: 54)
        }
        .padding(.vertical, -2)
        .hudPanel(cornerRadius: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Farmer level \(game.level)")
    }

    private var datePill: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 6) {
                GameIcon(asset: "ui_icon_season_\(game.season.name.lowercased())",
                         fallbackSymbol: Theme.seasonSymbol(game.season), tint: Theme.seasonColor(game.season), size: 18)
                Text(game.year > 1 ? "\(game.season.name) \(game.dayOfSeason) · Y\(game.year)" : "\(game.season.name) \(game.dayOfSeason)")
                    .font(Theme.label(16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            HStack(spacing: 5) {
                GameIcon(asset: "ui_icon_time_\(game.dayPhase.rawValue)", fallbackSymbol: Theme.phaseSymbol(game.dayPhase),
                         tint: Theme.inkSoft, size: 14)
                Text(game.timeText)
                    .font(Theme.number(15))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .hudPanel()
        .accessibilityElement(children: .combine)
    }

    private var inventoryButton: some View {
        Button {
            Haptics.tap()
            showsInventory = true
        } label: {
            GameIcon(asset: "ui_icon_inventory", fallbackSymbol: "basket.fill", tint: Theme.ink, size: 28)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Theme.parchment.opacity(0.95)).shadow(color: .black.opacity(0.2), radius: 6, y: 3))
                .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Inventory")
    }

    #if DEBUG
    private var debugButton: some View {
        Button {
            game.showsDebugPanel = true
        } label: {
            Image(systemName: "ladybug.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.8))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.parchment.opacity(0.8)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Debug tools")
    }
    #endif
}

/// The inventory arrives in Phase 2; this keeps the button honest until then.
struct InventoryPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "basket.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.leaf)
            Text("Your basket is empty")
                .font(Theme.title(22))
                .foregroundStyle(Theme.ink)
            Text("Harvested crops, eggs and logs will show up here.")
                .font(Theme.label(15))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.parchment)
    }
}
