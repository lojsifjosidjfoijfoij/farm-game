import Foundation

/// The steps of the new-player tutorial, in order.
public enum TutorialStep: Int, Codable, CaseIterable, Sendable {
    case welcome
    case plow
    case plowMore
    case plant
    case water
    case harvest
    case load
    case drive
    case sell
    case buySeeds
    /// The "you've got it" card.
    case finished
    /// Tutorial over (or skipped).
    case done
}

/// Things the player does that the tutorial listens for.
public enum TutorialEvent: Equatable, Sendable {
    /// The player tapped the card's button (welcome / finished).
    case next
    case plowed
    case planted
    case watered
    case harvested
    case loaded
    case arrivedAtMarket
    case sold
    case boughtSeeds
}

/// Tutorial progress (saved). Steps advance on matching events; doing a
/// *later* step early skips ahead, so the player can never get stuck.
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

    public var isActive: Bool { step != .done }

    /// Extra tiles to plow in the "plow a row" step.
    public static let rowLength = 3

    /// Handles an event; returns true if the step changed.
    @discardableResult
    public mutating func handle(_ event: TutorialEvent) -> Bool {
        guard isActive else { return false }
        if event == .next {
            guard step == .welcome || step == .finished else { return false }
            advance(to: step == .welcome ? .plow : .done)
            return true
        }
        if event == .plowed && step == .plowMore {
            progress += 1
            if progress >= Self.rowLength { advance(to: .plant) }
            return progress >= Self.rowLength
        }
        guard let completes = Self.step(completedBy: event), completes.rawValue >= step.rawValue,
              step != .welcome else { return false }
        let nextStep = TutorialStep(rawValue: completes.rawValue + 1) ?? .done
        advance(to: nextStep)
        return true
    }

    public mutating func skip() {
        advance(to: .done)
    }

    private mutating func advance(to next: TutorialStep) {
        step = next
        progress = 0
    }

    private static func step(completedBy event: TutorialEvent) -> TutorialStep? {
        switch event {
        case .next: nil
        case .plowed: .plow
        case .planted: .plant
        case .watered: .water
        case .harvested: .harvest
        case .loaded: .load
        case .arrivedAtMarket: .drive
        case .sold: .sell
        case .boughtSeeds: .buySeeds
        }
    }
}
