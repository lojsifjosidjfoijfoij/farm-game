import Foundation
import UserNotifications

/// Local notifications: "Your wheat is ready to harvest." Scheduled when the
/// app goes to the background, cleared when it comes back.
@MainActor
final class HarvestReminders {
    private let center = UNUserNotificationCenter.current()
    private let askedKey = "acres.askedForNotifications"
    private let identifier = "acres.harvest-ready"

    /// Asks for permission the first time it makes sense (the first planting),
    /// or again when the player switches reminders on in Settings.
    func requestPermissionIfNeeded(enabled: Bool, force: Bool = false) {
        guard enabled else { return }
        guard force || !UserDefaults.standard.bool(forKey: askedKey) else { return }
        UserDefaults.standard.set(true, forKey: askedKey)
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func schedule(after seconds: TimeInterval, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)) { _ in }
    }

    func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
