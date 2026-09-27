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
                VStack(alignment: .trailing, spacing: 6) {
                    seasonPill
                    if game.isDriving || game.fuelFraction < 0.999 { fuelPill }
                }
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

            if let card = game.tutorialCard {
                TutorialCardView(card: card, onButton: { game.advanceTutorial(.next) }, onSkip: { game.skipTutorial() })
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let shop = game.nearbyShop, game.openShop == nil {
                shopButton(shop)
                    .padding(.bottom, 10)
                    .transition(.scale.combined(with: .opacity))
            }

            if game.showsSeedPicker && !game.isDriving {
                SeedPicker(game: game)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: 12) {
                #if DEBUG
                debugButton
                #endif
                driveButton
                Spacer()
                if !game.isDriving { seedButton }
                inventoryButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .animation(.spring(duration: 0.35), value: game.banner)
        .animation(.spring(duration: 0.35), value: game.inspection)
        .animation(.spring(duration: 0.35), value: game.showsSeedPicker)
        .animation(.spring(duration: 0.35), value: game.nearbyShop)
        .animation(.spring(duration: 0.35), value: game.tutorialCard)
        .animation(.spring(duration: 0.35), value: game.isDriving)
    }

    private var seasonPill: some View {
        HStack(spacing: 6) {
            GameIcon(asset: "ui_icon_season_\(game.season.name.lowercased())",
                     fallbackSymbol: Theme.seasonSymbol(game.season), tint: Theme.seasonColor(game.season), size: 18)
            Text(game.season.name)
                .font(Theme.label(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("· \(Format.duration(game.seasonTimeLeft))")
                .font(Theme.number(14))
                .foregroundStyle(Theme.inkSoft)
        }
        .hudPanel()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(game.season.name), next season in \(Format.duration(game.seasonTimeLeft))")
    }

    private var fuelPill: some View {
        HStack(spacing: 6) {
            GameIcon(asset: "ui_icon_fuel", fallbackSymbol: "fuelpump.fill",
                     tint: game.fuelFraction < 0.15 ? Color(red: 0.8, green: 0.3, blue: 0.25) : Theme.inkSoft, size: 16)
            ProgressView(value: game.fuelFraction)
                .tint(game.fuelFraction < 0.15 ? Color(red: 0.8, green: 0.3, blue: 0.25) : Theme.leaf)
                .frame(width: 56)
        }
        .padding(.vertical, -2)
        .hudPanel(cornerRadius: 12)
        .accessibilityLabel("Fuel \(Int(game.fuelFraction * 100)) percent")
    }

    /// Get in the truck / park it.
    private var driveButton: some View {
        Button {
            if game.isDriving { game.park() } else { game.startDriving() }
        } label: {
            HStack(spacing: 8) {
                GameIcon(asset: "ui_icon_truck", fallbackSymbol: game.isDriving ? "parkingsign.circle.fill" : "truck.pickup.side.fill",
                         tint: .white, size: 24)
                Text(game.isDriving ? "Park" : "Drive")
                    .font(Theme.label(17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(
                Capsule().fill(game.isDriving ? Color(red: 0.55, green: 0.42, blue: 0.28) : Theme.leafDark)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            )
        }
        .buttonStyle(.plain)
        .pulsing(game.tutorialFocus == .driveButton)
        .accessibilityLabel(game.isDriving ? "Park the truck" : "Drive the truck")
    }

    private func shopButton(_ shop: ShopDefinition) -> some View {
        let title: String = switch shop.kind {
        case .market: "Sell at \(shop.name)"
        case .seedShop: "Open the Seed Shop"
        case .gasStation: "Fill up the tank"
        }
        let symbol: String = switch shop.kind {
        case .market: "basket.fill"
        case .seedShop: "leaf.fill"
        case .gasStation: "fuelpump.fill"
        }
        return Button {
            game.openNearbyShop()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(Theme.label(18, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(height: 54)
            .background(Capsule().fill(Theme.gold).shadow(color: .black.opacity(0.25), radius: 6, y: 3))
        }
        .buttonStyle(.plain)
        .pulsing(game.tutorialFocus == .shopButton)
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
                if game.cargoCount > 0 {
                    CountBadge(count: game.cargoCount)
                        .offset(x: -44, y: 0)
                        .accessibilityHidden(true)
                }
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
        .pulsing(game.tutorialFocus == .basket)
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

/// The tutorial's instruction card.
struct TutorialCardView: View {
    let card: TutorialCard
    let onButton: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.title)
                    .font(Theme.title(19))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if card.button == nil {
                    Button("Skip tutorial", action: onSkip)
                        .font(Theme.label(13))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            Text(card.body)
                .font(Theme.label(15))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let title = card.button {
                Button(action: onButton) {
                    Text(title)
                        .font(Theme.label(17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.leafDark))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.parchment.opacity(0.97))
                .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.gold.opacity(0.7), lineWidth: 2))
    }
}

/// The steering joystick, drawn where the thumb went down (visual only).
struct JoystickOverlay: View {
    let game: GameController

    var body: some View {
        ZStack {
            if let stick = game.joystick {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 2))
                    .frame(width: GameController.joystickRadius * 2, height: GameController.joystickRadius * 2)
                    .position(stick.origin)
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                    .frame(width: 56, height: 56)
                    .position(stick.knob)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

/// A gentle pulsing glow that says "tap me" (tutorial).
struct Pulsing: ViewModifier {
    let active: Bool
    @State private var phase = false

    func body(content: Content) -> some View {
        content
            .overlay(
                Capsule()
                    .strokeBorder(Theme.gold, lineWidth: 3)
                    .scaleEffect(phase ? 1.18 : 1)
                    .opacity(active ? (phase ? 0 : 0.9) : 0)
                    .allowsHitTesting(false)
            )
            .onAppear { restart() }
            .onChange(of: active) { _, _ in restart() }
    }

    private func restart() {
        phase = false
        guard active else { return }
        withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) { phase = true }
    }
}

extension View {
    func pulsing(_ active: Bool) -> some View {
        modifier(Pulsing(active: active))
    }
}
