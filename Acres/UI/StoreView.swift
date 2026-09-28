import SwiftUI
import AcresCore

/// The corner shop: rent it, stock the shelves from the truck, set prices.
struct StoreView: View {
    let game: GameController
    @State private var confirmsEndLease = false

    private var store: StoreDefinition { .corner }
    private var state: StoreState { game.storeState }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if state.isRented { rented } else { forRent }
                }
                .padding(16)
            }
            .background(PaperBackground())
            .navigationTitle(state.isRented ? "Your shop" : store.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { game.showsStore = false }
                }
            }
            .confirmationDialog("Give up the shop?", isPresented: $confirmsEndLease, titleVisibility: .visible) {
                Button("Give it up", role: .destructive) { game.endLease() }
            } message: {
                Text("No more rent from next Monday. You can rent it again later.")
            }
        }
    }

    // MARK: For rent

    private var forRent: some View {
        let locked = game.level < game.balance.storeUnlockLevel
        let first = game.firstRent
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.leafDark)
                VStack(alignment: .leading, spacing: 2) {
                    Text("For rent")
                        .font(Theme.title(20))
                    Text("A little shop on the village street")
                        .font(Theme.label(13))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .foregroundStyle(Theme.ink)

            Text("Sell your own harvest to the villagers. You set the prices: cheaper sells faster, dearer earns more on each sale. The shop is open \(hours) while you play.")
                .font(Theme.label(15))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 6) {
                fact("Rent", "\(game.balance.storeRentPerWeek) coins a week, on Mondays")
                fact("First payment", "\(first) coins (until Monday)")
                fact("Shelves", "\(game.balance.storeShelves) shelves of \(game.balance.storeShelfCapacity)")
            }
            .card()

            if locked {
                Label("The landlord rents to farmers of level \(game.balance.storeUnlockLevel) and up.", systemImage: "lock.fill")
                    .font(Theme.label(14, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            } else {
                BigButton(title: "Rent the shop", price: first, tint: game.money >= first ? Theme.leafDark : Color.gray) {
                    game.rentStore()
                }
                .disabled(game.money < first)
            }
        }
    }

    private func fact(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name)
                .font(Theme.label(14, weight: .semibold))
            Spacer()
            Text(value)
                .font(Theme.label(14))
                .foregroundStyle(Theme.inkSoft)
        }
        .foregroundStyle(Theme.ink)
    }

    private var hours: String { "\(String(format: "%02d", store.opens)):00–\(String(format: "%02d", store.closes)):00" }

    // MARK: Rented

    @ViewBuilder
    private var rented: some View {
        StoreTakings(game: game)

        let truckHere = game.storekeeping.truckIsHere(game.simulation.state)
        let goods = truckGoods
        if !truckHere {
            EmptyNote(symbol: "truck.pickup.side", text: "Park the truck in front of the shop to stock the shelves or take goods back.")
        } else if goods.isEmpty {
            EmptyNote(symbol: "shippingbox", text: "Nothing to sell on the truck. Load your harvest at the farm and bring it here.")
        } else {
            let total = goods.reduce(0) { $0 + (game.cargoItems[$1.id] ?? 0) }
            Button { game.stockAll() } label: {
                HStack {
                    Image(systemName: "tray.and.arrow.down.fill")
                    Text("Stock everything from the truck")
                        .font(Theme.label(17, weight: .semibold))
                    Spacer()
                    Text("\(total)")
                        .font(Theme.number(17))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.leafDark))
            }
            .buttonStyle(.plain)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(goods) { item in
                        Button { game.stock(item.id) } label: {
                            HStack(spacing: 6) {
                                ItemIcon(name: item.icon, size: 26)
                                Text("×\(game.cargoItems[item.id] ?? 0)")
                                    .font(Theme.number(13))
                                    .foregroundStyle(Theme.ink)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Theme.parchmentDark.opacity(0.7)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Stock \(item.name)")
                    }
                }
            }
        }

        Text("Shelves")
            .font(Theme.title(19))
            .foregroundStyle(Theme.ink)
            .padding(.top, 4)
        ForEach(Array(state.shelves.enumerated()), id: \.offset) { index, shelf in
            ShelfCard(game: game, shelf: shelf, index: index, editable: true, truckHere: truckHere)
        }
        Text("Tip: about 25% over the usual price earns the most per hour. A wider choice of goods brings more customers.")
            .font(Theme.label(12))
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)

        if state.totalStock == 0 {
            Button("Give up the shop…") { confirmsEndLease = true }
                .font(Theme.label(14, weight: .semibold))
                .foregroundStyle(Theme.danger)
                .padding(.top, 8)
        }
    }

    /// Sellable goods in the truck bed.
    private var truckGoods: [ItemDefinition] {
        ItemCatalog.all.filter { $0.category.isSellable && (game.cargoItems[$0.id] ?? 0) > 0 }
    }
}

/// Today's takings and whether the shop is open.
struct StoreTakings: View {
    let game: GameController

    var body: some View {
        let store = StoreDefinition.corner
        let open = store.isOpen(atHour: game.hour)
        let today = game.storeState.today
        let week = game.finance.thisWeek.income[LedgerCategory.shopSales] ?? 0
        HStack(spacing: 12) {
            Image(systemName: open ? "door.left.hand.open" : "door.left.hand.closed")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(open ? Theme.leafDark : Theme.inkSoft)
            VStack(alignment: .leading, spacing: 3) {
                Text(open ? "Open until \(store.closes):00" : "Closed · opens \(String(format: "%02d", store.opens)):00")
                    .font(Theme.label(15, weight: .semibold))
                Text("Today \(today.items) sold · this week \(week) coins")
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            HStack(spacing: 3) {
                CoinIcon(size: 16)
                Text("\(today.coins)")
                    .font(Theme.number(18))
            }
        }
        .foregroundStyle(Theme.ink)
        .card()
    }
}

/// One shelf: the goods, how many are left, the price and how fast it sells.
struct ShelfCard: View {
    let game: GameController
    let shelf: Shelf
    let index: Int
    /// Price buttons and "take back" (only when standing in the shop).
    let editable: Bool
    var truckHere = false

    var body: some View {
        let capacity = game.balance.storeShelfCapacity
        if let itemID = shelf.itemID, let item = ItemCatalog.item(itemID) {
            let perDay = game.salesPerDay(shelf)
            let price = game.unitPrice(itemID, factor: shelf.priceFactor)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ItemIcon(name: item.icon, size: 34)
                        .opacity(shelf.stock > 0 ? 1 : 0.4)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(item.name)
                                .font(Theme.label(15, weight: .semibold))
                            Spacer()
                            Text(shelf.stock > 0 ? "\(shelf.stock)/\(capacity)" : "Sold out")
                                .font(Theme.number(13))
                                .foregroundStyle(shelf.stock > 0 ? Theme.inkSoft : Theme.danger)
                        }
                        ProgressView(value: Double(shelf.stock), total: Double(capacity))
                            .tint(shelf.stock > 4 ? Theme.leaf : Theme.danger)
                    }
                }
                HStack(spacing: 8) {
                    if editable {
                        stepButton("minus", enabled: shelf.priceFactor > game.balance.storePriceFactorRange.lowerBound + 1e-6) {
                            game.adjustPrice(shelf: index, by: -1)
                        }
                    }
                    HStack(spacing: 3) {
                        CoinIcon(size: 13)
                        Text("\(price)")
                            .font(Theme.number(15))
                        Text(markup)
                            .font(Theme.label(12))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    if editable {
                        stepButton("plus", enabled: shelf.priceFactor < game.balance.storePriceFactorRange.upperBound - 1e-6) {
                            game.adjustPrice(shelf: index, by: 1)
                        }
                    }
                    Spacer()
                    Text(shelf.stock > 0 ? "~\(Int(perDay.rounded())) a day" : "")
                        .font(Theme.label(12))
                        .foregroundStyle(Theme.inkSoft)
                    if editable && truckHere && shelf.stock > 0 {
                        Button("Take back") { game.takeBack(shelf: index) }
                            .font(Theme.label(12, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .foregroundStyle(Theme.ink)
            }
            .foregroundStyle(Theme.ink)
            .card()
        } else {
            HStack(spacing: 10) {
                Image(systemName: "square.dashed")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 34, height: 34)
                Text("Empty shelf")
                    .font(Theme.label(15))
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
            }
            .card()
        }
    }

    /// "usual price", "+25%", "−20%".
    private var markup: String {
        let percent = Int(((shelf.priceFactor - 1) * 100).rounded())
        if percent == 0 { return "usual" }
        return percent > 0 ? "+\(percent)%" : "−\(-percent)%"
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 34, height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.parchment))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}
