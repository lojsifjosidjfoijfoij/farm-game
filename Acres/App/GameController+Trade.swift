import Foundation
import AcresCore

extension GameController {
    var trading: Trading { Trading(balance: balance) }

    /// Opens the shop the truck is stopped at.
    func openNearbyShop() {
        guard let shop = nearbyShop else { return }
        guard shop.isOpen(atHour: simulation.state.clock.hour) else {
            showMessage("\(shop.name) is closed. It opens at \(String(format: "%02d:00", shop.opens)).")
            Haptics.warning()
            return
        }
        if isDriving {
            motion = TruckMotion()
            autopilot = nil
            destination = nil
        }
        openShop = shop
        Haptics.tap()
    }

    /// Today's market price for anything the market buys.
    func price(of itemID: String) -> Int {
        trading.price(of: itemID, in: simulation.state) ?? 0
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

    func buySaplings(_ treeID: String, count: Int) {
        let result = simulation.trade { try $0.buySaplings(treeID, count: count, state: &$1) }
        finish(result) { cost in
            Haptics.success()
            let name = TreeCatalog.species(treeID)?.name.lowercased() ?? treeID
            showMessage("Bought \(count) \(name) \(count == 1 ? "sapling" : "saplings") for \(cost) coins. Plant them on plowed soil.")
        }
    }

    func buyAnimal(_ speciesID: String) {
        let result = simulation.trade { try $0.buyAnimal(speciesID, state: &$1) }
        finish(result) { animal in
            Haptics.success()
            let young = animal.species?.youngName.lowercased() ?? "animal"
            showMessage("Say hello to \(animal.name) the \(young)! They're waiting at your farm.")
            farmRevision += 1
        }
    }

    func buyFeed(count: Int) {
        let result = simulation.trade { try $0.buyFeed(count: count, state: &$1) }
        finish(result) { cost in
            Haptics.success()
            showMessage("Bought \(count) sacks of feed for \(cost) coins.")
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
        case .notAtShop(.livestock): "Drive to the livestock market."
        case .penNotRepaired(let penID): "Fix up the \(PenCatalog.pen(penID)?.name.lowercased() ?? "pen") at your farm first."
        case .penFull(let penID): "The \(PenCatalog.pen(penID)?.name.lowercased() ?? "pen") is full."
        case .closed(let opens): "Closed for the night. Opens at \(String(format: "%02d:00", opens))."
        case .truckNotHere(.market): "Bring the truck: your goods are in the truck bed."
        case .truckNotHere: "Bring the truck to fill it up."
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
