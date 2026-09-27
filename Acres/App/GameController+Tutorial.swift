import Foundation
import AcresCore

/// Which HUD element the tutorial is pointing at (it pulses).
enum TutorialFocus: Equatable {
    case none
    case driveButton
    case basket
    case seedButton
    case shopButton
    case bedButton
}

/// Text for the tutorial card.
struct TutorialCard: Equatable {
    let title: String
    let body: String
    /// A button that moves on (welcome and final cards); otherwise the step
    /// completes by doing it.
    let button: String?
}

extension GameController {

    func advanceTutorial(_ event: TutorialEvent) {
        var updated = simulation.state.tutorial
        guard updated.handle(event) else {
            // Still count progress inside a step (e.g. tiles plowed).
            if updated != simulation.state.tutorial { store(updated) }
            return
        }
        store(updated)
        if updated.step != .done { Haptics.selection() }
    }

    func skipTutorial() {
        var updated = simulation.state.tutorial
        updated.skip()
        store(updated)
    }

    func restartTutorial() {
        store(.new)
    }

    private func store(_ state: TutorialState) {
        simulation.modify { $0.tutorial = state }
        tutorial = state
        farmRevision += 1  // the scene re-reads the highlighted tile
    }

    var tutorialCard: TutorialCard? {
        switch tutorial.step {
        case .welcome:
            TutorialCard(title: "Welcome to your farm!",
                         body: "This old place is yours now. Tap where you want your farmer to go, and they'll walk over and do the work.",
                         button: "Let's go")
        case .plow:
            TutorialCard(title: "Plow the land", body: "Tap the glowing spot inside the fence. Your farmer walks over and plows it.", button: nil)
        case .plowMore:
            TutorialCard(title: "Plow a row",
                         body: "Drag your finger across the ground to line up a whole row of jobs. (\(tutorial.progress)/\(TutorialState.rowLength))",
                         button: nil)
        case .plant:
            TutorialCard(title: "Plant seeds", body: "Tap the plowed soil to plant. The seed button shows which seeds you'll plant.", button: nil)
        case .water:
            TutorialCard(title: "Water it", body: "Tap the seedlings to water them. Watered crops grow twice as fast, and a watering lasts a day.", button: nil)
        case .harvest:
            TutorialCard(title: "Sleep, then harvest",
                         body: "Wheat takes a day to grow. Tap the bed to sleep until morning: the farm keeps growing. Harvest the wheat when it sparkles.",
                         button: nil)
        case .load:
            TutorialCard(title: "Load the truck", body: "Open the basket and tap Load all to put your harvest in the truck.", button: nil)
        case .drive:
            TutorialCard(title: "Drive to the village",
                         body: "Tap Drive (or the truck) to hop in. Then tap the map button → Village Market, or tap the road to drive there.",
                         button: nil)
        case .sell:
            TutorialCard(title: "Sell your harvest", body: "Stop at the market square and tap Sell. The market is open 07:00–19:00.", button: nil)
        case .buySeeds:
            TutorialCard(title: "Buy seeds", body: "Drive next door to the seed shop (open 08:00–18:00) and buy some more seeds.", button: nil)
        case .finished:
            TutorialCard(title: "You've got it!",
                         body: "Your goals (top left) show what to aim for next. Grow, sell, save up, and the whole valley could be yours.",
                         button: "Start farming")
        case .done:
            nil
        }
    }

    var tutorialFocus: TutorialFocus {
        switch tutorial.step {
        case .harvest: simulation.state.plots.byTile.values.contains { $0.crop?.isReady == true } ? .none : .bedButton
        case .load: showsInventory ? .none : .basket
        case .drive: isDriving ? .none : .driveButton
        case .sell: nearbyShop?.kind == .market ? .shopButton : (isDriving ? .none : .driveButton)
        case .buySeeds: nearbyShop?.kind == .seedShop ? .shopButton : (isDriving ? .none : .driveButton)
        default: .none
        }
    }

    /// Where the guide arrow points while driving.
    var guideTarget: Vec2? {
        switch tutorial.step {
        case .drive, .sell: ShopCatalog.first(.market)?.zone.center
        case .buySeeds: ShopCatalog.first(.seedShop)?.zone.center
        default: nil
        }
    }

    /// A tile to highlight in the field for the current step.
    var tutorialTargetTile: TileCoord? {
        let state = simulation.state
        switch tutorial.step {
        case .plow:
            // A free spot on the old field, close to the yard.
            let area = HomeValleyMap.homeFarmArea
            var best: (TileCoord, Double)?
            for y in Int(area.minY)..<Int(area.maxY) {
                for x in Int(area.minX)..<Int(area.maxX) {
                    let tile = TileCoord(x, y)
                    guard farming.plowProblem(at: tile, in: state, checkReach: false) == nil else { continue }
                    let d = tile.center.distance(to: Vec2(34.5, 32.5))
                    if best == nil || d < best!.1 { best = (tile, d) }
                }
            }
            return best?.0
        case .plant:
            return state.plots.sorted.first { $0.crop == nil }?.tile
        case .water:
            return state.plots.sorted.first { $0.crop.map { !$0.isReady } == true && !$0.isWet(at: state.worldTime) }?.tile
        case .harvest:
            return state.plots.sorted.first { $0.crop?.isReady == true }?.tile
        default:
            return nil
        }
    }
}
