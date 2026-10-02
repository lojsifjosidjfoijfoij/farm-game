import Foundation
import AcresCore

/// The old farmer who keeps you company while you learn the farm. (One place
/// for his name, so it's easy to change.)
enum Mentor {
    static let name = "Arne"
}

/// What a step points at: a HUD element (it pulses) or the truck (ringed,
/// with the arrow over it).
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

/// What Arne says: a line or two, said to you, not a tutorial card.
struct GuideMessage: Equatable {
    let text: String
    /// A reply that moves on (his introduction, a goodbye); otherwise doing the thing is the reply.
    var button: String?
    /// Offer "Show me" (a pointer step whose details aren't showing yet).
    var offersHelp = false
}

/// Arne's timers (not observed).
struct GuideClock {
    /// Seconds since the current step or message began (how long the player has been at it).
    var stepTime: TimeInterval = 0
    /// Seconds of quiet play since he last dropped by.
    var quietTime: TimeInterval = 0
    /// He steps back to the side by himself when this runs out.
    var tuckIn: TimeInterval?
    /// The player tucked him away: news only lights the dot until they call him back.
    var playerTucked = false
    var lastStep: TutorialStep?
}

extension GameController {

    /// A pointer step offers its details after this long without progress.
    static let guideStuckAfter: TimeInterval = 25
    /// Quiet play between his drop-ins after the first loop.
    static let guideDropInGap: TimeInterval = 120
    /// How long a word in passing stays before he steps back.
    static let guideNudgeTime: TimeInterval = 12

    // MARK: Events

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

    /// The journal comes at level 2: Arne makes sure the farmer is there by then.
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

    /// Sends Arne home for good (settings, debug).
    func skipTutorial() {
        var updated = simulation.state.tutorial
        updated.skip()
        store(updated)
        guideTopic = nil
        guideAsked = false
    }

    /// Arne shows you around again (the farm is kept).
    func restartTutorial() {
        store(.new)
        resetGuide()
    }

    /// Arne starts fresh (showing you around again, a new farm).
    func resetGuide() {
        guideTopic = nil
        guideAsked = false
        guideHelping = false
        guideHasNews = false
        guideTucked = false
        guideClock = GuideClock()
    }

    private func store(_ state: TutorialState) {
        simulation.modify { $0.tutorial = state }
        tutorial = state
        farmRevision += 1  // the scene re-reads the highlighted tile
    }

    // MARK: Coming and going

    /// Arne is around at all (until he says goodbye).
    var guideIsAround: Bool { !tutorial.isRetired || guideTopic == .farewell }

    /// His speech bubble is out.
    var guideIsTalking: Bool { guideMessage != nil && !guideTucked }

    /// The player taps the reply on his bubble (his introduction, "Will do", goodbye).
    func answerGuide() {
        Haptics.tap()
        if let topic = guideTopic {
            finishTopic(topic)
        } else if guideAsked {
            guideAsked = false
            guideTucked = true
        } else {
            advanceTutorial(.next)
        }
    }

    /// The player tucks him away. He stays tucked (news lights the dot on his
    /// portrait) until they call him back; the glow on things still helps meanwhile.
    func tuckGuide() {
        Haptics.tap()
        guideClock.playerTucked = true
        guideHasNews = false
        // Tucking away something that only needed a nod counts as the nod.
        if let topic = guideTopic {
            finishTopic(topic)
        } else if guideAsked {
            guideAsked = false
        } else if tutorial.isActive, TutorialState.cardSteps.contains(tutorial.step) {
            advanceTutorial(.next)
        }
        guideTucked = true
        guideClock.tuckIn = nil
    }

    /// The player taps his portrait: he comes out with his news, or says what he'd do next.
    func callGuide() {
        Haptics.tap()
        guideClock.playerTucked = false
        guideHasNews = false
        if guideMessage == nil { guideAsked = true }
        guideTucked = false
        let inPassing = guideAsked || (guideTopic != nil && guideTopic != .farewell) || tutorial.step.detail == .nudge
            && tutorial.isActive && !TutorialState.cardSteps.contains(tutorial.step)
        guideClock.tuckIn = inPassing ? Self.guideNudgeTime : nil
    }

    /// "Show me": the details and the glow, now.
    func guideShowMe() {
        Haptics.tap()
        guideHelping = true
        farmRevision += 1
    }

    private func finishTopic(_ topic: GuideTopic) {
        guideTopic = nil
        guideClock.quietTime = 0
        guideTucked = true
        if topic == .farewell { Sound.play(.tap, volume: 0.5) }
    }

    /// Steps, drop-ins and timers; once per frame.
    func updateGuide(dt: TimeInterval) {
        if guideClock.lastStep != tutorial.step {
            guideClock.lastStep = tutorial.step
            guideStepBegan()
        }
        guard guideIsAround else { return }
        if isQuietMoment { guideClock.stepTime += dt }

        // Stuck at a pointer step: he offers the details (and the glow).
        if tutorial.isActive, tutorial.step.detail == .pointer, !guideHelping,
           guideClock.stepTime > Self.guideStuckAfter {
            guideHelping = true
            if guideTucked { guideHasNews = true }
            farmRevision += 1
        }

        if let left = guideClock.tuckIn, guideIsTalking {
            guideClock.tuckIn = left - dt
            if left - dt <= 0 {
                // A word in passing: he steps back to the side by himself.
                guideClock.tuckIn = nil
                guideAsked = false
                if let topic = guideTopic { finishTopic(topic) }
                guideTucked = true
            }
        }

        // After the first loop: drop by now and then with what's new, never in a busy moment.
        guard !tutorial.isActive, guideTopic == nil, isQuietMoment else { return }
        guideClock.quietTime += dt
        guard guideClock.quietTime >= Self.guideDropInGap,
              let topic = tutorial.nextTopic(in: simulation.state, balance: balance) else { return }
        var updated = simulation.state.tutorial
        updated.tell(topic)
        store(updated)
        guideTopic = topic
        guideAsked = false
        speak(nudge: topic != .farewell)
    }

    private func guideStepBegan() {
        guideClock.stepTime = 0
        guideHelping = false
        guard tutorial.isActive else { return }
        speak(nudge: tutorial.step.detail == .nudge && !TutorialState.cardSteps.contains(tutorial.step))
    }

    /// He has something new to say: he steps out, or, if the player tucked him
    /// away, lights the dot on his portrait.
    private func speak(nudge: Bool) {
        let comesOut = !guideClock.playerTucked
        guideTucked = !comesOut
        guideHasNews = !comesOut
        guideClock.tuckIn = nudge ? Self.guideNudgeTime : nil
        guideClock.stepTime = 0
    }

    /// No sheet, card or night in the way.
    private var isQuietMoment: Bool {
        welcome == nil && sleep == nil && levelUpCard == nil && rankUpCard == nil && weeklyReport == nil
            && !showsInventory && !showsGoals && !showsBusiness && !showsStore && !showsRoadmap
            && openShop == nil && openWorkshop == nil
    }

    /// Debug: skip the wait before his next drop-in.
    func debugGuideDropIn() {
        guideClock.quietTime = Self.guideDropInGap
    }

    // MARK: What he says

    var guideMessage: GuideMessage? {
        if let topic = guideTopic { return message(for: topic) }
        if guideAsked { return whatsNext }
        guard tutorial.isActive else { return nil }
        return stepMessage
    }

    private var stepMessage: GuideMessage? {
        let helping = guideHelping
        let pointer = tutorial.step.detail == .pointer
        func say(_ short: String, _ detail: String) -> GuideMessage {
            GuideMessage(text: helping ? "\(short) \(detail)" : short, offersHelp: pointer && !helping)
        }
        switch tutorial.step {
        case .welcome:
            return GuideMessage(
                text: "Hello there, you must be the new farmer! I'm \(Mentor.name). I worked this land for forty years, and now it's yours. "
                    + "It's gone a bit wild, but we'll soon have it growing again. I'll stay close for a while and show you how things work. "
                    + "If I talk too much, just tuck me away.",
                button: "Nice to meet you, \(Mentor.name)")
        case .plow:
            return GuideMessage(text: tool == .hoe
                                ? "Good. See the glowing spot in the field? Tap it, and you'll walk over and plow it."
                                : "Let's start with the soil. Pick the hoe on your tool belt, the one that's glowing.")
        case .plowMore:
            return GuideMessage(text: "That's it! Now drag your finger along the field to plow a whole row. "
                                + "(\(tutorial.progress) of \(TutorialState.rowLength))")
        case .plant:
            return GuideMessage(text: tool == .seeds
                                ? "Now tap or drag over the plowed soil to sow the wheat."
                                : "Time to sow. Pick the seed bag: wheat is easy, and it's ready by tomorrow.")
        case .water:
            return GuideMessage(text: tool == .can
                                ? "Give them a drink: tap or drag over the seedlings. Watered crops grow twice as fast."
                                : "Seeds are thirsty things. Pick the watering can.")
        case .sleep:
            return GuideMessage(text: "That's a good day's work. Crops grow overnight, so tap the bed and get some sleep. "
                                + "I'll see you in the morning.")
        case .harvest:
            return say("Good morning! Your wheat is ripe. Bring it in.",
                       tool == .sickle || tool == .hand ? "Tap or drag over the ripe wheat."
                           : "Pick the sickle, then tap or drag over the ripe wheat.")
        case .claimGoal:
            return say("You've earned a reward for all that. Go and claim it.", "Tap the goal at the top left, then Claim.")
        case .load:
            return say("Now let's turn that wheat into coins. Put it on the truck.", "Open the basket and tap Load all.")
        case .drive:
            return say("Off to the market in the village!",
                       isDriving ? "Tap the road where you want to go, or pick the market on the map. Follow the arrow."
                           : "Tap the truck to hop in. Tap it again to get out.")
        case .sell:
            return say("Sell your wheat at the market.",
                       nearbyShop?.kind == .market ? "Tap the market's button at the bottom, then Sell."
                           : "Stop on the market square, where the arrow points.")
        case .buySeeds:
            return say("Pick up seeds for the next crop while you're here.",
                       "The seed shop is just down the street. Stop in front of it and tap its button.")
        case .driveHome:
            return say("Let's head home.", "Follow the arrow back to the farm.")
        case .replant:
            return say("A field shouldn't stand empty for long. Get the new seeds in.",
                       isDriving ? "Tap the truck to get out, then pick the seed bag." : "Pick the seed bag and sow.")
        case .phone:
            return GuideMessage(text: "Folks in the village have heard about you, and some want to buy from you. "
                                + "Their orders are in your journal.")
        case .acceptOrder:
            return GuideMessage(text: "Orders pay better than the market. Take one on, if you like.")
        case .fieldsTour:
            return GuideMessage(text: "Crops only grow in fields. When you've saved up, buy another one: it's in your journal, under Farm.",
                                button: "Will do")
        case .finished:
            return GuideMessage(text: "You've got the hang of it! The goals at the top show the way from here, "
                                + "and I'll drop by when something new comes up.",
                                button: "See you around")
        case .done:
            return nil
        }
    }

    private func message(for topic: GuideTopic) -> GuideMessage {
        switch topic {
        case .chores:
            GuideMessage(text: "Every morning there'll be three little chores at the top. Do all three for a bonus, "
                         + "and keep it up for a streak.")
        case .axe:
            GuideMessage(text: "You've earned the axe. The trees in your woodlot give good logs.")
        case .coop:
            GuideMessage(text: "My old chicken coop is behind the farmhouse. Fix it up, and the livestock market "
                         + "will sell you some hens. Fresh eggs every day!")
        case .workshop:
            GuideMessage(text: "With a workshop, your crops and logs become goods worth a lot more. "
                         + "You'll find them in your journal, under Farm.")
        case .fishing:
            GuideMessage(text: "Have you tried the pond? Pick the rod, tap the water, and tap again when something bites.")
        case .foraging:
            GuideMessage(text: "Keep your eyes open in the woods and meadows. Wild things turn up there every morning.")
        case .shop:
            GuideMessage(text: "The corner shop in the village is for rent. You set your own prices, and it sells while you farm.")
        case .almanac:
            GuideMessage(text: "There's an almanac in your journal now. Everything you grow, catch, find or make goes in it, "
                         + "and a full page pays a reward.")
        case .farmhand:
            GuideMessage(text: "You can hire a farmhand now. They water, harvest and see to the animals while you get on "
                         + "with other things. Journal, under Farm.")
        case .farewell:
            GuideMessage(text: "Well, that's everything I know. You don't need an old man looking over your shoulder anymore. "
                         + "I'll be on the porch with my coffee. It's a fine farm you're making.",
                         button: "Take care, \(Mentor.name)")
        }
    }

    /// When asked: the next goal, as he'd put it.
    private var whatsNext: GuideMessage {
        if openGoals.contains(where: \.isComplete) {
            return GuideMessage(text: "There's a reward waiting for you. Tap the goal at the top.")
        }
        guard let goal = openGoals.first?.goal else {
            return GuideMessage(text: "Nothing I'd tell you to do. Enjoy the farm!")
        }
        let detail = goal.detail.prefix(1).lowercased() + goal.detail.dropFirst()
        return GuideMessage(text: "If I were you, I'd go for \u{201C}\(goal.title)\u{201D} next: \(detail)")
    }

    // MARK: What lights up

    /// The glow, the ring and the pulses: on the first day always; at a pointer
    /// step only when the player wants help; a word in passing keeps its pulse.
    var guideShowsHints: Bool {
        switch tutorial.step.detail {
        case .walkthrough, .nudge: true
        case .pointer: guideHelping
        }
    }

    var tutorialFocus: TutorialFocus {
        guard guideShowsHints else { return .none }
        return switch tutorial.step {
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
    /// otherwise where to drive (the trip to the village always has its arrow).
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
        guard guideShowsHints else { return nil }
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
