import Foundation

/// The steps of the new-player tutorial. The raw values are what saves
/// store, so they never change; `TutorialState.order` is the order they're
/// played in (steps added later were given new numbers).
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

/// Tutorial progress (saved). Steps advance on matching events; doing one
/// of the next couple of steps early skips ahead, so the player never gets
/// stuck, but doing something again later never jumps far ahead.
public struct TutorialState: Codable, Equatable, Sendable {
    public var step: TutorialStep
    /// Counter within a step (e.g. tiles plowed for "plow a row").
    public var progress: Int

    public init(step: TutorialStep, progress: Int = 0) {
        self.step = step
        self.progress = progress
    }

    public static let new = TutorialState(step: .welcome)
    public static let complete = TutorialState(step: .done)

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

    public var isActive: Bool { step != .done }

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

    public mutating func skip() {
        step = .done
        progress = 0
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
