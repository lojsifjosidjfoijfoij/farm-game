import Foundation
import AcresCore

extension GameController {
    var storekeeping: Storekeeping { Storekeeping(balance: balance) }

    /// Opens the shop sheet (the farmer is at the corner shop).
    func openNearbyStore() {
        guard nearbyStore != nil else { return }
        if isDriving {
            motion = TruckMotion()
            autopilot = nil
            destination = nil
        }
        showsSeedPicker = false
        showsStore = true
        Haptics.tap()
    }

    var firstRent: Int { storekeeping.firstRent(simulation.state) }

    /// Items one shelf sells in a day at its current price (for the UI).
    func salesPerDay(_ shelf: Shelf) -> Double {
        storekeeping.salesPerHour(shelf, in: storeState) * storekeeping.openHours
    }

    func unitPrice(_ itemID: String, factor: Double = 1) -> Int { storekeeping.unitPrice(itemID, factor: factor) }

    // MARK: Actions

    func rentStore() {
        let result = simulation.store { try $0.rent(state: &$1) }
        finishStore(result) { cost in
            Haptics.success()
            showBanner("The corner shop is yours! Paid \(cost) coins rent until Monday. Stock the shelves from your truck.")
        }
    }

    func endLease() {
        let result = simulation.store { try $0.endLease(state: &$1) }
        finishStore(result) { _ in
            Haptics.tap()
            showsStore = false
            showMessage("You gave the shop back. No more rent from next Monday.")
        }
    }

    func stock(_ itemID: String) {
        let result = simulation.store { try $0.stock(itemID, state: &$1) }
        finishStore(result) { moved in
            Haptics.success()
            showMessage("Put \(ItemCatalog.describe(moved, itemID)) on the shelves.")
        }
    }

    func stockAll() {
        let result = simulation.store { try $0.stockAll(state: &$1) }
        finishStore(result) { moved in
            Haptics.success()
            showMessage("Stocked \(moved) items. Customers come in 09:00–18:00.")
        }
    }

    func takeBack(shelf index: Int) {
        let result = simulation.store { try $0.takeBack(shelf: index, state: &$1) }
        finishStore(result) { moved in
            Haptics.tap()
            showMessage("Put \(moved) back in the truck.")
        }
    }

    /// Nudges a shelf's price up or down by 5%.
    func adjustPrice(shelf index: Int, by steps: Int) {
        guard storeState.shelves.indices.contains(index) else { return }
        let factor = storeState.shelves[index].priceFactor + Double(steps) * 0.05
        let result = simulation.store { try $0.setPrice(shelf: index, factor: factor, state: &$1) }
        finishStore(result) { _ in Haptics.selection() }
    }

    private func finishStore<T>(_ result: Result<T, StoreFailure>, onSuccess: (T) -> Void) {
        switch result {
        case .success(let value):
            onSuccess(value)
            refreshBusiness()
            refreshDisplay()
            refreshTruck()
            save()
        case .failure(let failure):
            Haptics.warning()
            showMessage(message(for: failure))
        }
    }

    func message(for failure: StoreFailure) -> String {
        switch failure {
        case .notAtStore: "Go to the corner shop in the village first."
        case .truckNotHere: "Bring the truck: the goods ride in the truck bed."
        case .notRented: "Rent the shop first."
        case .alreadyRented: "The shop is already yours."
        case .locked(let level): "The landlord wants an experienced farmer: come back at level \(level)."
        case .notEnoughMoney: money < 0 ? "You're in debt. Earn some coins first." : "Not enough coins for the first rent."
        case .notSellable: "Customers don't buy that."
        case .nothingToStock: "Nothing to put on the shelves. Load goods into the truck at the farm."
        case .shelvesFull: "The shelves are full."
        case .cargoFull: "The truck bed is full."
        case .shelvesNotEmpty: "Clear the shelves first (take the goods back into the truck)."
        case .unknownShelf: "That shelf doesn't exist."
        }
    }
}
