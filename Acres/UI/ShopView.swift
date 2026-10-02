import SwiftUI
import AcresCore

/// The sheet that opens when the truck stops at a shop: seeds, the market
/// or the gas station.
struct ShopView: View {
    let game: GameController
    let shop: ShopDefinition

    var body: some View {
        MenuSheet(title: shop.name, icon: MenuIcon.art[GameController.symbol(for: shop.kind)],
                  onClose: { game.openShop = nil }) {
            HeaderCoins(amount: game.money)
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(subtitle)
                        .font(Theme.label(13))
                        .foregroundStyle(Theme.inkSoft)
                    switch shop.kind {
                    case .seedShop: seedShop
                    case .market: market
                    case .gasStation: gasStation
                    case .livestock: livestock
                    case .bank: bank
                    }
                }
                .padding(16)
            }
        }
    }

    private var subtitle: String {
        switch shop.kind {
        case .seedShop: "Seeds go to your seed pouch."
        case .market: "Prices change every day."
        case .gasStation: "Fill up before long trips."
        case .livestock: "Animals are delivered to your farm."
        case .bank: "Loans are paid back on Mondays."
        }
    }

    // MARK: Seed shop

    /// Only what the farmer can buy now, or at the next level (the shop grows with you).
    private func isInView(_ unlockLevel: Int) -> Bool { unlockLevel <= game.level + 1 }

    private var seedShop: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(CropCatalog.all.filter { isInView($0.unlockLevel) }) { crop in
                seedRow(crop)
            }
            let saplings = TreeCatalog.all.filter { isInView($0.unlockLevel) }
            if !saplings.isEmpty {
                PageHeading(title: "Saplings")
                Text("Plant them on plowed soil. Wood trees give logs, fruit trees give fruit again and again.")
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(saplings) { tree in
                    saplingRow(tree)
                }
            }
            if CropCatalog.all.contains(where: { !isInView($0.unlockLevel) }) {
                IconLabel("More seeds come in as you level up.", symbol: "sparkles", size: 12)
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.inkSoft)
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
                PaperTag(text: "Level \(tree.unlockLevel)", symbol: "lock.fill")
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
                    MenuIcon(symbol: Theme.seasonSymbol(season), size: 12, tint: Theme.seasonColor(season))
                }
                Text("· \(Format.duration(crop.growthSeconds)) · owned \(owned)")
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.inkSoft)
            }
        } actions: {
            if locked {
                PaperTag(text: "Level \(crop.unlockLevel)", symbol: "lock.fill")
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
            PaperNote(symbol: "shippingbox",
                      text: "The truck bed is empty. Load your harvest at the farm (basket → Load all), then drive back here.")
            priceBoard
        } else {
            let total = cargo.reduce(0) { $0 + game.price(of: $1.id) * (game.cargoItems[$1.id] ?? 0) }
            VStack(spacing: 10) {
                ForEach(cargo) { item in
                    marketRow(item)
                }
            }
            BigButton(title: "Sell everything", price: total, tint: .green) { game.sellAll() }
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
            if game.isMarketSpecial(item.id) { SpecialBadge() }
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
                    if game.isMarketSpecial(item.id) { SpecialBadge() }
                    Spacer()
                    PriceTag(price: game.price(of: item.id), range: item.value)
                }
            }
        }
        .card()
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
            ForEach(AnimalCatalog.all.filter { isInView($0.unlockLevel) }) { species in
                animalRow(species)
            }
            PageHeading(title: "Feed")
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
                PaperTag(text: "Level \(species.unlockLevel)", symbol: "lock.fill")
            } else {
                PriceButton(title: "Buy", price: species.price, enabled: status == nil && game.money >= species.price) {
                    game.buyAnimal(species.id)
                }
            }
        }
    }

    // MARK: Bank

    private var bank: some View {
        let interest = game.balance.loanInterest
        return VStack(alignment: .leading, spacing: 12) {
            if let loan = game.finance.loan {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your loan")
                        .font(Theme.title(18))
                    Text("You owe \(loan.balance) coins: \(loan.weeklyPayment) every Monday for \(loan.weeksLeft) more \(loan.weeksLeft == 1 ? "week" : "weeks").")
                        .font(Theme.label(14))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    let total = max(1, Double(loan.amount) * (1 + interest))
                    HUDBar(fraction: min(1, max(0, total - Double(loan.balance)) / total))
                        .frame(height: 12)
                }
                .foregroundStyle(Theme.ink)
                .card()
                BigButton(title: game.money >= loan.balance ? "Pay it all off now" : "Not enough to pay it off yet",
                          price: loan.balance, tint: game.money >= loan.balance ? .green : .gray) { game.repayLoan() }
                    .disabled(game.money < loan.balance)
            }
            PageHeading(title: "Borrow")
            Text("Get coins now for seeds, animals or repairs. You pay back \(Int((interest * 100).rounded()))% more, a little every Monday with your bills. One loan at a time.")
                .font(Theme.label(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Bank.offers) { offer in
                loanRow(offer, interest: interest)
            }
        }
    }

    private func loanRow(_ offer: LoanOffer, interest: Double) -> some View {
        let locked = game.level < offer.unlockLevel
        let busy = game.finance.loan != nil
        return ShopRow {
            MenuIcon(symbol: "building.columns.fill", size: 36)
                .opacity(locked ? 0.4 : 1)
                .frame(width: 42, height: 42)
        } info: {
            HStack(spacing: 4) {
                CoinIcon(size: 14)
                Text("\(offer.amount)")
                    .font(Theme.number(16))
            }
            Text("\(offer.weeklyPayment(interest: interest)) a week × \(offer.weeks) weeks")
                .font(Theme.label(12))
                .foregroundStyle(Theme.inkSoft)
        } actions: {
            if locked {
                PaperTag(text: "Level \(offer.unlockLevel)", symbol: "lock.fill")
            } else {
                Button("Borrow") { game.takeLoan(offer.amount) }
                    .font(Theme.display(15))
                    .buttonStyle(CandyButtonStyle(tint: busy ? .gray : .green))
                    .disabled(busy)
            }
        }
    }

    // MARK: Gas station

    private var gasStation: some View {
        let cost = game.fullTankCost
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                MenuIcon(symbol: "fuelpump.fill")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tank \(Int((game.fuelFraction * 100).rounded()))%")
                        .font(Theme.label(16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    HUDBar(fraction: game.fuelFraction, color: game.fuelFraction < 0.2 ? HUD.danger : HUD.gold)
                        .frame(height: 12)
                }
            }
            .card()
            if cost <= 0 {
                PaperNote(symbol: "checkmark.circle", text: "The tank is full. Safe travels!")
            } else {
                BigButton(title: game.money >= cost ? "Fill up" : "Fill what I can afford",
                          price: max(0, min(cost, game.money)), tint: .gold) { game.refuel() }
            }
        }
    }
}

// MARK: - Pieces

/// One line in a shop: icon, name and details, buttons, on a paper card.
struct ShopRow<Icon: View, Info: View, Actions: View>: View {
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
        .background(PixelArtFrame(name: "ui_card", border: 4))
    }
}

/// A small "buy/sell N for X coins" button: a paper slot that presses in.
struct PriceButton: View {
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
                    CoinIcon(size: 12)
                    Text("\(price)")
                        .font(Theme.number(11))
                }
            }
            .foregroundStyle(Theme.ink)
            .frame(minWidth: 48, minHeight: 42)
        }
        .buttonStyle(SlotButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}

/// A wide painted board with a price on it.
struct BigButton: View {
    let title: String
    let price: Int
    let tint: CandyTint
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(Theme.display(18))
                Spacer()
                CoinIcon(size: 24)
                Text("\(price)")
                    .font(Theme.number(18))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
        .buttonStyle(CandyButtonStyle(tint: tint))
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
                MenuIcon(symbol: "arrow.up.circle.fill", size: 12)
                    .accessibilityLabel("Good price")
            } else if t <= 0.33 {
                MenuIcon(symbol: "arrow.down.circle.fill", size: 12)
                    .accessibilityLabel("Low price")
            }
        }
    }
}

/// "★ Special": today's market special pays extra.
private struct SpecialBadge: View {
    var body: some View {
        PaperTag(text: "Special", symbol: "star.fill", tint: Theme.goldDark)
    }
}
