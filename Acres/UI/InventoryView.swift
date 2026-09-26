import SwiftUI
import AcresCore

/// Farm storage and the seed pouch.
struct InventoryView: View {
    let game: GameController

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    storageBar
                    section(.crop, empty: "Nothing harvested yet. Ripe crops sparkle in the field: tap them to pick.")
                    section(.seed, empty: "No seeds. The village seed shop sells them.")
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
            if item.category == .crop {
                HStack(spacing: 3) {
                    CoinIcon(size: 11)
                    Text("\(item.value.lowerBound)–\(item.value.upperBound)")
                        .font(Theme.label(11))
                        .foregroundStyle(Theme.inkSoft)
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
            Section("About") {
                LabeledContent("Version", value: "Acres 0.2 · Phase 2")
            }
        }
        .navigationTitle("Settings")
    }
}
