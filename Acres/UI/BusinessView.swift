import SwiftUI
import AcresCore

/// The farm journal: orders from clients, the farm's money (this week's
/// books, Monday's bills, the loan), the farm's plans and the almanac. A
/// leather-bound book: a stitched leather band on top, paper tabs, pages.
struct BusinessView: View {
    @Bindable var game: GameController

    /// "Are you sure?" from a page (buying land, letting a farmhand go).
    @State private var confirm: ConfirmRequest?

    var body: some View {
        MenuSheet(title: "Farm journal", icon: "ui_icon_journal", onClose: { game.showsBusiness = false }) {
            HeaderCoins(amount: game.money)
        } content: {
            VStack(spacing: 0) {
                PaperTabs(tabs: game.businessTabs, selection: Binding(get: { shownTab }, set: { game.businessTab = $0 }),
                          title: { $0.rawValue })
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        switch shownTab {
                        case .orders: orders
                        case .shop: shop
                        case .farm: FarmTabView(game: game) { confirm = $0 }
                        case .money: money
                        case .almanac: AlmanacTabView(game: game)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .paperConfirm($confirm)
    }

    /// A tab that isn't open yet falls back to the orders.
    private var shownTab: BusinessTab {
        game.businessTabs.contains(game.businessTab) ? game.businessTab : .orders
    }

    // MARK: Orders

    @ViewBuilder
    private var orders: some View {
        let board = game.contractBoard
        reputation(board.reputation)

        PageHeading(title: "Your orders", trailing: "\(board.active.count) of \(game.balance.maxActiveContracts)")
        if board.active.isEmpty {
            PaperNote(symbol: "shippingbox",
                      text: "No orders yet. Accept one below, load the goods in your truck at the farm, and deliver them before the deadline.")
        } else {
            ForEach(board.active) { contract in
                ContractCard(game: game, contract: contract, isOffer: false)
            }
        }

        PageHeading(title: "New orders", trailing: nil)
        if board.offers.isEmpty {
            PaperNote(symbol: "moon.stars", text: "No new orders today. Clients send word every morning.")
        } else {
            ForEach(board.offers) { contract in
                ContractCard(game: game, contract: contract, isOffer: true)
            }
        }
        Text("Offers stay up for two days. Missing a deadline costs reputation.")
            .font(Theme.label(12))
            .foregroundStyle(Theme.inkSoft)
    }

    private func reputation(_ value: Int) -> some View {
        HStack(spacing: 12) {
            MenuIcon(symbol: "star.bubble.fill")
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Reputation")
                        .font(Theme.label(15, weight: .semibold))
                    Spacer()
                    Text("\(value)/100")
                        .font(Theme.number(14))
                        .foregroundStyle(Theme.inkSoft)
                }
                HUDBar(fraction: Double(value) / 100, color: HUD.gold)
                    .frame(height: 12)
                Text("Reliable farms get bigger, better-paid orders.")
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .foregroundStyle(Theme.ink)
        .card()
    }

    // MARK: Shop

    @ViewBuilder
    private var shop: some View {
        let state = game.storeState
        if state.isRented {
            StoreTakings(game: game)
            ForEach(Array(state.shelves.enumerated()), id: \.offset) { index, shelf in
                ShelfCard(game: game, shelf: shelf, index: index, editable: false)
            }
            Text("Drive to your shop to restock the shelves or change prices.")
                .font(Theme.label(12))
                .foregroundStyle(Theme.inkSoft)
        } else {
            PaperNote(symbol: "storefront",
                      text: "The corner shop between the gas station and the seed shop is for rent (from level \(game.balance.storeUnlockLevel)). Sell your own goods at your own prices.")
        }
    }

    // MARK: Money

    @ViewBuilder
    private var money: some View {
        let finance = game.finance
        cash

        LedgerCard(title: "This week", subtitle: "Week \(finance.thisWeek.week)", ledger: finance.thisWeek, detailed: true)

        bills

        if let loan = finance.loan {
            VStack(alignment: .leading, spacing: 6) {
                IconLabel("Bank loan", symbol: "building.columns.fill")
                    .font(Theme.label(15, weight: .semibold))
                Text("\(loan.balance) coins left · \(loan.weeklyPayment) a week for \(loan.weeksLeft) more \(loan.weeksLeft == 1 ? "week" : "weeks"). You can pay it off early at the bank.")
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.ink)
            .card()
        }

        if let last = finance.lastWeek {
            LedgerCard(title: "Last week", subtitle: "Week \(last.week)", ledger: last, detailed: false)
        }
    }

    private var cash: some View {
        let debt = game.money < 0
        return HStack(spacing: 10) {
            CoinIcon(size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(game.money, format: .number)
                    .font(Theme.number(24))
                    .foregroundStyle(debt ? Theme.danger : Theme.ink)
                Text(debt ? "In debt: you can't buy anything until you're back above zero." : "Coins in the bank")
                    .font(Theme.label(12))
                    .foregroundStyle(debt ? Theme.danger : Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .card()
    }

    private var bills: some View {
        let bills = game.upcomingBills
        let total = bills.map(\.amount).reduce(0, +)
        let days = game.daysUntilBills
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                IconLabel("Monday's bills", symbol: "doc.text.fill")
                    .font(Theme.label(15, weight: .semibold))
                Spacer()
                Text(days == 1 ? "tomorrow" : "in \(days) days")
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.inkSoft)
            }
            ForEach(bills, id: \.category) { bill in
                LedgerLine(name: bill.category, amount: -bill.amount)
            }
            PixelRule()
            LedgerLine(name: "Total", amount: -total, bold: true)
            if game.money < total {
                Text("Not enough coins yet: short bills go on as debt.")
                    .font(Theme.label(12, weight: .semibold))
                    .foregroundStyle(Theme.danger)
            }
        }
        .foregroundStyle(Theme.ink)
        .card()
    }
}

// MARK: - Pieces

/// One order: who, what (with progress), the pay and the deadline.
private struct ContractCard: View {
    let game: GameController
    let contract: Contract
    let isOffer: Bool

    var body: some View {
        let client = contract.client
        let daysLeft = game.daysLeft(contract)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    PixelFrame(.slot)
                    MenuIcon(symbol: client.map(GameController.symbol(for:)) ?? "shippingbox.fill")
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(client?.name ?? contract.clientID)
                        .font(Theme.label(16, weight: .semibold))
                    Text(client.map { "\($0.kind) · open \(String(format: "%02d", $0.opens))–\(String(format: "%02d", $0.closes))" } ?? "")
                        .font(Theme.label(12))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                HStack(spacing: 3) {
                    CoinIcon(size: 24)
                    Text("\(contract.reward)")
                        .font(Theme.number(17))
                }
            }

            ForEach(contract.sortedItems, id: \.self) { item in
                itemLine(item)
            }

            HStack(spacing: 6) {
                MenuIcon(symbol: "clock.fill", size: 12)
                Text(isOffer ? "\(contract.deadlineDay - contract.offeredDay) days to deliver" : "Due \(game.dueText(contract))")
                    .font(Theme.label(13, weight: .semibold))
                    .foregroundStyle(daysLeft <= 0 && !isOffer ? Theme.danger : Theme.inkSoft)
                Text("· +\(contract.xp) XP")
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
            }

            if isOffer {
                HStack(spacing: 10) {
                    Button { game.declineContract(contract.id) } label: {
                        Text("Not now").frame(maxWidth: .infinity)
                    }
                    .font(Theme.display(15))
                    .buttonStyle(CandyButtonStyle(tint: .wood))
                    Button { game.acceptContract(contract.id) } label: {
                        Text("Accept").frame(maxWidth: .infinity)
                    }
                    .font(Theme.display(15))
                    .buttonStyle(CandyButtonStyle(tint: canAccept ? .green : .gray))
                    .disabled(!canAccept)
                }
            } else if game.isDriving, let client {
                Button {
                    game.showsBusiness = false
                    game.drive(to: Destination(id: client.id, name: client.name, symbol: "", target: client.zone.center))
                } label: {
                    IconLabel("Drive there", symbol: "location.fill")
                        .font(Theme.display(15))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CandyButtonStyle(tint: .gold))
            }
        }
        .foregroundStyle(Theme.ink)
        .card()
    }

    private var canAccept: Bool { game.contractBoard.active.count < game.balance.maxActiveContracts }

    private func itemLine(_ item: String) -> some View {
        let definition = ItemCatalog.item(item)
        let ordered = contract.items[item] ?? 0
        let delivered = contract.delivered[item] ?? 0
        let onTruck = game.cargoItems[item] ?? 0
        let atFarm = game.inventoryItems[item] ?? 0
        return HStack(spacing: 10) {
            ItemIcon(name: definition?.icon ?? "item_\(item)", size: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(isOffer ? ItemCatalog.describe(ordered, item) : "\(delivered)/\(ordered) \(definition?.plural ?? item)")
                    .font(Theme.label(14, weight: .semibold))
                if !isOffer {
                    HUDBar(fraction: Double(delivered) / Double(max(1, ordered)))
                        .frame(height: 10)
                }
            }
            Spacer()
            Text(have(onTruck: onTruck, atFarm: atFarm))
                .font(Theme.label(12))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.trailing)
        }
    }

    private func have(onTruck: Int, atFarm: Int) -> String {
        var parts: [String] = []
        if onTruck > 0 { parts.append("\(onTruck) on truck") }
        if atFarm > 0 { parts.append("\(atFarm) at farm") }
        return parts.isEmpty ? "none yet" : parts.joined(separator: "\n")
    }
}

/// A week of income and expenses by category.
private struct LedgerCard: View {
    let title: String
    let subtitle: String
    let ledger: Ledger
    let detailed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(Theme.label(15, weight: .semibold))
                Spacer()
                Text(subtitle)
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.inkSoft)
            }
            if detailed {
                if ledger.income.isEmpty && ledger.expenses.isEmpty {
                    Text("Nothing yet this week.")
                        .font(Theme.label(13))
                        .foregroundStyle(Theme.inkSoft)
                }
                ForEach(ledger.income.sorted { $0.value > $1.value }, id: \.key) { entry in
                    LedgerLine(name: entry.key, amount: entry.value)
                }
                ForEach(ledger.expenses.sorted { $0.value > $1.value }, id: \.key) { entry in
                    LedgerLine(name: entry.key, amount: -entry.value)
                }
            } else {
                LedgerLine(name: "Income", amount: ledger.totalIncome)
                LedgerLine(name: "Expenses", amount: -ledger.totalExpenses)
            }
            PixelRule()
            LedgerLine(name: "Profit", amount: ledger.profit, bold: true)
        }
        .foregroundStyle(Theme.ink)
        .card()
    }
}

/// "Market sales   +320".
struct LedgerLine: View {
    let name: String
    let amount: Int
    var bold = false

    var body: some View {
        HStack {
            Text(name)
                .font(Theme.label(14, weight: bold ? .bold : .regular))
            Spacer()
            Text(amount > 0 ? "+\(amount)" : "\(amount)")
                .font(Theme.number(14))
                .foregroundStyle(amount < 0 ? Theme.danger : (amount > 0 ? Theme.leafDark : Theme.inkSoft))
        }
    }
}

/// Monday morning: how last week went and what the bills took.
struct WeeklyReportCard: View {
    let report: WeeklyReport
    let onClose: () -> Void

    var body: some View {
        RewardCard(ribbon: "WEEK \(report.week) DONE", tint: .blue, celebrates: false) {
            VStack(spacing: 6) {
                LedgerLine(name: "Earned", amount: report.ledger.totalIncome)
                LedgerLine(name: "Spent", amount: -report.ledger.totalExpenses)
                PixelRule()
                LedgerLine(name: "Profit", amount: report.ledger.profit, bold: true)
                LedgerLine(name: "Bills paid this morning", amount: -report.billsPaid)
            }
            .padding(12)
            .background(InsetPanel())
            HStack(spacing: 6) {
                CoinIcon(size: 20)
                Text("\(report.moneyAfter) coins")
                    .font(Theme.number(18))
                    .foregroundStyle(report.moneyAfter < 0 ? Theme.danger : Theme.ink)
            }
            if report.moneyAfter < 0 {
                Text("You're in debt. Sell some goods or finish an order to get back on your feet.")
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.danger)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            RewardButton(title: "New week, let's go", action: onClose)
        }
        .foregroundStyle(Theme.ink)
    }
}
