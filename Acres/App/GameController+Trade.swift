import Foundation
import AcresCore

extension GameController {
    var trading: Trading { Trading(balance: balance) }

    /// Opens the shop the truck is stopped at.
    func openNearbyShop() {
        guard let shop = nearbyShop else { return }
        if isDriving {
            motion = TruckMotion()
            autopilot = nil
            joystickInput = nil
            joystick = nil
        }
        openShop = shop
        Haptics.tap()
    }

    /// Today's market price for a crop.
    func price(of cropID: String) -> Int {
        trading.price(of: cropID, in: simulation.state) ?? 0
    }

    var fullTankCost: Int { trading.fullTankCost(simulation.state) }

    // MARK: Actions

    func buySeeds(_ cropID: String, count: Int) {
        let result = simulation.trade { try $0.buySeeds(cropID, count: count, state: &$1) }
        finish(result) { cost in
            Haptics.success()
            let name = CropCatalog.crop(cropID)?.name.lowercased() ?? cropID
            showMessage("Bought \(count) \(name) seeds for \(cost) coins.")
            advanceTutorial(.boughtSeeds)
        }
    }

    func sell(_ itemID: String, count: Int) {
        let result = simulation.trade { try $0.sell(itemID, count: count, state: &$1) }
        finish(result) { earned in
            Haptics.success()
            showMessage("Sold for \(earned) coins!")
            advanceTutorial(.sold)
        }
    }

    func sellAll() {
        let result = simulation.trade { try $0.sellAll(state: &$1) }
        finish(result) { earned in
            Haptics.success()
            showMessage("Sold everything for \(earned) coins!")
            advanceTutorial(.sold)
        }
    }

    func refuel() {
        let result = simulation.trade { try $0.refuel(state: &$1) }
        finish(result) { fill in
            Haptics.success()
            showMessage("Filled up for \(fill.cost) coins.")
        }
    }

    func load(_ itemID: String, count: Int) {
        let result = simulation.trade { try $0.load(itemID, count: count, state: &$1) }
        finish(result) { moved in
            Haptics.tap()
            showMessage("Loaded \(moved) into the truck.")
            advanceTutorial(.loaded)
        }
    }

    func loadAll() {
        let result = simulation.trade { try $0.loadAll(state: &$1) }
        finish(result) { moved in
            Haptics.success()
            showMessage("Loaded \(moved) into the truck. Off to market!")
            advanceTutorial(.loaded)
        }
    }

    func unload(_ itemID: String, count: Int) {
        let result = simulation.trade { try $0.unload(itemID, count: count, state: &$1) }
        finish(result) { _ in Haptics.tap() }
    }

    // MARK: Helpers

    private func finish<T>(_ result: Result<T, TradeFailure>, onSuccess: (T) -> Void) {
        switch result {
        case .success(let value):
            onSuccess(value)
            refreshDisplay()
            refreshInventory()
            refreshTruck()
            save()
        case .failure(let failure):
            Haptics.warning()
            showMessage(message(for: failure))
        }
    }

    func message(for failure: TradeFailure) -> String {
        switch failure {
        case .notAtShop(.seedShop): "Drive to the seed shop to buy seeds."
        case .notAtShop(.market): "Drive to the market to sell."
        case .notAtShop(.gasStation): "Drive to the gas station to fill up."
        case .notAtFarm: "Park the truck at your farm to load it."
        case .notEnoughMoney: "Not enough coins."
        case .locked(let level): "Unlocks at level \(level)."
        case .unknownItem: "Nothing to move."
        case .nothingToSell: "The truck is empty. Load your harvest at the farm."
        case .cargoFull: "The truck bed is full."
        case .storageFull: "Farm storage is full."
        case .tankFull: "The tank is already full."
        }
    }
}
