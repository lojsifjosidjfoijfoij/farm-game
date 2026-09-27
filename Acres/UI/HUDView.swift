import SwiftUI
import AcresCore

/// The heads-up display: money and level, the clock and the farmer's
/// energy, the current goal, messages, and the buttons along the bottom.
/// Big touch targets, one thumb.
struct HUDView: View {
    @Bindable var game: GameController

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        moneyPill
                        phoneButton
                    }
                    levelPill
                    if !game.tutorial.isActive, let goal = game.openGoals.first { goalTracker(goal) }
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 6) {
                    clockPill
                    energyPill
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
                    InspectionCard(inspection: inspection, onAction: { game.performInspectionAction() }) { game.dismissInspection() }
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

            if game.jobCount > 0 && !game.isDriving {
                jobChip
                    .padding(.bottom, 10)
                    .transition(.scale.combined(with: .opacity))
            }

            if let shop = game.nearbyShop, game.openShop == nil {
                shopButton(shop)
                    .padding(.bottom, 10)
                    .transition(.scale.combined(with: .opacity))
            } else if let client = game.nearbyClient {
                clientButton(client)
                    .padding(.bottom, 10)
                    .transition(.scale.combined(with: .opacity))
            } else if game.nearbyStore != nil, !game.showsStore {
                storeButton
                    .padding(.bottom, 10)
                    .transition(.scale.combined(with: .opacity))
            }

            if game.showsSeedPicker && !game.isDriving {
                SeedPicker(game: game)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if !game.isDriving {
                ToolBelt(game: game)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: 12) {
                #if DEBUG
                debugButton
                #endif
                driveButton
                if game.isDriving { mapMenu }
                Spacer()
                if !game.isDriving && (game.isBedtime || game.tutorialFocus == .bedButton) { bedButton }
                inventoryButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .animation(.spring(duration: 0.35), value: game.banner)
        .animation(.spring(duration: 0.35), value: game.inspection)
        .animation(.spring(duration: 0.35), value: game.showsSeedPicker)
        .animation(.spring(duration: 0.25), value: game.tool)
        .animation(.spring(duration: 0.35), value: game.nearbyShop)
        .animation(.spring(duration: 0.35), value: game.nearbyClient)
        .animation(.spring(duration: 0.35), value: game.nearbyStore)
        .animation(.spring(duration: 0.35), value: game.tutorialCard)
        .animation(.spring(duration: 0.35), value: game.isDriving)
        .animation(.spring(duration: 0.35), value: game.jobCount > 0)
    }

    // MARK: Top

    private var moneyPill: some View {
        let debt = game.money < 0
        return HStack(spacing: 8) {
            CoinIcon(size: 22)
            Text(game.money, format: .number)
                .font(Theme.number(19))
                .foregroundStyle(debt ? Theme.danger : Theme.ink)
                .contentTransition(.numericText(value: Double(game.money)))
                .animation(.snappy, value: game.money)
            if debt {
                Text("debt")
                    .font(Theme.label(11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Theme.danger))
            }
        }
        .hudPanel()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(debt ? "In debt: \(-game.money) coins" : "\(game.money) coins")
    }

    /// The business phone: orders and money. The badge counts orders on.
    private var phoneButton: some View {
        let active = game.contractBoard.active
        let urgent = active.contains { game.daysLeft($0) <= 0 }
        return Button {
            Haptics.tap()
            game.showsSeedPicker = false
            game.showsBusiness = true
        } label: {
            ZStack(alignment: .topTrailing) {
                GameIcon(asset: "ui_icon_phone", fallbackSymbol: "iphone.gen2", tint: Theme.ink, size: 22)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.parchment.opacity(0.95)).shadow(color: .black.opacity(0.2), radius: 5, y: 2))
                    .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
                if !active.isEmpty {
                    Text("\(active.count)")
                        .font(Theme.number(12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(urgent ? Theme.danger : Theme.leafDark))
                        .offset(x: 4, y: -4)
                } else if !game.contractBoard.offers.isEmpty {
                    Circle()
                        .fill(Theme.gold)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                        .offset(x: 1, y: -1)
                }
            }
        }
        .buttonStyle(.plain)
        .pulsing(game.phoneNeedsAttention)
        .accessibilityLabel(active.isEmpty ? "Business phone" : "Business phone, \(active.count) orders on")
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

    /// The first open goal; tap for all goals.
    private func goalTracker(_ goal: GoalProgress) -> some View {
        let claimable = game.openGoals.contains(where: \.isComplete)
        return Button {
            game.showsGoals = true
            Haptics.tap()
        } label: {
            HStack(spacing: 6) {
                GameIcon(asset: "ui_icon_goals", fallbackSymbol: claimable ? "gift.fill" : "flag.checkered",
                         tint: claimable ? Theme.gold : Theme.leafDark, size: 16)
                if claimable {
                    Text("Goal done! Claim")
                        .font(Theme.label(13, weight: .bold))
                        .foregroundStyle(Theme.ink)
                } else {
                    Text(goal.goal.title)
                        .font(Theme.label(13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text("\(goal.current)/\(goal.target)")
                        .font(Theme.number(12))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .padding(.vertical, -2)
            .hudPanel(cornerRadius: 12)
        }
        .buttonStyle(.plain)
        .pulsing(claimable)
        .accessibilityLabel(claimable ? "A goal is complete. Claim the reward." : "Goal: \(goal.goal.title), \(goal.current) of \(goal.target)")
    }

    private var clockPill: some View {
        VStack(alignment: .trailing, spacing: 1) {
            HStack(spacing: 6) {
                Image(systemName: Theme.clockSymbol(hour: game.hour))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                Text(game.clockText)
                    .font(Theme.number(18))
                    .foregroundStyle(Theme.ink)
            }
            HStack(spacing: 4) {
                Image(systemName: Theme.seasonSymbol(game.season))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.seasonColor(game.season))
                Text("\(game.season.name) · \(game.weekText)")
                    .font(Theme.label(11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .hudPanel()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(game.clockText), \(game.season.name), \(game.weekText)")
    }

    private var energyPill: some View {
        let low = game.energyFraction < 0.2
        return HStack(spacing: 6) {
            GameIcon(asset: "ui_icon_energy", fallbackSymbol: "bolt.fill",
                     tint: low ? Color(red: 0.8, green: 0.3, blue: 0.25) : Theme.gold, size: 15)
            ProgressView(value: game.energyFraction)
                .tint(low ? Color(red: 0.8, green: 0.3, blue: 0.25) : Color(red: 0.95, green: 0.72, blue: 0.2))
                .frame(width: 58)
        }
        .padding(.vertical, -2)
        .hudPanel(cornerRadius: 12)
        .accessibilityLabel("Energy \(Int(game.energyFraction * 100)) percent")
    }

    private var fuelPill: some View {
        HStack(spacing: 6) {
            GameIcon(asset: "ui_icon_fuel", fallbackSymbol: "fuelpump.fill",
                     tint: game.fuelFraction < 0.15 ? Color(red: 0.8, green: 0.3, blue: 0.25) : Theme.inkSoft, size: 15)
            ProgressView(value: game.fuelFraction)
                .tint(game.fuelFraction < 0.15 ? Color(red: 0.8, green: 0.3, blue: 0.25) : Theme.leaf)
                .frame(width: 58)
        }
        .padding(.vertical, -2)
        .hudPanel(cornerRadius: 12)
        .accessibilityLabel("Fuel \(Int(game.fuelFraction * 100)) percent")
    }

    // MARK: Middle

    /// "5 jobs lined up · Stop".
    private var jobChip: some View {
        HStack(spacing: 10) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.leafDark)
            Text(game.jobCount == 1 ? "1 job lined up" : "\(game.jobCount) jobs lined up")
                .font(Theme.label(15, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Button("Stop") {
                game.cancelJobs()
                Haptics.tap()
            }
            .font(Theme.label(14, weight: .bold))
            .foregroundStyle(Color(red: 0.75, green: 0.3, blue: 0.22))
        }
        .hudPanel(cornerRadius: 18)
    }

    private func shopButton(_ shop: ShopDefinition) -> some View {
        let open = shop.isOpen(atHour: game.hour)
        let title: String = if !open {
            "\(shop.name) · opens \(String(format: "%02d:00", shop.opens))"
        } else {
            switch shop.kind {
            case .market: "Sell at \(shop.name)"
            case .seedShop: "Open the Seed Shop"
            case .gasStation: "Fill up the tank"
            case .livestock: "Visit \(shop.name)"
            case .bank: "Visit the bank"
            }
        }
        return Button {
            game.openNearbyShop()
        } label: {
            placeLabel(title, symbol: open ? GameController.symbol(for: shop.kind) : "moon.zzz.fill", active: open)
        }
        .buttonStyle(.plain)
        .pulsing(open && game.tutorialFocus == .shopButton)
    }

    /// Parked at a client: hand over the goods for their orders.
    private func clientButton(_ client: ClientDefinition) -> some View {
        let open = client.isOpen(atHour: game.hour)
        let hasOrder = game.contractBoard.active.contains { $0.clientID == client.id }
        let title: String = if !open {
            "\(client.name) · opens \(String(format: "%02d:00", client.opens))"
        } else if hasOrder {
            "Deliver to \(client.name)"
        } else {
            "\(client.name) · no orders"
        }
        return Button {
            if open { game.deliverToNearbyClient() } else {
                Haptics.warning()
                game.showMessage("\(client.name) is closed. It opens at \(String(format: "%02d:00", client.opens)).")
            }
        } label: {
            placeLabel(title, symbol: open ? GameController.symbol(for: client) : "moon.zzz.fill", active: open && hasOrder)
        }
        .buttonStyle(.plain)
        .pulsing(open && hasOrder)
    }

    /// Parked at the corner shop: rent it, or run it.
    private var storeButton: some View {
        let rented = game.storeState.isRented
        return Button {
            game.openNearbyStore()
        } label: {
            placeLabel(rented ? "Open your shop" : "Corner Shop · for rent", symbol: "storefront.fill", active: true)
        }
        .buttonStyle(.plain)
    }

    private func placeLabel(_ title: String, symbol: String, active: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
            Text(title)
                .font(Theme.label(18, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .frame(height: 54)
        .background(Capsule().fill(active ? Theme.gold : Color(red: 0.5, green: 0.5, blue: 0.55))
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3))
    }

    // MARK: Bottom

    /// Hop in (the farmer walks to the truck) / get out.
    private var driveButton: some View {
        Button {
            if game.isDriving { game.park() } else { game.startDriving() }
        } label: {
            HStack(spacing: 8) {
                GameIcon(asset: "ui_icon_truck", fallbackSymbol: game.isDriving ? "figure.walk" : "truck.pickup.side.fill",
                         tint: .white, size: 24)
                Text(game.isDriving ? "Get out" : "Drive")
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
        .accessibilityLabel(game.isDriving ? "Get out of the truck" : "Drive the truck")
    }

    /// The GPS: pick a place and the truck drives there.
    private var mapMenu: some View {
        Menu {
            ForEach(game.destinations) { destination in
                Button {
                    game.drive(to: destination)
                } label: {
                    Label(destination.menuTitle, systemImage: destination.symbol)
                }
            }
        } label: {
            GameIcon(asset: "ui_icon_map", fallbackSymbol: "map.fill", tint: Theme.ink, size: 26)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.parchment.opacity(0.95)).shadow(color: .black.opacity(0.2), radius: 6, y: 3))
                .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
        }
        .pulsing(game.tutorial.step == .drive)
        .accessibilityLabel("Map: drive somewhere")
    }

    private var bedButton: some View {
        Button {
            game.goToBed()
        } label: {
            GameIcon(asset: "ui_icon_bed", fallbackSymbol: "bed.double.fill", tint: Color(red: 0.35, green: 0.4, blue: 0.7), size: 26)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Theme.parchment.opacity(0.95)).shadow(color: .black.opacity(0.2), radius: 6, y: 3))
                .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .pulsing(game.tutorialFocus == .bedButton)
        .accessibilityLabel("Go to bed")
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
    let onAction: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            info
            if let title = inspection.actionTitle {
                Button(action: onAction) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(Theme.label(16, weight: .semibold))
                        if case .repairPen = inspection.action {
                            CoinIcon(size: 16)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(Capsule().fill(Theme.leafDark).shadow(color: .black.opacity(0.2), radius: 4, y: 2))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var info: some View {
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

/// The farmer's tools. The one in hand is raised and ringed; taps and drags
/// on the field only do its job. A short hint says how to use it.
struct ToolBelt: View {
    let game: GameController

    var body: some View {
        VStack(spacing: 6) {
            if game.tool != .hand {
                Text(game.tool.hint)
                    .font(Theme.label(13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.parchment.opacity(0.92)))
                    .transition(.opacity)
                    .id(game.tool)
            }
            HStack(spacing: 6) {
                ForEach(BeltTool.allCases) { tool in
                    button(tool)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Theme.parchment.opacity(0.95)).shadow(color: .black.opacity(0.2), radius: 6, y: 3)
            )
            .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
        }
    }

    private func button(_ tool: BeltTool) -> some View {
        let selected = game.tool == tool
        return Button {
            game.selectTool(tool)
        } label: {
            ZStack(alignment: .topTrailing) {
                icon(tool)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(selected ? Theme.gold.opacity(0.35) : Color.clear))
                    .overlay(Circle().strokeBorder(selected ? Theme.gold : Color.clear, lineWidth: 2.5))
                    .scaleEffect(selected ? 1.1 : 1)
                    .offset(y: selected ? -3 : 0)
                if tool == .seeds, let packet = game.selectedPacket {
                    CountBadge(count: packet.count)
                }
            }
        }
        .buttonStyle(.plain)
        .pulsing(game.tutorialFocus == .tool(tool))
        .accessibilityLabel(tool == .seeds ? "Seeds" : tool.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func icon(_ tool: BeltTool) -> some View {
        if tool == .seeds {
            if let packet = game.selectedPacket {
                ItemIcon(name: packet.icon, size: 34)
            } else {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.leaf)
            }
        } else if let name = tool.icon {
            ItemIcon(name: name, size: 34)
        }
    }
}

/// Slide-up tray of seed packets. Tap one to plant it on empty soil.
struct SeedPicker: View {
    let game: GameController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Seeds & saplings")
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
        let selected = game.selectedSeed == option.id
        return Button {
            game.select(seed: option.id)
        } label: {
            VStack(spacing: 4) {
                ItemIcon(name: option.icon, size: 46)
                Text(option.name)
                    .font(Theme.label(13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(option.inSeason ? "×\(option.count)" : option.seasons)
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
        .accessibilityLabel("\(option.name), \(option.count)\(option.inSeason ? "" : ", out of season")")
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
