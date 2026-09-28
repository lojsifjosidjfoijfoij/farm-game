import Foundation
import AcresCore

extension GameController {
    var estateRules: EstateRules { EstateRules(map: map, balance: balance) }

    // MARK: Land, upgrades, machines

    func buyLand(_ id: String) {
        let name = PropertyCatalog.property(id)?.name ?? "the land"
        runEstate({ try $0.buyLand(id, state: &$1) }) { price in
            Haptics.success()
            showBanner("\(name) is yours! (\(price) coins) Plow it, plant it, fill it. 🌾")
            farmRevision += 1
        }
    }

    // MARK: Fields

    static let notAFieldMessage = "Crops only grow in your fields (the marked patches). More fields are on your phone → Farm."

    /// Fields on your land that aren't yours yet (to buy now or later).
    var fieldsForSale: [FieldDefinition] { estateRules.fieldsForSale(simulation.state) }

    func buyField(_ id: String) {
        guard let field = FieldCatalog.field(id) else { return }
        runEstate({ try $0.buyField(id, state: &$1) }) { _ in
            Haptics.success()
            Sound.play(.coins)
            showBanner("\(field.name) is ready: \(field.tileCount) more tiles to farm! 🌱")
            onWorldReset?()  // its border appears
        }
    }

    /// The card for a field you could buy (tapping it on your land).
    func fieldInspection(_ tile: TileCoord) -> TileInspection? {
        // Fields for later levels aren't there yet (the farm opens up as you level).
        guard let field = FieldCatalog.field(containing: tile), !simulation.state.ownedFields.contains(field.id),
              simulation.state.ownedProperties.contains(field.propertyID), level >= field.unlockLevel else { return nil }
        return TileInspection(target: .tile(tile), title: "\(field.name) for sale",
                              detail: "\(field.tileCount) more tiles to farm for \(field.price) coins.", icon: nil,
                              symbol: "square.grid.3x3.fill", action: .buyField(field.id), actionTitle: "Buy · \(field.price)")
    }

    func upgradeStorage() {
        runEstate({ try $0.upgradeStorage(state: &$1) }) { _ in
            Haptics.success()
            showBanner("Storage upgraded: room for \(storageCapacity) now.")
            onWorldReset?()  // the new building appears
        }
    }

    func upgradeTruckBed() {
        runEstate({ try $0.upgradeTruckBed(state: &$1) }) { _ in
            Haptics.success()
            showBanner("A bigger truck bed: \(truckCapacity) items per trip.")
        }
    }

    func buyMachine(_ id: String) {
        let name = ItemCatalog.item(id)?.name.lowercased() ?? "machine"
        let isWorkshop = WorkshopCatalog.workshop(id) != nil
        runEstate({ try $0.buyMachine(id, state: &$1) }) { _ in
            Haptics.success()
            showMessage(isWorkshop ? "A \(name) was delivered. Tap Place to set it up on your land."
                : "A \(name) was delivered to your farm. Tap Place to put it in a field.")
        }
    }

    /// Starts placing a machine from the pouch: the next tap on your land puts it there.
    func startPlacing(_ kind: String) {
        guard (inventoryItems[kind] ?? 0) > 0 else { return }
        placingMachine = kind
        showsBusiness = false
        showsSeedPicker = false
        dismissInspection()
        let name = ItemCatalog.item(kind)?.name.lowercased() ?? "machine"
        if WorkshopCatalog.workshop(kind) != nil {
            showBanner("Tap grass on your land where the \(name) should stand.")
        } else {
            showBanner("Tap grass in your fields where the \(name) should stand. It waters the tiles around it.")
        }
    }

    func cancelPlacing() {
        placingMachine = nil
    }

    /// Lines up placing a machine (the farmer walks over and sets it up).
    func queuePlaceJob(_ kind: String, at tile: TileCoord) {
        if let problem = estateRules.placeProblem(at: tile, in: simulation.state, checkReach: false) {
            Haptics.warning()
            showMessage(message(for: problem))
            onFeedback?(.refused(tile))
            return
        }
        placingMachine = nil
        enqueueJob(FarmerJob(kind: .placeMachine(tile, kind: kind), spot: tile.center, marker: tile.center))
    }

    func pickUpSprinkler(at tile: TileCoord) {
        dismissInspection()
        enqueueJob(FarmerJob(kind: .pickUpSprinkler(tile), spot: tile.center, marker: tile.center))
    }

    /// The farmer arrived: set the machine up.
    func finishPlacing(_ kind: String, at tile: TileCoord) {
        runEstate({ try $0.placeMachine(kind, at: tile, state: &$1) }) { _ in
            Haptics.success()
            if let workshop = WorkshopCatalog.workshop(kind) {
                onFeedback?(.workshop(tile, collected: nil))
                showMessage(workshop.isAutomatic ? "The \(workshop.name.lowercased()) is up. It works on its own: tap it now and then."
                    : "The \(workshop.name.lowercased()) is ready. Tap it to make something.")
            } else {
                onFeedback?(.sprinkler(tile))
            }
        }
    }

    func finishPickingUp(at tile: TileCoord) {
        runEstate({ try $0.pickUpSprinkler(at: tile, state: &$1) }) { _ in
            Haptics.tap()
            showMessage("Sprinkler back in your pouch.")
        }
    }

    // MARK: Farmhands

    func hire(_ job: WorkerJob) {
        runEstate({ try $0.hire(job, state: &$1) }) { worker in
            Haptics.success()
            showBanner("\(worker.name) joins the farm as your \(job.title.lowercased())! They work 08:00–17:00.")
        }
    }

    func assign(_ id: Int, to job: WorkerJob) {
        runEstate({ try $0.assign(id, to: job, state: &$1) }) { _ in Haptics.selection() }
    }

    func dismissWorker(_ id: Int) {
        let name = estateState.workers.first { $0.id == id }?.name ?? "The farmhand"
        runEstate({ try $0.dismiss(id, state: &$1) }) { _ in
            Haptics.tap()
            showMessage("\(name) packed up. No more wages from next Monday.")
        }
    }

    var firstWage: Int { estateRules.firstWage(simulation.state) }
    var nextHireLevel: Int? { estateRules.nextHireLevel(simulation.state) }
    var nextStorageUpgrade: (capacity: Int, cost: Int, level: Int)? { estateRules.nextStorageUpgrade(simulation.state) }
    var nextTruckBedUpgrade: (capacity: Int, cost: Int, level: Int)? { estateRules.nextTruckBedUpgrade(simulation.state) }

    /// What a farmhand is up to, in words.
    func status(of worker: Worker) -> String {
        let hour = simulation.state.clock.hour
        guard hour >= balance.workStartHour && hour < balance.workEndHour else {
            return "Off work · back at \(String(format: "%02d", balance.workStartHour)):00"
        }
        switch worker.lastTask {
        case .water?: return "Watering the fields"
        case .harvest?: return "Harvesting"
        case .collect?: return "Collecting from the animals"
        case .fillTrough?: return "Filling the troughs"
        case .feed?: return "Feeding the animals"
        case .craft?: return "Busy in the workshops"
        case nil:
            switch worker.job {
            case .fields: return "Looking for thirsty crops"
            case .animals: return "Checking on the animals"
            case .workshops: return "Checking the workshops"
            }
        }
    }

    // MARK: Helpers

    private func runEstate<T>(_ body: (EstateRules, inout GameState) throws -> T, onSuccess: (T) -> Void) {
        switch simulation.estate(on: map, body) {
        case .success(let value):
            onSuccess(value)
            refreshBusiness()
            refreshDisplay()
            refreshInventory()
            refreshTruck()
            farmRevision += 1
            save()
        case .failure(let failure):
            Haptics.warning()
            showMessage(message(for: failure))
        }
    }

    func message(for failure: EstateFailure) -> String {
        switch failure {
        case .unknown: "That isn't for sale."
        case .alreadyOwned: "That's already yours."
        case .locked(let level): "Unlocks at level \(level)."
        case .notEnoughMoney: money < 0 ? "You're in debt. Earn some coins first." : "Not enough coins."
        case .maxLevel: "Already the biggest there is."
        case .notYourLand: "That isn't your land."
        case .cannotPlaceHere: "It needs a free patch of grass (not a field, tree or path)."
        case .tooFar: "Walk over there first."
        case .noneInPouch: "You don't have one. Buy it on your phone (Farm)."
        case .noSprinkler: "There's no sprinkler here."
        case .tooManyWorkers: "The farm has all the hands it can take."
        case .noSuchWorker: "That farmhand has left."
        }
    }

    /// The land card for a parcel that isn't yours.
    func landInspection(_ tile: TileCoord) -> TileInspection? {
        guard let property = PropertyCatalog.property(containing: tile), let price = property.price,
              !simulation.state.ownedProperties.contains(property.id) else { return nil }
        let level = property.unlockLevel > self.level ? " · from level \(property.unlockLevel)" : ""
        return TileInspection(target: .tile(tile), title: "For sale: \(property.name)",
                              detail: "\(property.blurb) \(price) coins\(level).", icon: nil, symbol: "signpost.right.fill",
                              action: .showFarm, actionTitle: "See it on your phone")
    }

    func sprinklerInspection(_ tile: TileCoord) -> TileInspection {
        let kind = simulation.state.estate.sprinkler(at: tile)?.kind ?? "sprinkler"
        let machine = MachineCatalog.machine(kind)
        return TileInspection(target: .sprinkler(tile), title: machine?.name ?? "Sprinkler", detail: machine?.blurb ?? "",
                              icon: machine?.icon, symbol: "drop.fill", action: .pickUpSprinkler(tile), actionTitle: "Pick up")
    }
}
