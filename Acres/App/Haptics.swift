import UIKit

/// Tiny wrapper around iOS haptics so feedback is consistent everywhere.
@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    /// A light tap: pressing things, focusing the camera.
    static func tap() { light.impactOccurred() }

    /// A barely-there tick: selecting a tile.
    static func selection() { selectionGenerator.selectionChanged() }

    /// A soft thump: gentle events like a new day.
    static func thump() { soft.impactOccurred(intensity: 0.7) }

    static func success() { notification.notificationOccurred(.success) }
}
