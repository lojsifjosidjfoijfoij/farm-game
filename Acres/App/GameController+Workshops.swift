import Foundation
import AcresCore

extension GameController {
    var workshopRules: Workshops { Workshops(balance: balance) }

    /// The workshop under a tap: its own tile, or the roof poking into the tile above.
    func workshopTile(at spot: Vec2) -> TileCoord? {
        let estate = simulation.state.estate
        let tile = TileCoord(containing: spot)
        if estate.workshop(at: tile) != nil { return tile }
        let below = TileCoord(tile.x, tile.y - 1)
        guard simulation.state.plots[tile] == nil, estate.workshop(at: below) != nil,
              spot.y - Double(below.y) < 1.45 else { return nil }
        return below
    }

    /// Walk up to the workshop; its panel opens on arrival.
    func queueWorkshopJob(_ tile: TileCoord) {
        cancelJobs()
        let spot = Self.workshopSpot(tile)
        enqueueJob(FarmerJob(kind: .workshop(tile), spot: spot, marker: tile.center))
    }

    /// Where the farmer stands to use a workshop (in front of it).
    static func workshopSpot(_ tile: TileCoord) -> Vec2 { tile.center + Vec2(0, -0.75) }

    func arrivedAtWorkshop(_ tile: TileCoord) {
        guard simulation.state.estate.workshop(at: tile) != nil else { return }
        dismissInspection()
        showsSeedPicker = false
        openWorkshop = WorkshopSheet(tile: tile)
        refreshWorkshopSnapshot()
        Sound.play(.tap, volume: 0.6)
    }

    func closeWorkshop() {
        openWorkshop = nil
        workshopSnapshot = nil
    }

    /// The open workshop, copied once a (real) second so its timer ticks.
    func refreshWorkshopSnapshot() {
        guard let tile = openWorkshop?.tile, var workshop = simulation.state.estate.workshop(at: tile) else {
            if openWorkshop != nil { closeWorkshop() }
            return
        }
        workshop.progress = workshop.progress.rounded(.down)
        if workshopSnapshot != workshop { workshopSnapshot = workshop }
    }

    /// How many batches of a recipe the goods in storage pay for.
    func affordableBatches(_ recipe: Recipe) -> Int { workshopRules.affordableBatches(recipe, in: simulation.state) }

    /// Time until the whole queue is done (real seconds).
    func timeUntilDone(_ workshop: Workshop) -> TimeInterval? {
        guard let recipe = workshop.currentRecipe, workshop.queued > 0 else { return nil }
        if workshop.definition?.isAutomatic == true { return workshop.timeLeft }
        return max(0, Double(workshop.queued) * recipe.seconds - workshop.progress)
    }

    // MARK: Actions

    func startRecipe(_ recipe: Recipe, batches: Int) {
        guard let tile = openWorkshop?.tile else { return }
        runWorkshop({ try $0.start(recipe.id, batches: batches, at: tile, state: &$1) }) { _ in
            Haptics.tap()
            Sound.play(.plant, volume: 0.6)
            let what = batches * recipe.amount == 1 ? recipe.name.lowercased() : "\(batches * recipe.amount) \(recipe.plural.lowercased())"
            showMessage("Making \(what). Ready in \(Format.duration(Double(batches) * recipe.seconds)).")
        }
    }

    func collectWorkshop() {
        guard let tile = openWorkshop?.tile else { return }
        runWorkshop({ try $0.collect(at: tile, state: &$1) }) { result in
            Haptics.success()
            Sound.play(.harvest)
            let name = result.amount == 1 ? (ItemCatalog.item(result.item)?.name ?? result.item)
                : (ItemCatalog.item(result.item)?.plural ?? result.item)
            showMessage("+\(result.amount) \(name.lowercased()) into storage · +\(result.xp) XP")
            onFeedback?(.workshop(tile, collected: result.item))
            handle(result.events)
        }
    }

    func pickUpWorkshop() {
        guard let tile = openWorkshop?.tile else { return }
        let name = simulation.state.estate.workshop(at: tile)?.definition?.name.lowercased() ?? "workshop"
        runWorkshop({ try $0.pickUp(at: tile, state: &$1) }) { _ in
            Haptics.tap()
            closeWorkshop()
            showMessage("The \(name) is back in your pouch. Place it again from the Farm tab.")
            onWorldReset?()
        }
    }

    private func runWorkshop<T>(_ body: (Workshops, inout GameState) throws -> T, onSuccess: (T) -> Void) {
        switch simulation.workshops(body) {
        case .success(let value):
            onSuccess(value)
            refreshWorkshopSnapshot()
            refreshBusiness()
            refreshDisplay()
            refreshInventory()
            farmRevision += 1
            save()
        case .failure(let failure):
            Haptics.warning()
            showMessage(message(for: failure))
        }
    }

    func message(for failure: WorkshopFailure) -> String {
        switch failure {
        case .noWorkshop: "That workshop is gone."
        case .tooFar: "Walk over to the workshop first."
        case .unknownRecipe: "This workshop can't make that."
        case .busy: "It's busy with something else. Collect it first."
        case .missing(let item, let need):
            "You need \(need) \((ItemCatalog.item(item)?.plural ?? item).lowercased()) in storage."
        case .nothingReady: "Nothing's ready yet."
        case .storageFull: "Storage is full. Sell or deliver something first."
        case .notEmpty: "Empty it first: wait for the goods and collect them."
        }
    }
}
