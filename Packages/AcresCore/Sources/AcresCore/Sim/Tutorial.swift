import Foundation

// Arne, who farmed this land for forty years, keeps the new farmer company
// while they learn it. It shouldn't feel like a tutorial: he introduces
// himself, walks you through your first day move by move, then only points
// the way, then mentions things in passing. After that first loop he drops
// by now and then when something new opens up (chores, the axe, the coop,
// fishing…), and once the start of the game is behind you he says goodbye.
// The player can tuck him away at any time (that part is the app's).

/// The steps of Arne's walk through the first loop. The raw values are what
/// saves store, so they never change; `TutorialState.order` is the order
/// they're played in (steps added later were given new numbers).
public enum TutorialStep: Int, Codable, CaseIterable, Sendable {
    case welcome = 0
    case plow = 1
    case plowMore = 2
    case plant = 3
    case water = 4
    case harvest = 5
    case load = 6
    case drive = 7
    case sell = 8
    case buySeeds = 9
    /// The "you've got it" card.
    case finished = 10
    /// Tutorial over (or skipped).
    case done = 11
    // Added with the longer tutorial.
    case sleep = 12
    case claimGoal = 13
    case driveHome = 14
    case replant = 15
    case phone = 16
    case acceptOrder = 17
    case fieldsTour = 18
}

/// How much Arne says at a step. It fades as the first loop goes on.
public enum GuideDetail: Int, Comparable, Sendable {
    /// Every move, with the thing to tap glowing (the first day).
    case walkthrough
    /// Where to go, in a line; the glow only comes if the player seems stuck.
    case pointer
    /// A word in passing; he tucks himself away again.
    case nudge

    public static func < (a: GuideDetail, b: GuideDetail) -> Bool { a.rawValue < b.rawValue }
}

extension TutorialStep {
    public var detail: GuideDetail {
        switch self {
        case .welcome, .plow, .plowMore, .plant, .water, .sleep: .walkthrough
        case .harvest, .claimGoal, .load, .drive, .sell, .buySeeds, .driveHome, .replant: .pointer
        case .phone, .acceptOrder, .fieldsTour, .finished, .done: .nudge
        }
    }
}

/// Something new Arne drops by to mention after the first loop, once it has
/// opened up. The last one is his goodbye. The raw values are saved.
public enum GuideTopic: String, CaseIterable, Sendable {
    case chores, market, axe, coop, workshop, fishing, foraging, shop, almanac, village, farmhand
    /// "That's everything I know." After this he's retired.
    case farewell

    /// Open: worth mentioning now.
    func isOpen(in state: GameState, balance: Balance) -> Bool {
        let level = state.progress.level
        switch self {
        case .chores: return state.has(.chores)
        // Once a price has fallen from selling a lot (or by level 3 anyway).
        case .market:
            let market = Market(balance: balance)
            return level >= 3 || state.market.sold.keys.contains { market.factor($0, in: state) < 0.85 }
        case .axe: return state.has(.axe)
        case .coop: return level >= (PenCatalog.pen("coop")?.unlockLevel ?? 2)
        case .workshop: return WorkshopCatalog.all.contains { $0.unlockLevel <= level }
        case .fishing: return state.has(.rod)
        case .foraging: return state.has(.foraging)
        case .shop: return level >= balance.storeUnlockLevel
        case .almanac: return state.has(.almanac)
        case .village: return level >= (Village.all.first?.unlockLevel ?? 3)
        case .farmhand: return balance.workerUnlockLevels.first.map { level >= $0 } ?? false
        case .farewell: return true
        }
    }

    /// Moot: the player already found it on their own, so there's nothing to say.
    func isMoot(in state: GameState) -> Bool {
        switch self {
        case .coop: state.ranch["coop"].isRepaired
        case .workshop: !state.estate.workshops.isEmpty
        case .shop: state.store.isRented
        case .farmhand: !state.estate.workers.isEmpty
        case .village: !state.village.progress.isEmpty || !state.village.finished.isEmpty
        default: false
        }
    }
}

/// Things the player does that the tutorial listens for.
public enum TutorialEvent: Equatable, Sendable {
    /// The player tapped the card's button (welcome, the fields tour, finished).
    case next
    case plowed
    case planted
    case watered
    case slept
    case harvested
    case claimedGoal
    case loaded
    case arrivedAtMarket
    case sold
    case boughtSeeds
    case arrivedHome
    case openedPhone
    case acceptedOrder
}

/// Arne's guidance (saved): the step of the first loop, then the topics he
/// has dropped by about. Steps advance on matching events; doing one of the
/// next couple of steps early skips ahead, so the player never gets stuck,
/// but doing something again later never jumps far ahead.
public struct TutorialState: Codable, Equatable, Sendable {
    public var step: TutorialStep
    /// Counter within a step (e.g. tiles plowed for "plow a row").
    public var progress: Int
    /// Topics Arne has dropped by about (`GuideTopic` raw values). (v14)
    public var told: [String]

    public init(step: TutorialStep, progress: Int = 0, told: [String] = []) {
        self.step = step
        self.progress = progress
        self.told = told
    }

    public static let new = TutorialState(step: .welcome)
    /// Arne has shown you everything and gone home.
    public static let complete = TutorialState(step: .done, told: GuideTopic.allCases.map(\.rawValue))

    /// The steps in the order they're played.
    public static let order: [TutorialStep] = [
        .welcome, .plow, .plowMore, .plant, .water, .sleep, .harvest, .claimGoal,
        .load, .drive, .sell, .buySeeds, .driveHome, .replant,
        .phone, .acceptOrder, .fieldsTour, .finished, .done,
    ]

    /// Steps that move on with the card's button rather than by doing something.
    public static let cardSteps: Set<TutorialStep> = [.welcome, .fieldsTour, .finished]

    /// How far ahead an event may skip (so repeating an old action never jumps far).
    static let lookahead = 2

    /// Arne is walking you through the first loop.
    public var isActive: Bool { step != .done }

    /// He has said goodbye: no more drop-ins.
    public var isRetired: Bool { told.contains(GuideTopic.farewell.rawValue) }

    /// What Arne would drop by about next, if anything: the first topic that
    /// has opened up and that he hasn't mentioned (skipping ones the player
    /// found by themselves), and his goodbye once nothing is left. Nothing
    /// during the first loop.
    public func nextTopic(in state: GameState, balance: Balance = .standard) -> GuideTopic? {
        guard !isActive, !isRetired else { return nil }
        let left = GuideTopic.allCases.filter { $0 != .farewell && !told.contains($0.rawValue) && !$0.isMoot(in: state) }
        if left.isEmpty { return .farewell }
        return left.first { $0.isOpen(in: state, balance: balance) }
    }

    public mutating func tell(_ topic: GuideTopic) {
        if !told.contains(topic.rawValue) { told.append(topic.rawValue) }
    }

    /// Extra tiles to plow in the "plow a row" step.
    public static let rowLength = 3

    /// Position in the order (0 = welcome).
    public var index: Int { Self.order.firstIndex(of: step) ?? Self.order.count - 1 }

    /// "Step 5 of 17" (the steps before the end card).
    public var stepNumber: Int { min(index + 1, Self.stepCount) }
    public static var stepCount: Int { order.count - 1 }

    /// True once the tutorial has reached (or passed) a step.
    public func hasReached(_ other: TutorialStep) -> Bool {
        !isActive || index >= (Self.order.firstIndex(of: other) ?? 0)
    }

    /// Handles an event; returns true if the step changed.
    @discardableResult
    public mutating func handle(_ event: TutorialEvent) -> Bool {
        guard isActive else { return false }
        if event == .next {
            guard Self.cardSteps.contains(step) else { return false }
            advance(past: step)
            return true
        }
        if event == .plowed && step == .plowMore {
            progress += 1
            if progress >= Self.rowLength { advance(past: .plowMore) }
            return progress >= Self.rowLength
        }
        // The first step this event completes, at or just after the current one.
        let window = index...(index + Self.lookahead)
        guard step != .welcome,
              let completes = Self.steps(completedBy: event).first(where: { candidate in
                  Self.order.firstIndex(of: candidate).map(window.contains) ?? false
              }) else { return false }
        advance(past: completes)
        return true
    }

    /// Sends Arne home: the first loop ends and he won't drop by again.
    public mutating func skip() {
        self = .complete
    }

    private mutating func advance(past completed: TutorialStep) {
        let i = Self.order.firstIndex(of: completed) ?? Self.order.count - 2
        step = Self.order[min(i + 1, Self.order.count - 1)]
        progress = 0
    }

    private static func steps(completedBy event: TutorialEvent) -> [TutorialStep] {
        switch event {
        case .next: []
        case .plowed: [.plow]
        case .planted: [.plant, .replant]
        case .watered: [.water]
        case .slept: [.sleep]
        case .harvested: [.harvest]
        case .claimedGoal: [.claimGoal]
        case .loaded: [.load]
        case .arrivedAtMarket: [.drive]
        case .sold: [.sell]
        case .boughtSeeds: [.buySeeds]
        case .arrivedHome: [.driveHome]
        case .openedPhone: [.phone]
        case .acceptedOrder: [.acceptOrder]
        }
    }
}
