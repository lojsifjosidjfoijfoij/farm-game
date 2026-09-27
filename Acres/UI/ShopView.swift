import SwiftUI
import AcresCore

/// The sheet that opens when the truck stops at a shop: seeds, the market
/// or the gas station.
struct ShopView: View {
    let game: GameController
    let shop: ShopDefinition

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    wallet
                    switch shop.kind {
                    case .seedShop: seedShop
                    case .market: market
                    case .gasStation: gasStation
                    case .livestock: livestock
                    }
                }
                .padding(16)
            }
            .background(Theme.parchment)
            .navigationTitle(shop.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { game.openShop = nil }
                }
            }
        }
    }

    private var wallet: some View {
        HStack(spacing: 6) {
            CoinIcon(size: 20)
            Text("\(game.money)")
                .font(Theme.number(18))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Spacer()
            Text(subtitle)
                .font(Theme.label(13))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private var subtitle: String {
        switch shop.kind {
        case .seedShop: "Seeds go to your seed pouch."
        case .market: "Prices change every day."
        case .gasStation: "Fill up before long trips."
        case .livestock: "Animals are delivered to your farm."
        }
    }

    // MARK: Seed shop

    private var seedShop: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(CropCatalog.all) { crop in
                seedRow(crop)
            }
            Text("Saplings")
                .font(Theme.title(18))
                .foregroundStyle(Theme.ink)
                .padding(.top, 6)
            Text("Plant them on plowed soil. Wood trees give logs, fruit trees give fruit again and again.")
                .font(Theme.label(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(TreeCatalog.all) { tree in
                saplingRow(tree)
            }
        }
    }

    private func saplingRow(_ tree: TreeSpecies) -> some View {
        let locked = game.level < tree.unlockLevel
        let owned = game.inventoryItems[tree.saplingItemID] ?? 0
        let gives = tree.fruitItemID.flatMap { ItemCatalog.item($0)?.plural } ?? "\(tree.logs.lowerBound)–\(tree.logs.upperBound) logs"
        return ShopRow {
            ItemIcon(name: "item_sapling_\(tree.id)", size: 42)
                .opacity(locked ? 0.4 : 1)
        } info: {
            Text(tree.name)
                .font(Theme.label(16, weight: .semibold))
            Text("\(gives) · grows in \(Format.duration(tree.growSeconds)) · owned \(owned)")
                .font(Theme.label(12))
                .foregroundStyle(Theme.inkSoft)
        } actions: {
            if locked {
                Label("Level \(tree.unlockLevel)", systemImage: "lock.fill")
                    .font(Theme.label(13, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            } else {
                PriceButton(title: "1", price: tree.saplingCost, enabled: game.money >= tree.saplingCost) {
                    game.buySaplings(tree.id, count: 1)
                }
                PriceButton(title: "5", price: tree.saplingCost * 5, enabled: game.money >= tree.saplingCost * 5) {
                    game.buySaplings(tree.id, count: 5)
                }
            }
        }
    }

    private func seedRow(_ crop: CropDefinition) -> some View {
        let locked = game.level < crop.unlockLevel
        let owned = game.inventoryItems[crop.seedItemID] ?? 0
        return ShopRow {
            ItemIcon(name: "item_seeds_\(crop.id)", size: 42)
                .opacity(locked ? 0.4 : 1)
        } info: {
            Text(crop.name)
                .font(Theme.label(16, weight: .semibold))
            HStack(spacing: 4) {
                ForEach(crop.seasonList, id: \.self) { season in
                    Image(systemName: Theme.seasonSymbol(season))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.seasonColor(season))
                }
                Text("· \(Format.duration(crop.growthSeconds)) · owned \(owned)")
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.inkSoft)
            }
        } actions: {
            if locked {
                Label("Level \(crop.unlockLevel)", systemImage: "lock.fill")
                    .font(Theme.label(13, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            } else {
                PriceButton(title: "1", price: crop.seedCost, enabled: game.money >= crop.seedCost) {
                    game.buySeeds(crop.id, count: 1)
                }
                PriceButton(title: "10", price: crop.seedCost * 10, enabled: game.money >= crop.seedCost * 10) {
                    game.buySeeds(crop.id, count: 10)
                }
            }
        }
    }

    // MARK: Market

    /// Sellable goods in the truck bed.
    private var cargo: [ItemDefinition] {
        ItemCatalog.all.filter { $0.category.isSellable && (game.cargoItems[$0.id] ?? 0) > 0 }
    }

    @ViewBuilder
    private var market: some View {
        if cargo.isEmpty {
            EmptyNote(symbol: "shippingbox",
                      text: "The truck bed is empty. Load your harvest at the farm (basket → Load all), then drive back here.")
            priceBoard
        } else {
            let total = cargo.reduce(0) { $0 + game.price(of: $1.id) * (game.cargoItems[$1.id] ?? 0) }
            VStack(spacing: 10) {
                ForEach(cargo) { item in
                    marketRow(item)
                }
            }
            BigButton(title: "Sell everything", price: total, tint: Theme.leaf) { game.sellAll() }
        }
    }

    private func marketRow(_ item: ItemDefinition) -> some View {
        let count = game.cargoItems[item.id] ?? 0
        let price = game.price(of: item.id)
        return ShopRow {
            ItemIcon(name: item.icon, size: 42)
        } info: {
            Text("\(item.name) ×\(count)")
                .font(Theme.label(16, weight: .semibold))
            PriceTag(price: price, range: item.value)
        } actions: {
            PriceButton(title: "1", price: price, enabled: true) { game.sell(item.id, count: 1) }
            if count > 1 {
                PriceButton(title: "All", price: price * count, enabled: true) { game.sell(item.id, count: count) }
            }
        }
    }

    /// Today's prices for everything, so the player can plan the next trip.
    private var priceBoard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's prices")
                .font(Theme.title(18))
                .foregroundStyle(Theme.ink)
            ForEach(boardItems) { item in
                HStack(spacing: 10) {
                    ItemIcon(name: item.icon, size: 28)
                    Text(item.name)
                        .font(Theme.label(15))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    PriceTag(price: game.price(of: item.id), range: item.value)
                }
            }
        }
        .padding(.top, 6)
    }

    /// Unlocked crops plus every other good the market buys.
    private var boardItems: [ItemDefinition] {
        ItemCatalog.all.filter { item in
            guard item.category.isSellable else { return false }
            if let crop = CropCatalog.crop(item.id) { return crop.unlockLevel <= game.level }
            return true
        }
    }

    // MARK: Livestock market

    private var livestock: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(AnimalCatalog.all) { species in
                animalRow(species)
            }
            Text("Feed")
                .font(Theme.title(18))
                .foregroundStyle(Theme.ink)
                .padding(.top, 6)
            ShopRow {
                ItemIcon(name: "item_animal_feed", size: 42)
            } info: {
                Text("Animal feed")
                    .font(Theme.label(16, weight: .semibold))
                Text("Every animal eats it · in storage \(game.inventoryItems["animal_feed"] ?? 0)")
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.inkSoft)
            } actions: {
                let price = game.balance.feedPrice
                PriceButton(title: "10", price: price * 10, enabled: game.money >= price * 10) { game.buyFeed(count: 10) }
                PriceButton(title: "25", price: price * 25, enabled: game.money >= price * 25) { game.buyFeed(count: 25) }
            }
        }
    }

    private func animalRow(_ species: AnimalSpecies) -> some View {
        let locked = game.level < species.unlockLevel
        let pen = PenCatalog.pen(species.penID)
        let penState = game.simulation.state.ranch[species.penID]
        let product = ItemCatalog.item(species.productItemID)?.plural ?? species.productItemID
        let foods = species.feeds.compactMap { ItemCatalog.item($0)?.name.lowercased() }.prefix(2).joined(separator: " or ")
        let status: String? = if locked {
            nil
        } else if !penState.isRepaired {
            "Fix up the \(pen?.name.lowercased() ?? "pen") at your farm first"
        } else if penState.animals.count >= (pen?.capacity ?? 0) {
            "The \(pen?.name.lowercased() ?? "pen") is full"
        } else {
            nil
        }
        return ShopRow {
            ItemIcon(name: "item_\(species.productItemID)", size: 42)
                .opacity(locked ? 0.4 : 1)
        } info: {
            Text("\(species.youngName) · \(penState.animals.count)/\(pen?.capacity ?? 0)")
                .font(Theme.label(16, weight: .semibold))
            Text(status ?? "Gives \(product) · eats \(foods)")
                .font(Theme.label(12))
                .foregroundStyle(status == nil ? Theme.inkSoft : Color(red: 0.7, green: 0.3, blue: 0.2))
                .fixedSize(horizontal: false, vertical: true)
        } actions: {
            if locked {
                Label("Level \(species.unlockLevel)", systemImage: "lock.fill")
                    .font(Theme.label(13, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            } else {
                PriceButton(title: "Buy", price: species.price, enabled: status == nil && game.money >= species.price) {
                    game.buyAnimal(species.id)
                }
            }
        }
    }

    // MARK: Gas station

    private var gasStation: some View {
        let cost = game.fullTankCost
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tank \(Int((game.fuelFraction * 100).rounded()))%")
                        .font(Theme.label(16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    ProgressView(value: game.fuelFraction)
                        .tint(game.fuelFraction < 0.2 ? Color(red: 0.8, green: 0.3, blue: 0.25) : Theme.gold)
                }
            }
            if cost <= 0 {
                EmptyNote(symbol: "checkmark.circle", text: "The tank is full. Safe travels!")
            } else {
                BigButton(title: game.money >= cost ? "Fill up" : "Fill what I can afford",
                          price: min(cost, game.money), tint: Theme.gold) { game.refuel() }
            }
        }
    }
}

// MARK: - Pieces

/// One line in a shop: icon, name and details, buttons.
private struct ShopRow<Icon: View, Info: View, Actions: View>: View {
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let info: () -> Info
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        HStack(spacing: 12) {
            icon()
            VStack(alignment: .leading, spacing: 3) {
                info()
            }
            .foregroundStyle(Theme.ink)
            Spacer(minLength: 4)
            HStack(spacing: 6) {
                actions()
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.parchmentDark.opacity(0.55)))
    }
}

/// A small "buy/sell N for X coins" button.
private struct PriceButton: View {
    let title: String
    let price: Int
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(title)
                    .font(Theme.label(13, weight: .bold))
                HStack(spacing: 2) {
                    CoinIcon(size: 10)
                    Text("\(price)")
                        .font(Theme.number(11))
                }
            }
            .foregroundStyle(Theme.ink)
            .frame(minWidth: 46, minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.parchment))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}

/// A wide call-to-action button with a price.
private struct BigButton: View {
    let title: String
    let price: Int
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(Theme.label(18, weight: .semibold))
                Spacer()
                CoinIcon(size: 18)
                Text("\(price)")
                    .font(Theme.number(18))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint))
        }
        .buttonStyle(.plain)
    }
}

/// Today's price, with an arrow saying whether it's a good day to sell.
private struct PriceTag: View {
    let price: Int
    let range: ClosedRange<Int>

    var body: some View {
        let span = max(1, range.upperBound - range.lowerBound)
        let t = Double(price - range.lowerBound) / Double(span)
        HStack(spacing: 3) {
            CoinIcon(size: 12)
            Text("\(price) each")
                .font(Theme.label(13))
                .foregroundStyle(Theme.inkSoft)
            if t >= 0.67 {
                Image(systemName: "arrow.up.circle.fill").foregroundStyle(Theme.leaf)
                    .accessibilityLabel("Good price")
            } else if t <= 0.33 {
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(Color(red: 0.8, green: 0.4, blue: 0.25))
                    .accessibilityLabel("Low price")
            }
        }
        .font(.system(size: 12, weight: .semibold))
    }
}

private struct EmptyNote: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            Text(text)
                .font(Theme.label(15))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.parchmentDark.opacity(0.4)))
    }
}
