import SwiftUI
import AcresCore

/// Farm storage, the seed pouch and the truck bed.
struct InventoryView: View {
    let game: GameController

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
            .background(Theme.parchment)
            .navigationTitle("Farm storage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    NavigationLink {
                        SettingsView(game: game)
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { game.showsInventory = false }
                }
            }
        }
    }

    private var storageBar: some View {
        let fraction = game.storageCapacity > 0 ? Double(game.storageUsed) / Double(game.storageCapacity) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Storage")
                    .font(Theme.title(18))
                Spacer()
                Text("\(game.storageUsed) / \(game.storageCapacity)")
                    .font(Theme.number(16))
            }
            .foregroundStyle(Theme.ink)
            ProgressView(value: min(1, fraction))
                .tint(fraction >= 1 ? Color(red: 0.8, green: 0.3, blue: 0.25) : Theme.leaf)
            if fraction >= 1 {
                Text("Full! Crops wait in the field until there's room.")
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
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
        let capacity = game.balance.truckCargoCapacity
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "truck.pickup.side.fill")
                Text("Truck bed")
                    .font(Theme.title(18))
                Spacer()
                Text("\(game.cargoCount) / \(capacity)")
                    .font(Theme.number(16))
            }
            .foregroundStyle(Theme.ink)
            ProgressView(value: min(1, Double(game.cargoCount) / Double(max(1, capacity))))
                .tint(Theme.gold)

            if !cargo.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(cargo) { item in
                            cargoChip(item, count: game.cargoItems[item.id] ?? 0)
                        }
                    }
                }
            }

            if game.truckAtFarm {
                if hasSellables && game.cargoCount < capacity {
                    Button { game.loadAll() } label: {
                        Label("Load all", systemImage: "arrow.up.bin.fill")
                            .font(Theme.label(17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.leaf))
                    }
                    .buttonStyle(.plain)
                    .pulsing(game.tutorial.step == .load)
                }
            } else {
                Text("Loading and unloading happens at the farm.")
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private func cargoChip(_ item: ItemDefinition, count: Int) -> some View {
        HStack(spacing: 6) {
            ItemIcon(name: item.icon, size: 26)
            Text("×\(count)")
                .font(Theme.number(14))
                .foregroundStyle(Theme.ink)
            if game.truckAtFarm {
                Button { game.unload(item.id, count: count) } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.inkSoft)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Unload \(item.plural)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.parchmentDark.opacity(0.55)))
    }

    // MARK: Storage

    private func section(_ category: ItemCategory, empty: String) -> some View {
        let items = ItemCatalog.all.filter { $0.category == category && (game.inventoryItems[$0.id] ?? 0) > 0 }
        return VStack(alignment: .leading, spacing: 10) {
            Text(category.title)
                .font(Theme.title(18))
                .foregroundStyle(Theme.ink)
            if items.isEmpty {
                Text(empty)
                    .font(Theme.label(14))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
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
                    CoinIcon(size: 11)
                    Text("\(item.value.lowerBound)–\(item.value.upperBound)")
                        .font(Theme.label(11))
                        .foregroundStyle(Theme.inkSoft)
                }
                if game.truckAtFarm && game.cargoCount < game.balance.truckCargoCapacity {
                    Button("Load") { game.load(item.id, count: count) }
                        .font(Theme.label(13, weight: .semibold))
                        .buttonStyle(.bordered)
                        .tint(Theme.leaf)
                        .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.parchmentDark.opacity(0.55)))
        .accessibilityElement(children: .combine)
    }
}

/// Player settings (stored on the device, not in the save).
struct SettingsView: View {
    let game: GameController

    var body: some View {
        Form {
            Section {
                Toggle("Harvest reminders", isOn: Binding(get: { game.remindersEnabled }, set: { game.setReminders($0) }))
                Toggle("Haptics", isOn: Binding(get: { game.hapticsEnabled }, set: { game.setHaptics($0) }))
            } footer: {
                Text("Harvest reminders send a notification when your fields are ready while the app is closed.")
            }
            Section {
                Picker("Driving", selection: Binding(get: { game.driveControls }, set: { game.setDriveControls($0) })) {
                    ForEach(DriveControls.allCases) { controls in
                        Text(controls.title).tag(controls)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Driving")
            } footer: {
                Text(game.driveControls.hint)
            }
            Section {
                Button("Restart the tutorial") {
                    game.restartTutorial()
                    game.showsInventory = false
                }
            }
            Section("About") {
                LabeledContent("Version", value: "Acres 0.4 · Phase 4")
            }
        }
        .navigationTitle("Settings")
    }
}
