import Foundation
import AcresCore

/// The business phone's two tabs.
enum BusinessTab: String, CaseIterable, Identifiable {
    case orders = "Orders"
    case shop = "Shop"
    case farm = "Farm"
    case money = "Money"
    case almanac = "Almanac"
    var id: String { rawValue }
}

/// Monday morning's look back at the week that ended.
struct WeeklyReport: Equatable, Identifiable {
    let week: Int
    let ledger: Ledger
    let billsPaid: Int
    let moneyAfter: Int
    var id: Int { week }
}

extension GameController {
    var contracts: Contracts { Contracts(balance: balance) }

    /// Copies contracts and the books for the UI (only when they change).
    func refreshBusiness() {
        let state = simulation.state
        if contractBoard != state.contracts { contractBoard = state.contracts }
        if finance != state.finance { finance = state.finance }
        if storeState != state.store { storeState = state.store }
        // Workshop timers tick every frame; the copy only changes when something happens.
        var estate = state.estate
        for i in estate.workshops.indices { estate.workshops[i].progress = 0 }
        if estateState != estate { estateState = estate }
        if ownedLand != state.ownedProperties { ownedLand = state.ownedProperties }
        if ownedFields != state.ownedFields { ownedFields = state.ownedFields }
        if almanac != state.almanac { almanac = state.almanac }
        if rankIndex != state.rank.rank { rankIndex = state.rank.rank }
    }

    var today: Int { simulation.state.clock.dayIndex }

    /// Bills due next Monday morning (property tax, loan instalment).
    var upcomingBills: [(category: String, amount: Int)] { Bank.weeklyBills(simulation.state, balance: balance) }

    /// Days until the bills are paid (Monday 06:00).
    var daysUntilBills: Int { 7 - today % 7 }

    // MARK: Contracts

    func acceptContract(_ id: Int) {
        let result = simulation.contracts { try $0.accept(id, state: &$1) }
        switch result {
        case .success:
            Haptics.success()
            advanceTutorial(.acceptedOrder)
            if let contract = simulation.state.contracts.active.first(where: { $0.id == id }), let client = contract.client {
                showMessage("Deal! Bring \(describe(contract.items)) to \(client.name) by \(dueText(contract)).")
            }
            afterBusinessChange()
        case .failure(let failure):
            Haptics.warning()
            showMessage(message(for: failure))
        }
    }

    func declineContract(_ id: Int) {
        _ = simulation.contracts { contracts, state in contracts.decline(id, state: &state) }
        Haptics.tap()
        afterBusinessChange()
    }

    /// Hands over the goods on the truck to the client it's parked at.
    func deliverToNearbyClient() {
        guard let client = nearbyClient else { return }
        guard contractBoard.active.contains(where: { $0.clientID == client.id }) else {
            showMessage("No orders from \(client.name) right now. New orders come in every morning (see your farm journal).")
            businessTab = .orders
            showsBusiness = true
            return
        }
        if isDriving {
            motion = TruckMotion()
            autopilot = nil
            destination = nil
        }
        let result = simulation.contracts { try $0.deliver(to: client.id, state: &$1) }
        switch result {
        case .success(let delivery):
            if delivery.completed.isEmpty {
                Haptics.tap()
                let left = simulation.state.contracts.active.filter { $0.clientID == client.id }
                    .map { contract in contract.items.keys.reduce(0) { $0 + contract.remaining($1) } }
                    .reduce(0, +)
                showMessage("Delivered \(describe(delivery.delivered)). \(left) more to go.")
            } else {
                Haptics.success()
                let reward = delivery.completed.map(\.reward).reduce(0, +)
                showBanner("Order complete! \(client.name) paid \(reward) coins. 🤝")
                Sound.play(.coins)
            }
            if !delivery.events.isEmpty { handle(delivery.events) }
            refreshTruck()
            refreshDisplay()
            save()
        case .failure(let failure):
            Haptics.warning()
            showMessage(message(for: failure, client: client))
        }
    }

    private func afterBusinessChange() {
        refreshBusiness()
        refreshDisplay()
        save()
    }

    func message(for failure: ContractFailure, client: ClientDefinition? = nil) -> String {
        let name = client?.name ?? "the client"
        switch failure {
        case .notFound: return "That order is gone."
        case .tooManyActive: return "You can take \(balance.maxActiveContracts) orders at a time. Finish one first."
        case .notAtClient: return "Drive over to \(name) to deliver."
        case .truckNotHere: return "The goods are in the truck: park it closer to \(name)."
        case .closed(let opens): return "\(name) is closed. It opens at \(String(format: "%02d:00", opens))."
        case .nothingToDeliver:
            let wanted = contractBoard.active.filter { $0.clientID == client?.id }
                .flatMap { contract in contract.sortedItems.filter { contract.remaining($0) > 0 } }
            let names = Array(Set(wanted)).sorted().compactMap { ItemCatalog.item($0)?.plural }
            return names.isEmpty ? "Nothing for this order on you or in the truck."
                : "Nothing for this order on you. They want \(names.joined(separator: ", ")): bring them in your bag or the truck."
        }
    }

    // MARK: Bank

    func takeLoan(_ amount: Int) {
        let result = simulation.trade { try $0.takeLoan(amount, state: &$1) }
        switch result {
        case .success(let loan):
            Haptics.success()
            showBanner("Borrowed \(loan.amount) coins. \(loan.weeklyPayment) a week comes off on Mondays.")
            afterBusinessChange()
        case .failure(let failure):
            Haptics.warning()
            showMessage(message(for: failure))
        }
    }

    func repayLoan() {
        let result = simulation.trade { try $0.repayLoan(state: &$1) }
        switch result {
        case .success(let paid):
            Haptics.success()
            showBanner("Loan paid off (\(paid) coins). Debt free! 🎉")
            afterBusinessChange()
        case .failure(let failure):
            Haptics.warning()
            showMessage(message(for: failure))
        }
    }

    // MARK: Text

    /// "12 carrots and 5 eggs".
    func describe(_ items: [String: Int]) -> String {
        let parts = items.keys.sorted().map { ItemCatalog.describe(items[$0] ?? 0, $0) }
        guard parts.count > 1 else { return parts.first ?? "nothing" }
        return parts.dropLast().joined(separator: ", ") + " and " + parts.last!
    }

    /// "today", "tomorrow", "Thursday".
    func dueText(_ contract: Contract) -> String {
        let days = contract.deadlineDay - today
        switch days {
        case ..<0: return "yesterday"
        case 0: return "tonight"
        case 1: return "tomorrow"
        default: return Weekday(rawValue: contract.deadlineDay % 7)?.name ?? "day \(contract.deadlineDay + 1)"
        }
    }

    /// "Due tomorrow" with how urgent it is (0 = today).
    func daysLeft(_ contract: Contract) -> Int { contract.deadlineDay - today }

    static func symbol(for client: ClientDefinition) -> String {
        switch client.id {
        case "rusty_spoon": "fork.knife"
        case "hansens_bakery": "birthday.cake.fill"
        case "lumber_yard": "tree.fill"
        default: "shippingbox.fill"
        }
    }

    /// The client the truck's cargo is for (earliest deadline first), for the guide arrow.
    var deliveryTarget: Vec2? {
        let cargo = cargoItems
        let next = contractBoard.active.sorted { $0.deadlineDay < $1.deadlineDay }.first { contract in
            contract.items.keys.contains { contract.remaining($0) > 0 && (cargo[$0] ?? 0) > 0 }
        }
        guard let client = next?.client, client != nearbyClient else { return nil }
        return client.zone.center
    }

    /// Pulse the phone while the first-order goal waits for an accepted order.
    var phoneNeedsAttention: Bool {
        !tutorial.isActive && contractBoard.active.isEmpty && !contractBoard.offers.isEmpty
            && openGoals.first?.goal.id == "contract1"
    }
}
