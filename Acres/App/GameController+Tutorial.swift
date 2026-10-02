import Foundation
import AcresCore

/// What the tutorial is pointing at: a HUD element (it pulses) or the truck
/// (ringed, with the arrow over it).
enum TutorialFocus: Equatable {
    case none
    /// The truck in the world: tap it to get in (or out).
    case truck
    case basket
    /// A tool on the belt.
    case tool(BeltTool)
    case shopButton
    case bedButton
    case goalTracker
    case phoneButton
}

/// Text for the tutorial card, as said by Grandpa Tom, who ran the farm before you.
struct TutorialCard: Equatable {
    let title: String
    let body: String
    /// A button that moves on (card steps); otherwise the step completes by doing it.
    let button: String?
    /// "3 of 17".
    var step = 0
    var steps = 0
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
        if updated.step != .done {
            Haptics.selection()
            Sound.play(.tap, volume: 0.6)
        }
        if updated.step == .phone { reachTutorialLevel(Feature.phone.unlockLevel) }
    }

    /// The phone comes at level 2: the tutorial makes sure the farmer is there by then.
    private func reachTutorialLevel(_ target: Int) {
        let balance = self.balance
        let events = simulation.modify { state -> [SimEvent] in
            var events: [SimEvent] = []
            while state.progress.level < target {
                let needed = balance.xpToNextLevel(from: state.progress.level) - state.progress.xp
                events += Progression.addXP(max(1, needed), to: &state, balance: balance)
            }
            return events
        }
        handle(events)
        refreshDisplay()
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
        guard var card = baseTutorialCard else { return nil }
        card.step = tutorial.stepNumber
        card.steps = TutorialState.stepCount
        return card
    }

    private var baseTutorialCard: TutorialCard? {
        switch tutorial.step {
        case .welcome:
            TutorialCard(title: "Welcome to Acres!",
                         body: "I'm Tom. I ran this farm for forty years, and now it's yours. It's seen better days, but together we'll soon have it growing again.",
                         button: "Let's get started")
        case .plow:
            TutorialCard(title: "Plow your field",
                         body: tool == .hoe ? "See the glowing spot in your field? Tap it, and you'll walk over and plow it."
                             : "First, the soil. Pick the hoe on your tool belt (it's glowing).", button: nil)
        case .plowMore:
            TutorialCard(title: "Plow a row",
                         body: "Now drag your finger across the field to plow a whole row. (\(tutorial.progress)/\(TutorialState.rowLength))",
                         button: nil)
        case .plant:
            TutorialCard(title: "Sow some wheat",
                         body: tool == .seeds ? "Tap or drag over the plowed soil to plant your wheat seeds."
                             : "Pick the seed bag. Wheat is easy: it's ready in a day.", button: nil)
        case .water:
            TutorialCard(title: "Water the seedlings",
                         body: tool == .can ? "Tap or drag over your seedlings. Watered crops grow twice as fast."
                             : "Pick the watering can. Thirsty crops grow slowly.", button: nil)
        case .sleep:
            TutorialCard(title: "Sleep on it",
                         body: "Crops grow overnight. Tap the bed to go home and sleep until morning.", button: nil)
        case .harvest:
            TutorialCard(title: "Harvest time!",
                         body: tool == .sickle ? "Tap or drag over the ripe wheat to harvest it."
                             : "Your wheat is ripe! Pick the sickle to harvest it.", button: nil)
        case .claimGoal:
            TutorialCard(title: "A job well done",
                         body: "Goals pay you for getting things done. Tap the goal at the top left and claim your reward.", button: nil)
        case .load:
            TutorialCard(title: "Load the truck",
                         body: "Open the basket and tap Load all. Your harvest goes on the truck.", button: nil)
        case .drive:
            TutorialCard(title: "Off to market",
                         body: isDriving ? "Tap the road where you want to go, or pick the market on the map. Follow the arrow into the village."
                             : "Tap the truck to hop in (it's glowing). There's no key: tap it again to get out.", button: nil)
        case .sell:
            TutorialCard(title: "Sell your harvest",
                         body: "Stop on the market square and tap Sell. Prices change every day.", button: nil)
        case .buySeeds:
            TutorialCard(title: "Buy more seeds",
                         body: "The seed shop is just down the street. Buy seeds for your next crop.", button: nil)
        case .driveHome:
            TutorialCard(title: "Head home",
                         body: "Follow the arrow back to the farm.", button: nil)
        case .replant:
            TutorialCard(title: "Plant again",
                         body: isDriving ? "Home again! Tap the truck to get out, then plant your new seeds."
                             : "A field should never stand empty for long. Plant your new seeds.", button: nil)
        case .phone:
            TutorialCard(title: "Orders are coming in!",
                         body: "Word travels fast: people in the village want to buy from you. Their orders are in your farm journal. Tap the journal.", button: nil)
        case .acceptOrder:
            TutorialCard(title: "Your first order",
                         body: "Orders pay better than the market. Accept one, then bring the goods to the customer before the deadline.",
                         button: nil)
        case .fieldsTour:
            TutorialCard(title: "Room to grow",
                         body: "Crops only grow in fields. When you've saved up, buy your next field in your farm journal, under Farm. More come up as you level up.",
                         button: "Got it")
        case .finished:
            TutorialCard(title: "You're a natural!",
                         body: "The goals at the top left show what to aim for next. Grow, sell, save up, and this could be the finest farm in the valley.",
                         button: "Start farming")
        case .done:
            nil
        }
    }

    var tutorialFocus: TutorialFocus {
        switch tutorial.step {
        case .plow, .plowMore: tool == .hoe ? .none : .tool(.hoe)
        case .plant: tool == .seeds ? .none : .tool(.seeds)
        case .replant: isDriving ? .truck : (tool == .seeds ? .none : .tool(.seeds))
        case .water: tool == .can ? .none : .tool(.can)
        case .sleep: .bedButton
        case .harvest: tool == .sickle || tool == .hand ? .none : .tool(.sickle)
        case .claimGoal: .goalTracker
        case .load: showsInventory ? .none : .basket
        case .drive: isDriving ? .none : .truck
        case .sell: nearbyShop?.kind == .market ? .shopButton : (isDriving ? .none : .truck)
        case .buySeeds: nearbyShop?.kind == .seedShop ? .shopButton : (isDriving ? .none : .truck)
        case .driveHome: isDriving ? .none : .truck
        case .phone: .phoneButton
        default: .none
        }
    }

    /// Where the guide arrow points: the truck when it's time to get in or out,
    /// otherwise where to drive.
    var guideTarget: Vec2? {
        if tutorialFocus == .truck { return simulation.state.truck.position }
        return switch tutorial.step {
        case .drive, .sell: ShopCatalog.first(.market)?.zone.center
        case .buySeeds: ShopCatalog.first(.seedShop)?.zone.center
        case .driveHome: HomeValleyMap.truckParkingSpot
        default: deliveryTarget
        }
    }

    /// A tile to highlight in the field for the current step.
    var tutorialTargetTile: TileCoord? {
        let state = simulation.state
        switch tutorial.step {
        case .plow:
            // A free spot in the first field, on the side nearest the house.
            let area = HomeValleyMap.homeFarmArea
            var best: (TileCoord, Double)?
            for y in Int(area.minY)..<Int(area.maxY) {
                for x in Int(area.minX)..<Int(area.maxX) {
                    let tile = TileCoord(x, y)
                    guard farming.plowProblem(at: tile, in: state, checkReach: false) == nil else { continue }
                    let d = tile.center.distance(to: Vec2(27, 32.5))
                    if best == nil || d < best!.1 { best = (tile, d) }
                }
            }
            return best?.0
        case .plant, .replant:
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
