import SwiftUI
import AcresCore

/// Minimal heads-up display: money, level, date/time, messages, the seed
/// button and the inventory. Big touch targets, one thumb.
struct HUDView: View {
    @Bindable var game: GameController

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

            VStack(spacing: 8) {
                if let banner = game.banner {
                    Text(banner)
                        .font(Theme.title(17))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .hudPanel(cornerRadius: 18)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if let inspection = game.inspection {
                    InspectionCard(inspection: inspection) { game.dismissInspection() }
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer()

            if game.showsSeedPicker {
                SeedPicker(game: game)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: 12) {
                #if DEBUG
                debugButton
                #endif
                Spacer()
                seedButton
                inventoryButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .animation(.spring(duration: 0.35), value: game.banner)
        .animation(.spring(duration: 0.35), value: game.inspection)
        .animation(.spring(duration: 0.35), value: game.showsSeedPicker)
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
                .animation(.easeOut(duration: 0.4), value: game.levelProgress)
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

    /// Shows the packet that tapping empty soil will plant.
    private var seedButton: some View {
        Button {
            Haptics.tap()
            game.showsSeedPicker.toggle()
        } label: {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let seed = game.selectedSeed, let crop = CropCatalog.crop(seed) {
                        ItemIcon(name: "item_seeds_\(crop.id)", size: 40)
                    } else {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Theme.leaf)
                    }
                }
                .frame(width: 60, height: 60)
                .background(Circle().fill(Theme.parchment.opacity(0.95)).shadow(color: .black.opacity(0.2), radius: 6, y: 3))
                .overlay(Circle().strokeBorder(game.showsSeedPicker ? Theme.leaf : Theme.border, lineWidth: game.showsSeedPicker ? 2.5 : 1))

                if let seed = game.selectedSeed, let crop = CropCatalog.crop(seed) {
                    CountBadge(count: game.inventoryItems[crop.seedItemID] ?? 0)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Seeds")
    }

    private var inventoryButton: some View {
        Button {
            Haptics.tap()
            game.showsSeedPicker = false
            game.showsInventory = true
        } label: {
            ZStack(alignment: .topTrailing) {
                GameIcon(asset: "ui_icon_inventory", fallbackSymbol: "basket.fill", tint: Theme.ink, size: 28)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Theme.parchment.opacity(0.95)).shadow(color: .black.opacity(0.2), radius: 6, y: 3))
                    .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
                if game.storageUsed >= game.storageCapacity {
                    Text("Full")
                        .font(Theme.label(11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(red: 0.8, green: 0.3, blue: 0.25)))
                }
            }
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

/// Small count bubble for buttons.
struct CountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(Theme.number(12))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(count > 0 ? Theme.leafDark : Color(red: 0.8, green: 0.3, blue: 0.25)))
            .offset(x: 4, y: -4)
    }
}

/// An item or seed icon from the asset catalog (real art or placeholder).
struct ItemIcon: View {
    let name: String
    var size: CGFloat = 40

    var body: some View {
        Image(uiImage: AssetCatalog.shared.uiImage(name))
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

/// What's on a tile (long-press, or a tap with nothing to do).
struct InspectionCard: View {
    let inspection: TileInspection
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: 12) {
                if let icon = inspection.icon {
                    ItemIcon(name: icon, size: 40)
                } else {
                    Image(systemName: inspection.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.leaf)
                        .frame(width: 40, height: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(inspection.title)
                        .font(Theme.title(17))
                        .foregroundStyle(Theme.ink)
                    Text(inspection.detail)
                        .font(Theme.label(14))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .hudPanel(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
}

/// Slide-up tray of seed packets. Tap one to plant it on empty soil.
struct SeedPicker: View {
    let game: GameController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Seeds")
                    .font(Theme.title(18))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(game.season.name) planting")
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.inkSoft)
            }
            let options = game.seedOptions
            if options.isEmpty {
                Text("Your seed pouch is empty. Seeds are sold at the village seed shop.")
                    .font(Theme.label(15))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(options) { option in
                            packet(option)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.parchment.opacity(0.97))
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }

    private func packet(_ option: SeedOption) -> some View {
        let selected = game.selectedSeed == option.crop.id
        return Button {
            game.select(seed: option.crop.id)
        } label: {
            VStack(spacing: 4) {
                ItemIcon(name: "item_seeds_\(option.crop.id)", size: 46)
                Text(option.crop.name)
                    .font(Theme.label(13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(option.inSeason ? "×\(option.count)" : option.crop.seasonList.map(\.name).joined(separator: ", "))
                    .font(Theme.label(11))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
            }
            .frame(width: 84, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Theme.leaf.opacity(0.18) : Theme.parchmentDark.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Theme.leaf : Color.clear, lineWidth: 2)
            )
            .opacity(option.inSeason ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.crop.name) seeds, \(option.count)\(option.inSeason ? "" : ", out of season")")
    }
}
