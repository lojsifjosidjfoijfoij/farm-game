import SwiftUI
import AcresCore

/// Farm storage, the seed pouch and the truck bed; the settings live behind
/// the gear in its header.
struct InventoryView: View {
    let game: GameController
    @State private var showsSettings = false

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        MenuSheet(title: showsSettings ? "Settings" : "Farm storage",
                  icon: showsSettings ? "ui_icon_settings" : "ui_icon_inventory",
                  onClose: { game.showsInventory = false }) {
            Button {
                showsSettings.toggle()
                Haptics.selection()
            } label: {
                HUDIcon(name: showsSettings ? "ui_icon_inventory" : "ui_icon_settings")
            }
            .buttonStyle(HUDButtonStyle(size: 40))
            .accessibilityLabel(showsSettings ? "Back to storage" : "Settings")
        } content: {
            if showsSettings {
                SettingsView(game: game)
            } else {
                storage
            }
        }
    }

    private var storage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                truckSection
                storageBar
                ForEach(ItemCategory.allCases, id: \.self) { category in
                    if let empty = emptyText(category) {
                        section(category, empty: empty)
                    } else if hasItems(category) {
                        section(category, empty: "")
                    }
                }
            }
            .padding(16)
        }
    }

    private var storageBar: some View {
        let fraction = game.storageCapacity > 0 ? Double(game.storageUsed) / Double(game.storageCapacity) : 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                MenuIcon(symbol: "archivebox.fill")
                Text("Storage")
                    .font(Theme.title(18))
                Spacer()
                Text("\(game.storageUsed) / \(game.storageCapacity)")
                    .font(Theme.number(16))
            }
            .foregroundStyle(Theme.ink)
            HUDBar(fraction: min(1, fraction), color: fraction >= 1 ? HUD.danger : HUD.xp)
                .frame(height: 12)
            if fraction >= 1 {
                Text("Full! Crops wait in the field until there's room.")
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .card()
    }

    // MARK: Truck

    /// Categories always listed (with a hint when empty); the rest appear once you have some.
    private func emptyText(_ category: ItemCategory) -> String? {
        switch category {
        case .crop: "Nothing harvested yet. Ripe crops sparkle in the field: tap them to pick."
        case .seed: "No seeds. The village seed shop sells them."
        default: nil
        }
    }

    private func hasItems(_ category: ItemCategory) -> Bool {
        ItemCatalog.all.contains { $0.category == category && (game.inventoryItems[$0.id] ?? 0) > 0 }
    }

    private var cargo: [ItemDefinition] {
        ItemCatalog.all.filter { (game.cargoItems[$0.id] ?? 0) > 0 }
    }

    private var hasSellables: Bool {
        ItemCatalog.all.contains { $0.category.isSellable && (game.inventoryItems[$0.id] ?? 0) > 0 }
    }

    private var truckSection: some View {
        let capacity = game.truckCapacity
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                MenuIcon(symbol: "truck.pickup.side.fill")
                Text("Truck bed")
                    .font(Theme.title(18))
                Spacer()
                Text("\(game.cargoCount) / \(capacity)")
                    .font(Theme.number(16))
            }
            .foregroundStyle(Theme.ink)
            HUDBar(fraction: min(1, Double(game.cargoCount) / Double(max(1, capacity))), color: HUD.gold)
                .frame(height: 12)

            if !cargo.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(cargo) { item in
                            cargoChip(item, count: game.cargoItems[item.id] ?? 0)
                        }
                    }
                    .padding(.bottom, 2)
                }
            }

            if game.truckAtFarm {
                if hasSellables && game.cargoCount < capacity {
                    Button { game.loadAll() } label: {
                        IconLabel("Load all", symbol: "arrow.up.bin.fill")
                            .font(Theme.display(17))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CandyButtonStyle(tint: .green))
                    .pulsing(game.tutorial.step == .load)
                }
            } else {
                Text("Loading and unloading happens at the farm.")
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .card()
    }

    private func cargoChip(_ item: ItemDefinition, count: Int) -> some View {
        HStack(spacing: 6) {
            ItemIcon(name: item.icon, size: 24)
            Text("×\(count)")
                .font(Theme.number(14))
                .foregroundStyle(Theme.ink)
            if game.truckAtFarm {
                Button { game.unload(item.id, count: count) } label: {
                    MenuIcon(symbol: "arrow.down.circle.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Unload \(item.plural)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(InsetPanel())
    }

    // MARK: Storage

    private func section(_ category: ItemCategory, empty: String) -> some View {
        let items = ItemCatalog.all.filter { $0.category == category && (game.inventoryItems[$0.id] ?? 0) > 0 }
        return VStack(alignment: .leading, spacing: 10) {
            PageHeading(title: category.title)
            if items.isEmpty {
                PaperNote(symbol: category == .seed ? "leaf.fill" : "basket.fill", text: empty)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(items) { item in
                        cell(item, count: game.inventoryItems[item.id] ?? 0)
                    }
                }
            }
        }
    }

    private func cell(_ item: ItemDefinition, count: Int) -> some View {
        VStack(spacing: 4) {
            ItemIcon(name: item.icon, size: 48)
            Text(item.name)
                .font(Theme.label(13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("×\(count)")
                .font(Theme.number(15))
                .foregroundStyle(Theme.ink)
            if item.category.isSellable {
                HStack(spacing: 3) {
                    CoinIcon(size: 12)
                    Text("\(item.value.lowerBound)–\(item.value.upperBound)")
                        .font(Theme.label(11))
                        .foregroundStyle(Theme.inkSoft)
                }
                if game.truckAtFarm && game.cargoCount < game.truckCapacity {
                    Button("Load") { game.load(item.id, count: count) }
                        .font(Theme.display(13))
                        .buttonStyle(CandyButtonStyle(tint: .green))
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(PixelArtFrame(name: "ui_card", border: 4))
        .accessibilityElement(children: .combine)
    }
}

/// Player settings (stored on the device, not in the save): paper cards with
/// wooden switches, like the rest of the farm.
struct SettingsView: View {
    let game: GameController
    @State private var confirmsNewFarm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PageHeading(title: "On this phone")
                VStack(alignment: .leading, spacing: 12) {
                    toggle("Harvest reminders", symbol: "clock.fill",
                           isOn: Binding(get: { game.remindersEnabled }, set: { game.setReminders($0) }))
                    toggle("Haptics", symbol: "hand.tap.fill",
                           isOn: Binding(get: { game.hapticsEnabled }, set: { game.setHaptics($0) }))
                    toggle("Sound effects", symbol: "speaker.wave.2.fill",
                           isOn: Binding(get: { game.soundEnabled }, set: { game.setSound($0) }))
                    note("Harvest reminders send a notification when your fields are ready while the app is closed.")
                }
                .card()

                PageHeading(title: "From the beginning")
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Button {
                            game.restartTutorial()
                            game.showsInventory = false
                        } label: {
                            Text("Replay the tutorial")
                                .font(Theme.display(15))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CandyButtonStyle(tint: .wood))
                        Button { confirmsNewFarm = true } label: {
                            Text("Start a new farm…")
                                .font(Theme.display(15))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CandyButtonStyle(tint: .red))
                    }
                    note("Replaying the tutorial keeps your farm. A new farm starts over on day one with the tutorial, "
                         + "and your current farm is gone for good.")
                }
                .card()

                HStack {
                    Text("Acres 1.0")
                        .font(Theme.label(13, weight: .semibold))
                    Spacer()
                    Text("Made with care, for slow evenings.")
                        .font(Theme.label(12))
                }
                .foregroundStyle(Theme.inkSoft)
                .padding(.horizontal, 4)
            }
            .padding(16)
        }
        .paperConfirm("Start over with a brand-new farm?", isPresented: $confirmsNewFarm,
                      message: "Your current farm, coins and progress will be deleted. This can't be undone.",
                      confirmTitle: "Start a new farm", destructive: true) {
            game.startNewFarm()
        }
    }

    private func toggle(_ title: String, symbol: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            IconLabel(title, symbol: symbol, spacing: 10)
                .font(Theme.label(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
        .toggleStyle(PaperToggleStyle())
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Theme.label(13))
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
    }
}
