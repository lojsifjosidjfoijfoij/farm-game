import Foundation
import AcresCore

/// What the scene should animate after a pen or tree action.
enum WorldFeedback {
    case pen(RanchOutcome, penID: String)
    case tree(TreeOutcome, tile: TileCoord, position: Vec2)
}

extension GameController {
    var ranching: Ranching { Ranching(balance: balance) }
    var forestry: Forestry { Forestry(map: map, balance: balance) }

    // MARK: Pens

    /// One tap on a pen: collect, water or feed, whichever comes first. A
    /// run-down pen shows its card instead (repairs cost coins, so they're a
    /// deliberate button press).
    func tapPen(_ pen: PenDefinition) {
        guard welcome == nil else { return }
        guard let action = ranching.suggestedAction(for: pen, in: simulation.state), action != .repair else {
            inspect(.pen(pen.id))
            return
        }
        performPen(action, pen)
    }

    @discardableResult
    func performPen(_ action: PenAction, _ pen: PenDefinition) -> RanchOutcome {
        let result = simulation.perform(action, on: pen)
        switch result.outcome {
        case .failed(let failure):
            Haptics.warning()
            showMessage(message(for: failure, pen: pen))
        case .repaired:
            Haptics.success()
            let young = pen.species.map { $0.youngName.lowercased() + "s" } ?? "animals"
            showBanner("The \(pen.name.lowercased()) is fixed up! Buy \(young) at the livestock market.")
            dismissInspection()
        case .collected:
            Haptics.success()
        case .watered, .fed:
            Haptics.tap()
        }
        if !result.events.isEmpty { handle(result.events) }
        afterWorldAction()
        onFeedback?(.pen(result.outcome, penID: pen.id))
        return result.outcome
    }

    private func message(for failure: RanchFailure, pen: PenDefinition) -> String {
        let plural = pen.species?.plural ?? "animals"
        switch failure {
        case .notYourLand: return "This isn't your land."
        case .truckNotHere: return "Park your truck at the farm to look after the animals."
        case .locked(let level): return "The \(pen.name.lowercased()) can be fixed up at level \(level)."
        case .notEnoughMoney: return "Repairs cost \(pen.repairCost) coins."
        case .notRepaired: return "Fix up the \(pen.name.lowercased()) first."
        case .alreadyRepaired, .unknown, .nothingToCollect, .alreadyWatered, .nobodyHungry: return "All good here."
        case .noAnimals: return "No \(plural) yet. Buy some at the livestock market."
        case .storageFull: return "Storage is full (\(storageUsed)/\(storageCapacity)). Sell or make room first."
        case .noFeed(let speciesID):
            let foods = AnimalCatalog.species(speciesID)?.feeds.compactMap { ItemCatalog.item($0)?.name.lowercased() } ?? []
            return "The \(plural) are hungry! They eat \(foods.joined(separator: ", ")). Feed is sold at the livestock market."
        case .penFull: return "The \(pen.name.lowercased()) is full."
        }
    }

    func penInspection(_ id: String) -> TileInspection {
        guard let pen = PenCatalog.pen(id), let species = pen.species else {
            return TileInspection(target: .pen(id), title: "Pen", detail: "", icon: nil, symbol: "square.dashed")
        }
        let state = simulation.state
        let penState = state.ranch[id]
        let productIcon = "item_\(species.productItemID)"
        guard penState.isRepaired else {
            if state.progress.level < pen.unlockLevel {
                return TileInspection(target: .pen(id), title: pen.name,
                                      detail: "Run-down. It can be fixed up at level \(pen.unlockLevel) for \(pen.repairCost) coins.",
                                      icon: productIcon, symbol: "hammer.fill")
            }
            return TileInspection(target: .pen(id), title: pen.name,
                                  detail: "Run-down. Fix it up, then buy \(species.youngName.lowercased())s at the livestock market.",
                                  icon: productIcon, symbol: "hammer.fill",
                                  action: .repairPen(id), actionTitle: "Repair · \(pen.repairCost)")
        }
        guard !penState.animals.isEmpty else {
            return TileInspection(target: .pen(id), title: pen.name,
                                  detail: "Empty. Buy \(species.youngName.lowercased())s at the livestock market in the village.",
                                  icon: productIcon, symbol: "hare.fill")
        }
        let now = state.worldTime
        let water = penState.hasWater(at: now)
        var parts = ["\(penState.animals.count) of \(pen.capacity) \(species.plural)"]
        let ready = penState.animals.filter(\.hasProduct).count
        let hungry = penState.animals.filter(\.isHungry).count
        let young = penState.animals.filter { !$0.isAdult }.count
        if ready > 0 { parts.append("\(ItemCatalog.describe(ready, species.productItemID)) ready") }
        if hungry > 0 { parts.append("\(hungry) hungry") }
        if young > 0 { parts.append("\(young) growing up") }
        let producing = penState.animals.compactMap { animal -> TimeInterval? in
            guard let production = animal.production, production < species.produceSeconds else { return nil }
            return species.produceSeconds - production
        }
        if let next = producing.min() {
            // With water it's real time; a dry trough halves the pace.
            let wetLeft = max(0, penState.waterUntil - now)
            let eta = next <= wetLeft ? next : wetLeft + (next - wetLeft) / balance.dryProductionRate
            parts.append("next in \(Format.duration(eta))")
        }
        parts.append(water ? "water \(Format.duration(penState.waterUntil - now))" : "trough empty")
        let happiness = penState.animals.map(\.happiness).reduce(0, +) / Double(penState.animals.count)
        let mood = happiness > 0.75 ? "Very happy" : (happiness > 0.4 ? "Content" : "A bit sad")
        return TileInspection(target: .pen(id), title: "\(pen.name) · \(mood)",
                              detail: parts.joined(separator: " · "), icon: productIcon, symbol: "hare.fill")
    }

    // MARK: Trees

    /// The tree under a point (tile units), for taps.
    func treeTile(at point: Vec2) -> TileCoord? {
        forestry.treeTile(at: point, in: simulation.state)
    }

    /// One tap on a tree: chop, clear the stump or pick fruit; otherwise its card.
    func tapTree(_ tile: TileCoord) {
        guard welcome == nil else { return }
        guard let action = forestry.suggestedAction(at: tile, in: simulation.state) else {
            inspect(.tree(tile))
            return
        }
        performTree(action, at: tile)
    }

    @discardableResult
    func performTree(_ action: TreeAction, at tile: TileCoord) -> TreeOutcome {
        let position = forestry.position(of: tile)
        let result = simulation.perform(action, at: tile, on: map)
        switch result.outcome {
        case .failed(let failure):
            Haptics.warning()
            if let text = message(for: failure) { showMessage(text) }
        case .chopped:
            Haptics.thump()
            if inspection?.target == .tree(tile) { dismissInspection() }
        case .stumpCleared, .picked:
            Haptics.success()
        case .planted:
            Haptics.tap()
        }
        if !result.events.isEmpty { handle(result.events) }
        afterWorldAction()
        onFeedback?(.tree(result.outcome, tile: tile, position: position))
        return result.outcome
    }

    private func message(for failure: TreeFailure) -> String? {
        switch failure {
        case .notYourLand: return "This tree isn't on your land."
        case .truckNotHere: return "Park your truck at the farm to work here."
        case .storageFull: return "Storage is full (\(storageUsed)/\(storageCapacity)). Sell or make room first."
        case .noSaplings: return "No saplings of that kind left."
        case .notGrown: return "Let it grow first."
        case .noTree, .noFruit, .notPlowed, .occupied, .unknown: return nil
        }
    }

    func treeInspection(_ tile: TileCoord) -> TileInspection {
        let state = simulation.state
        guard let info = forestry.tree(at: tile, in: state) else {
            return TileInspection(target: .tree(tile), title: "Cleared", detail: "Nothing grows here now.", icon: nil, symbol: "leaf")
        }
        let owned = forestry.accessProblem(at: tile, in: state) != .notYourLand
        let species = info.species
        let title = species?.name ?? "Old stump"
        let sapling = species.map { "item_sapling_\($0.id)" }
        func card(_ detail: String, icon: String?, action: InspectionAction? = nil, actionTitle: String? = nil) -> TileInspection {
            TileInspection(target: .tree(tile), title: info.stage == .stump ? "\(title) stump" : title, detail: detail,
                           icon: icon, symbol: "tree.fill", action: action, actionTitle: actionTitle)
        }
        guard owned else { return card("A wild tree. It isn't on your land.", icon: sapling) }
        switch info.stage {
        case .stump:
            if let record = info.record, let age = record.stumpAge, species != nil {
                let left = max(0, balance.stumpRegrowSeconds - age)
                return card("Tap to clear it away. Left alone, it sprouts again in \(Format.duration(left)).", icon: "item_log")
            }
            return card("Tap to clear it away.", icon: "item_log")
        case .sapling, .young:
            let left = max(0, (species?.growSeconds ?? 0) - (info.record?.growth ?? 0))
            return card("\(info.stage == .sapling ? "A sapling" : "Growing") · full-grown in \(Format.duration(left))", icon: sapling)
        case .mature:
            guard let species else { return card("", icon: nil) }
            if let fruitID = species.fruitItemID {
                let fruitName = ItemCatalog.item(fruitID)?.plural ?? fruitID
                let detail: String
                if info.hasFruit {
                    detail = "Ripe \(fruitName)! Tap to pick."
                } else {
                    let left = max(0, species.fruitSeconds - (info.record?.fruit ?? 0))
                    detail = "\(fruitName.prefix(1).uppercased() + fruitName.dropFirst()) in \(Format.duration(left))."
                }
                return card(detail, icon: "item_\(fruitID)", action: .chopTree(tile), actionTitle: "Chop down")
            }
            return card("Tap to chop: \(species.logs.lowerBound)–\(species.logs.upperBound) logs. The stump grows back.", icon: "item_log")
        }
    }

    // MARK: Info card buttons

    func performInspectionAction() {
        guard let action = inspection?.action else { return }
        switch action {
        case .repairPen(let id):
            if let pen = PenCatalog.pen(id) { performPen(.repair, pen) }
        case .chopTree(let tile):
            performTree(.chop, at: tile)
        }
    }

    // MARK: Helpers

    private func afterWorldAction() {
        refreshInventory()
        refreshDisplay()
        farmRevision += 1
        refreshInspection()
    }
}
