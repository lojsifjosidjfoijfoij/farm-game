import SwiftUI
import AcresCore

/// The heads-up display, laid out for a phone held sideways, slim and
/// see-through so the farm shows (look: `HUD`). Level, goal and chores in the
/// top-left corner; coins, energy, the clock and fuel in the top-right;
/// messages at the top in the middle. Along the bottom: the tool belt in the
/// middle, and bed, phone and basket on the right (the map on the left while
/// driving). To drive, tap the truck itself. Big touch targets, two thumbs.
struct HUDView: View {
    @Bindable var game: GameController

    /// How wide the things in the middle may get, so the corners stay clear.
    static let centerWidth: CGFloat = 440

    var body: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    levelMeter
                    if game.tutorial.hasReached(.claimGoal), let goal = game.openGoals.first { goalTracker(goal) }
                    if !game.tutorial.isActive, game.has(.chores), !game.todaysChores.isEmpty { choresChip }
                    // The tutorial talks from the side, so the field in the middle stays in view.
                    if let card = game.tutorialCard {
                        TutorialCardView(card: card, onButton: { game.advanceTutorial(.next) }, onSkip: { game.skipTutorial() })
                            .frame(width: 340)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                // Messages, at the top in the middle (only in the space the corners leave).
                VStack(spacing: 8) {
                    if let banner = game.banner {
                        BannerView(text: banner)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if let inspection = game.inspection {
                        InspectionCard(inspection: inspection, onAction: { game.performInspectionAction() }) { game.dismissInspection() }
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: 380)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
                VStack(alignment: .trailing, spacing: 5) {
                    moneyMeter
                    energyMeter
                    clockChip
                    if game.isDriving || game.fuelFraction < 0.999 { fuelMeter }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)

            VStack(spacing: 0) {
                Spacer()
                bottomCenter
                    .frame(maxWidth: Self.centerWidth)
                bottomBar
            }
        }
        .animation(.spring(duration: 0.35), value: game.banner)
        .animation(.spring(duration: 0.35), value: game.inspection)
        .animation(.spring(duration: 0.35), value: game.showsSeedPicker)
        .animation(.spring(duration: 0.25), value: game.tool)
        .animation(.spring(duration: 0.3), value: game.placingMachine)
        .animation(.spring(duration: 0.25), value: game.fishingHint)
        .animation(.spring(duration: 0.35), value: game.nearbyShop)
        .animation(.spring(duration: 0.35), value: game.nearbyClient)
        .animation(.spring(duration: 0.35), value: game.nearbyStore)
        .animation(.spring(duration: 0.35), value: game.tutorialCard)
        .animation(.spring(duration: 0.35), value: game.isDriving)
        .animation(.spring(duration: 0.35), value: game.jobCount > 0)
    }

    /// Cards and buttons that come and go above the belt.
    @ViewBuilder
    private var bottomCenter: some View {
        VStack(spacing: 8) {
            if game.jobCount > 0 && !game.isDriving {
                jobChip
                    .transition(.scale.combined(with: .opacity))
            }

            if let shop = game.nearbyShop, game.openShop == nil {
                shopButton(shop)
                    .transition(.scale.combined(with: .opacity))
            } else if let client = game.nearbyClient {
                clientButton(client)
                    .transition(.scale.combined(with: .opacity))
            } else if game.nearbyStore != nil, !game.showsStore {
                storeButton
                    .transition(.scale.combined(with: .opacity))
            }

            if game.showsSeedPicker && !game.isDriving {
                SeedPicker(game: game)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let kind = game.placingMachine, !game.isDriving {
                HStack(spacing: 10) {
                    ItemIcon(name: "item_\(kind)", size: 30)
                    Text("Tap grass on your land to place the \(ItemCatalog.item(kind)?.name.lowercased() ?? "machine").")
                        .font(HUD.font(13))
                        .foregroundStyle(HUD.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Cancel") { game.cancelPlacing() }
                        .font(HUD.font(13, .black))
                        .foregroundStyle(HUD.danger)
                }
                .hudPanel(cornerRadius: 16, strong: true)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let hint = game.fishingHint {
                HStack(spacing: 8) {
                    Image(systemName: "fish.fill")
                        .foregroundStyle(HUD.gold)
                    Text(hint)
                        .font(HUD.font(14))
                        .foregroundStyle(HUD.text)
                }
                .hudPanel(cornerRadius: 16, strong: true)
                .allowsHitTesting(false)
                .transition(.scale.combined(with: .opacity))
                .id(hint)
            }
        }
        .padding(.bottom, 8)
    }

    /// Tools in the middle; bed, phone and basket on the right; the map on
    /// the left while driving. (No drive button: the truck in the world is
    /// the button. Tap it to hop in, tap it again to get out.)
    private var bottomBar: some View {
        ZStack(alignment: .bottom) {
            HStack(alignment: .bottom, spacing: 8) {
                #if DEBUG
                debugButton
                #endif
                if game.isDriving { mapMenu }
                Spacer(minLength: 0)
                if !game.isDriving && (game.isBedtime || game.tutorialFocus == .bedButton) { bedButton }
                // The phone (orders, the books, the Farm tab) arrives at level 2
                // (the tutorial brings it in when it's time).
                if game.has(.phone) && game.tutorial.hasReached(.phone) { phoneButton }
                inventoryButton
            }
            if !game.isDriving {
                ToolBelt(game: game)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    // MARK: Top

    /// The level in a gold star over the end of a bar filling toward the next one.
    private var levelMeter: some View {
        Button {
            game.showsRoadmap = true
            Haptics.tap()
        } label: {
            HUDMeter(height: 18, overlap: 16) {
                HUDStar(level: game.level, size: 38)
            } content: {
                HUDBar(fraction: game.levelProgress)
                    .frame(width: 92, height: 9)
                    .padding(.trailing, -5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Farmer level \(game.level)")
        .accessibilityAddTraits(.isButton)
    }

    private var moneyMeter: some View {
        let debt = game.money < 0
        return HUDMeter(height: 24, overlap: 14) {
            HUDCoin(size: 28)
        } content: {
            HStack(spacing: 6) {
                if debt {
                    Text("debt")
                        .font(HUD.font(11, .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(HUD.danger))
                }
                Text(game.money, format: .number)
                    .font(HUD.number(16))
                    .foregroundStyle(debt ? HUD.danger : HUD.text)
                    .hudOutline()
                    .contentTransition(.numericText(value: Double(game.money)))
                    .animation(.snappy, value: game.money)
            }
            .frame(minWidth: 62, alignment: .trailing)
        }
        .overlay(alignment: .bottomLeading) {
            ZStack {
                ForEach(game.moneyFloats) { float in
                    FloatingAmount(amount: float.amount)
                }
            }
            .offset(x: -8, y: 18)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(debt ? "In debt: \(-game.money) coins" : "\(game.money) coins")
    }

    private var energyMeter: some View {
        let low = game.energyFraction < 0.2
        return HUDMeter(height: 16, overlap: 11) {
            meterIcon("bolt.fill", fill: low ? HUD.danger : HUD.gold, edge: low ? HUD.edge : HUD.goldEdge)
        } content: {
            HUDBar(fraction: game.energyFraction, color: low ? HUD.danger : HUD.gold)
                .frame(width: 70, height: 8)
                .padding(.trailing, -6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Energy \(Int(game.energyFraction * 100)) percent")
    }

    private var fuelMeter: some View {
        let low = game.fuelFraction < 0.15
        return HUDMeter(height: 16, overlap: 11) {
            meterIcon("fuelpump.fill", fill: low ? HUD.danger : Color(red: 0.36, green: 0.62, blue: 0.86), edge: HUD.edge)
        } content: {
            HUDBar(fraction: game.fuelFraction, color: low ? HUD.danger : HUD.xp)
                .frame(width: 70, height: 8)
                .padding(.trailing, -6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fuel \(Int(game.fuelFraction * 100)) percent")
    }

    /// A small round badge at the end of a bar.
    private func meterIcon(_ symbol: String, fill: Color, edge: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(Circle().fill(fill))
            .overlay(Circle().strokeBorder(edge, lineWidth: 2))
    }

    /// "Tue 08:40 · Spring · Week 2", with the sun, moon or weather.
    private var clockChip: some View {
        HStack(spacing: 6) {
            Image(systemName: game.weather == .sunny ? Theme.clockSymbol(hour: game.hour)
                  : GameController.symbol(for: game.weather, hour: game.hour))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(game.weather == .sunny ? HUD.gold : Color(red: 0.7, green: 0.8, blue: 0.95))
            Text(game.clockText)
                .font(HUD.number(14))
                .foregroundStyle(HUD.text)
                .hudOutline()
            Text("\(game.season.name) · \(game.weekText)")
                .font(HUD.font(12))
                .foregroundStyle(HUD.textSoft)
        }
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(Capsule().fill(HUD.panel))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(game.clockText), \(game.season.name), \(game.weekText)")
    }

    /// The first open goal; tap for all goals. Orange when there's a reward to claim.
    private func goalTracker(_ goal: GoalProgress) -> some View {
        let claimable = game.openGoals.contains(where: \.isComplete)
        return Button {
            game.showsGoals = true
            Haptics.tap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: claimable ? "gift.fill" : "flag.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(claimable ? .white : HUD.gold)
                if claimable {
                    Text("Goal done! Claim")
                        .font(HUD.font(12.5, .black))
                        .foregroundStyle(.white)
                } else {
                    Text(goal.goal.title)
                        .font(HUD.font(12.5))
                        .foregroundStyle(HUD.text)
                        .lineLimit(1)
                    Text("\(goal.current)/\(goal.target)")
                        .font(HUD.font(12.5))
                        .foregroundStyle(HUD.textSoft)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Capsule().fill(claimable ? HUD.accent : HUD.panel))
        }
        .buttonStyle(.plain)
        .pulsing(claimable || game.tutorialFocus == .goalTracker)
        .accessibilityLabel(claimable ? "A goal is complete. Claim the reward." : "Goal: \(goal.goal.title), \(goal.current) of \(goal.target)")
    }

    /// Today's chores at a glance (tap for the list). Orange when there's a reward.
    private var choresChip: some View {
        let done = game.todaysChores.filter(\.isDone).count
        let claimable = game.choresClaimable
        return Button {
            game.showsGoals = true
            Haptics.tap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: claimable ? "gift.fill" : "checklist")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(claimable ? .white : HUD.xp)
                Text(claimable ? "Chore done! Claim" : "Today \(done)/\(game.todaysChores.count)")
                    .font(HUD.font(12.5, claimable ? .black : .heavy))
                    .foregroundStyle(HUD.text)
                if game.dailyState.streak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(claimable ? .white : Color(red: 0.95, green: 0.6, blue: 0.27))
                        Text("\(game.dailyState.streak)")
                            .font(HUD.font(12.5))
                            .foregroundStyle(HUD.text)
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Capsule().fill(claimable ? HUD.accent : HUD.panel))
        }
        .buttonStyle(.plain)
        .pulsing(claimable)
        .accessibilityLabel(claimable ? "A chore is done. Claim the reward." : "Today's chores: \(done) of \(game.todaysChores.count) done")
    }

    // MARK: Middle

    /// "5 jobs lined up · Stop".
    private var jobChip: some View {
        HStack(spacing: 10) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(HUD.gold)
            Text(game.jobCount == 1 ? "1 job lined up" : "\(game.jobCount) jobs lined up")
                .font(HUD.font(14))
                .foregroundStyle(HUD.text)
            Button("Stop") {
                game.cancelJobs()
                Haptics.tap()
            }
            .font(HUD.font(14, .black))
            .foregroundStyle(HUD.danger)
        }
        .hudPanel(cornerRadius: 16)
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
            placeLabel(title, symbol: open ? GameController.symbol(for: shop.kind) : "moon.zzz.fill")
        }
        .buttonStyle(HUDPillButtonStyle(tint: open ? HUD.accent : HUD.slate, height: 46))
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
            placeLabel(title, symbol: open ? GameController.symbol(for: client) : "moon.zzz.fill")
        }
        .buttonStyle(HUDPillButtonStyle(tint: open && hasOrder ? HUD.accent : HUD.slate, height: 46))
        .pulsing(open && hasOrder)
    }

    /// Parked at the corner shop: rent it, or run it.
    private var storeButton: some View {
        let rented = game.storeState.isRented
        return Button {
            game.openNearbyStore()
        } label: {
            placeLabel(rented ? "Open your shop" : "Corner Shop · for rent", symbol: "storefront.fill")
        }
        .buttonStyle(HUDPillButtonStyle(height: 46))
    }

    /// What the big button for the place the truck is at says.
    private func placeLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
    }

    // MARK: Bottom

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
            GameIcon(asset: "ui_icon_map", fallbackSymbol: "map.fill", tint: .white, size: 22)
                .frame(width: 46, height: 46)
                .background(Circle().fill(HUD.panel))
        }
        .pulsing(game.tutorial.step == .drive)
        .accessibilityLabel("Map: drive somewhere")
    }

    private var bedButton: some View {
        Button {
            game.goToBed()
        } label: {
            GameIcon(asset: "ui_icon_bed", fallbackSymbol: "moon.fill", tint: HUD.gold, size: 19)
        }
        .buttonStyle(HUDRoundButtonStyle(size: 42))
        .pulsing(game.tutorialFocus == .bedButton)
        .accessibilityLabel("Go to bed")
    }

    /// The business phone: orders and money. The badge counts orders on.
    private var phoneButton: some View {
        let active = game.contractBoard.active
        let urgent = active.contains { game.daysLeft($0) <= 0 }
        return Button {
            Haptics.tap()
            Sound.play(.open, volume: 0.7)
            game.showsSeedPicker = false
            if !game.claimableAlmanacSets.isEmpty { game.businessTab = .almanac }  // a reward waits there
            game.showsBusiness = true
            game.advanceTutorial(.openedPhone)
        } label: {
            GameIcon(asset: "ui_icon_phone", fallbackSymbol: "iphone.gen2", tint: .white, size: 21)
        }
        .buttonStyle(HUDRoundButtonStyle(size: 46))
        .overlay(alignment: .topTrailing) {
            if !active.isEmpty {
                Text("\(active.count)")
                    .font(HUD.number(11))
                    .foregroundStyle(.white)
                    .hudOutline()
                    .padding(.horizontal, 5)
                    .frame(minWidth: 19, minHeight: 19)
                    .background(Capsule().fill(urgent ? HUD.danger : HUD.accent))
                    .offset(x: 3, y: -3)
                    .allowsHitTesting(false)
            } else if !game.contractBoard.offers.isEmpty || !game.claimableAlmanacSets.isEmpty {
                Circle()
                    .fill(HUD.gold)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().strokeBorder(HUD.goldEdge, lineWidth: 1.5))
                    .offset(x: 0, y: 0)
                    .allowsHitTesting(false)
            }
        }
        .pulsing(game.phoneNeedsAttention || game.tutorialFocus == .phoneButton)
        .accessibilityLabel(active.isEmpty ? "Business phone" : "Business phone, \(active.count) orders on")
    }

    private var inventoryButton: some View {
        Button {
            Haptics.tap()
            game.showsSeedPicker = false
            game.showsInventory = true
        } label: {
            GameIcon(asset: "ui_icon_inventory", fallbackSymbol: "basket.fill", tint: .white, size: 24)
        }
        .buttonStyle(HUDRoundButtonStyle(size: 52))
        .overlay(alignment: .topTrailing) {
            if game.storageUsed >= game.storageCapacity {
                Text("Full")
                    .font(HUD.font(11, .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(HUD.danger))
                    .offset(x: 4, y: -4)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topLeading) {
            if game.cargoCount > 0 {
                CountBadge(count: game.cargoCount)
                    .offset(x: -10, y: 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .pulsing(game.tutorialFocus == .basket)
        .accessibilityLabel("Inventory")
    }

    #if DEBUG
    private var debugButton: some View {
        Button {
            game.showsDebugPanel = true
        } label: {
            Image(systemName: "ladybug.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HUD.textSoft)
        }
        .buttonStyle(HUDRoundButtonStyle(size: 36))
        .accessibilityLabel("Debug tools")
    }
    #endif
}

/// Small count bubble for buttons.
struct CountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(HUD.number(11))
            .foregroundStyle(.white)
            .hudOutline()
            .padding(.horizontal, 5)
            .frame(minWidth: 19, minHeight: 19)
            .background(Capsule().fill(count > 0 ? HUD.accent : HUD.danger))
            .offset(x: 4, y: -4)
    }
}

/// An item or seed icon from the asset catalog (real art or placeholder).
struct ItemIcon: View {
    let name: String
    var size: CGFloat = 40

    var body: some View {
        Image(uiImage: AssetCatalog.shared.uiImage(name))
            .interpolation(.none)  // pixel art: crisp pixels
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
                        if case .repairPen = inspection.action {
                            HUDCoin(size: 16)
                        }
                    }
                }
                .buttonStyle(HUDPillButtonStyle(height: 40, fontSize: 15))
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
                        .foregroundStyle(HUD.xp)
                        .frame(width: 40, height: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(inspection.title)
                        .font(HUD.font(16, .black))
                        .foregroundStyle(HUD.text)
                    Text(inspection.detail)
                        .font(HUD.font(13, .semibold))
                        .foregroundStyle(HUD.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 3)
            .hudPanel(cornerRadius: 16, strong: true)
        }
        .buttonStyle(.plain)
    }
}

/// The farmer's tools on a slim see-through tray. The one in hand sits raised
/// on an orange disc; taps and drags on the field only do its job. A short
/// hint says how to use it.
struct ToolBelt: View {
    let game: GameController

    var body: some View {
        VStack(spacing: 10) {
            if game.tool != .hand {
                Text(game.tool.hint)
                    .font(HUD.font(12.5))
                    .foregroundStyle(HUD.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(HUD.panel))
                    .frame(maxWidth: 360)
                    .transition(.opacity)
                    .id(game.tool)
            }
            HStack(spacing: 4) {
                ForEach(game.beltTools) { tool in
                    button(tool)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 52)
            .background(Capsule().fill(HUD.panel))
        }
    }

    private func button(_ tool: BeltTool) -> some View {
        let selected = game.tool == tool
        return Button {
            game.selectTool(tool)
        } label: {
            icon(tool, selected: selected)
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(HUD.accent)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 2.5))
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 3)
                        .opacity(selected ? 1 : 0)
                )
                .scaleEffect(selected ? 1.2 : 1)
                .offset(y: selected ? -9 : 0)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: selected)
                .overlay(alignment: .topTrailing) {
                    if tool == .seeds, let packet = game.selectedPacket {
                        Text("\(packet.count)")
                            .font(HUD.number(11))
                            .foregroundStyle(packet.count > 0 ? HUD.text : HUD.danger)
                            .hudOutline()
                            .offset(x: 2, y: selected ? -12 : -1)
                    }
                }
        }
        .buttonStyle(.plain)
        .pulsing(game.tutorialFocus == .tool(tool))
        .accessibilityLabel(tool == .seeds ? "Seeds" : tool.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func icon(_ tool: BeltTool, selected: Bool) -> some View {
        if tool == .seeds {
            if let packet = game.selectedPacket {
                ItemIcon(name: packet.icon, size: 30)
            } else {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(selected ? .white : HUD.xp)
            }
        } else if let name = tool.icon {
            ItemIcon(name: name, size: 30)
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
                    .font(HUD.font(16, .black))
                    .foregroundStyle(HUD.text)
                Spacer()
                Text("\(game.season.name) planting")
                    .font(HUD.font(12, .bold))
                    .foregroundStyle(HUD.textSoft)
            }
            let options = game.seedOptions
            if options.isEmpty {
                Text("Your seed pouch is empty. Seeds are sold at the village seed shop.")
                    .font(HUD.font(14, .semibold))
                    .foregroundStyle(HUD.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(options) { option in
                            packet(option)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(HUD.panelStrong))
    }

    private func packet(_ option: SeedOption) -> some View {
        let selected = game.selectedSeed == option.id
        return Button {
            game.select(seed: option.id)
        } label: {
            VStack(spacing: 3) {
                ItemIcon(name: option.icon, size: 42)
                Text(option.name)
                    .font(HUD.font(12.5))
                    .foregroundStyle(HUD.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(option.inSeason ? "×\(option.count)" : option.seasons)
                    .font(HUD.font(11, .bold))
                    .foregroundStyle(HUD.textSoft)
                    .lineLimit(1)
            }
            .frame(width: 80, height: 94)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? HUD.accent.opacity(0.3) : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? HUD.accent : Color.clear, lineWidth: 2.5)
            )
            .opacity(option.inSeason ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.name), \(option.count)\(option.inSeason ? "" : ", out of season")")
    }
}

/// The tutorial's instruction card: Tom talking, from the side of the screen.
/// His portrait sits over the card's corner.
struct TutorialCardView: View {
    let card: TutorialCard
    let onButton: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(card.title)
                        .font(HUD.font(17, .black))
                        .foregroundStyle(HUD.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 4)
                    if card.steps > 0 {
                        Text("\(card.step)/\(card.steps)")
                            .font(HUD.number(12))
                            .foregroundStyle(HUD.textSoft)
                            .accessibilityLabel("Step \(card.step) of \(card.steps)")
                    }
                }
                Text(card.body)
                    .font(HUD.font(14, .bold))
                    .foregroundStyle(HUD.text.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                if card.steps > 0 {
                    HUDBar(fraction: Double(card.step) / Double(card.steps), color: HUD.accent)
                        .frame(height: 5)
                        .accessibilityHidden(true)
                }
                HStack {
                    if card.button == nil {
                        Button("Skip tutorial", action: onSkip)
                            .font(HUD.font(12))
                            .foregroundStyle(HUD.textSoft)
                            .accessibilityLabel("Skip the tutorial")
                    }
                    Spacer(minLength: 0)
                    if let title = card.button {
                        Button {
                            Haptics.tap()
                            onButton()
                        } label: {
                            Text(title)
                                .frame(minWidth: 100)
                        }
                        .buttonStyle(HUDPillButtonStyle(height: 38, fontSize: 16))
                    }
                }
                .padding(.top, 2)
            }
            .padding(.leading, 50)
            .padding(.trailing, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(HUD.panelStrong))
            .padding(.leading, 20)
            .padding(.top, 18)

            VStack(spacing: 2) {
                MentorPortrait(size: 64)
                Text("Tom")
                    .font(HUD.font(11, .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
                    .padding(.horizontal, 8)
                    .frame(height: 18)
                    .background(Capsule().fill(HUD.accent))
            }
        }
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
                    .strokeBorder(HUD.gold, lineWidth: 3)
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
