import SwiftUI
import AcresCore

/// The corner shop: rent it, stock the shelves from the truck, set prices.
struct StoreView: View {
    let game: GameController
    @State private var confirmsEndLease = false

    private var store: StoreDefinition { .corner }
    private var state: StoreState { game.storeState }

    var body: some View {
        MenuSheet(title: state.isRented ? "Your shop" : store.name, icon: "ui_icon_shop",
                  onClose: { game.showsStore = false }) {
            HeaderCoins(amount: game.money)
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if state.isRented { rented } else { forRent }
                }
                .padding(16)
            }
        }
        .paperConfirm("Give up the shop?", isPresented: $confirmsEndLease,
                      message: "No more rent from next Monday. You can rent it again later.",
                      confirmTitle: "Give it up", destructive: true) {
            game.endLease()
        }
    }

    // MARK: For rent

    private var forRent: some View {
        let locked = game.level < game.balance.storeUnlockLevel
        let first = game.firstRent
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                MenuIcon(symbol: "storefront.fill", size: 48)
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
                PaperNote(symbol: "lock.fill", text: "The landlord rents to farmers of level \(game.balance.storeUnlockLevel) and up.")
            } else {
                BigButton(title: "Rent the shop", price: first, tint: game.money >= first ? .green : .gray) {
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
            PaperNote(symbol: "truck.pickup.side", text: "Park the truck in front of the shop to stock the shelves or take goods back.")
        } else if goods.isEmpty {
            PaperNote(symbol: "shippingbox", text: "Nothing to sell on the truck. Load your harvest at the farm and bring it here.")
        } else {
            let total = goods.reduce(0) { $0 + (game.cargoItems[$1.id] ?? 0) }
            Button { game.stockAll() } label: {
                HStack {
                    MenuIcon(symbol: "tray.and.arrow.down.fill")
                    Text("Stock everything from the truck")
                        .font(Theme.display(17))
                    Spacer()
                    Text("\(total)")
                        .font(Theme.number(17))
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(CandyButtonStyle(tint: .green))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(goods) { item in
                        Button { game.stock(item.id) } label: {
                            HStack(spacing: 6) {
                                ItemIcon(name: item.icon, size: 24)
                                Text("×\(game.cargoItems[item.id] ?? 0)")
                                    .font(Theme.number(13))
                                    .foregroundStyle(Theme.ink)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(SlotButtonStyle())
                        .accessibilityLabel("Stock \(item.name)")
                    }
                }
            }
        }

        PageHeading(title: "Shelves")
        ForEach(Array(state.shelves.enumerated()), id: \.offset) { index, shelf in
            ShelfCard(game: game, shelf: shelf, index: index, editable: true, truckHere: truckHere)
        }
        Text("Tip: about 25% over the usual price earns the most per hour. A wider choice of goods brings more customers.")
            .font(Theme.label(12))
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)

        if state.totalStock == 0 {
            Button("Give up the shop…") { confirmsEndLease = true }
                .font(Theme.display(14))
                .buttonStyle(CandyButtonStyle(tint: .red))
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
            MenuIcon(symbol: open ? "door.left.hand.open" : "door.left.hand.closed")
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
                        HUDBar(fraction: Double(shelf.stock) / Double(max(1, capacity)), color: shelf.stock > 4 ? HUD.xp : HUD.danger)
                            .frame(height: 10)
                    }
                }
                HStack(spacing: 8) {
                    if editable {
                        stepButton("−", enabled: shelf.priceFactor > game.balance.storePriceFactorRange.lowerBound + 1e-6) {
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
                        stepButton("+", enabled: shelf.priceFactor < game.balance.storePriceFactorRange.upperBound - 1e-6) {
                            game.adjustPrice(shelf: index, by: 1)
                        }
                    }
                    Spacer()
                    Text(shelf.stock > 0 ? "~\(Int(perDay.rounded())) a day" : "")
                        .font(Theme.label(12))
                        .foregroundStyle(Theme.inkSoft)
                    if editable && truckHere && shelf.stock > 0 {
                        Button("Take back") { game.takeBack(shelf: index) }
                            .font(Theme.label(12, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 6)
                            .frame(height: 30)
                            .buttonStyle(SlotButtonStyle())
                    }
                }
                .foregroundStyle(Theme.ink)
            }
            .foregroundStyle(Theme.ink)
            .card()
        } else {
            HStack(spacing: 10) {
                InsetPanel()
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

    private func stepButton(_ sign: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(sign)
                .font(HUD.font(18, .black))
                .foregroundStyle(Theme.ink)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(SlotButtonStyle())
        .accessibilityLabel(sign == "+" ? "Raise the price" : "Lower the price")
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}
