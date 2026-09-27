import UIKit

/// Tiny wrapper around iOS haptics so feedback is consistent everywhere.
@MainActor
enum Haptics {
    /// Player setting (Settings → Haptics).
    static var isEnabled = true

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    /// A light tap: pressing things, focusing the camera.
    static func tap() { if isEnabled { light.impactOccurred() } }

    /// A barely-there tick: selecting a tile.
    static func selection() { if isEnabled { selectionGenerator.selectionChanged() } }

    /// A soft thump: gentle events like a new day.
    static func thump() { if isEnabled { soft.impactOccurred(intensity: 0.7) } }

    static func success() { if isEnabled { notification.notificationOccurred(.success) } }

    /// Something couldn't be done (with a soft "nope" sound).
    static func warning() {
        Sound.play(.refuse, volume: 0.6)
        if isEnabled { notification.notificationOccurred(.warning) }
    }

    private static let medium = UIImpactFeedbackGenerator(style: .medium)

    /// The truck hit something; stronger at speed.
    static func bump(intensity: Double) {
        Sound.play(.bump, volume: Float(max(0.3, min(1, intensity))))
        if isEnabled { medium.impactOccurred(intensity: CGFloat(max(0.3, min(1, intensity)))) }
    }
}
