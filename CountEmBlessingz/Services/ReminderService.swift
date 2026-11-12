import SwiftUI
import SwiftData
import UserNotifications

/// What to schedule: one reminder per thank-you-pending blesser, `days` after their latest blessing.
enum ReminderPlan {
    struct Item: Equatable {
        let identifier: String        // "thank-{blesser.id}"
        let name: String
        let fireDate: Date
    }

    static let identifierPrefix = "thank-"

    static func identifier(for blesser: Blesser) -> String { identifierPrefix + blesser.id.uuidString }

    static func items(
        for blessers: [Blesser], days: Int, now: Date = .now, calendar: Calendar = .current
    ) -> [Item] {
        guard days > 0 else { return [] }
        var items: [Item] = []
        for blesser in blessers where blesser.thankYouPending {
            guard let latest = blesser.blessings.map(\.date).max(),
                  let fire = calendar.date(byAdding: .day, value: days, to: latest),
                  fire > now          // a reminder in the past would fire immediately; skip it
            else { continue }
            items.append(Item(identifier: identifier(for: blesser), name: blesser.name, fireDate: fire))
        }
        return items.sorted { $0.identifier < $1.identifier }
    }
}

protocol NotificationCenterProtocol {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async -> Bool
    func pendingIdentifiers() async -> [String]
    func add(_ request: UNNotificationRequest) async
    func remove(identifiers: [String])
    func setCategories(_ categories: Set<UNNotificationCategory>)
}

struct SystemNotificationCenter: NotificationCenterProtocol {
    private var center: UNUserNotificationCenter { .current() }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }
    func pendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }
    func add(_ request: UNNotificationRequest) async {
        try? await center.add(request)
    }
    func remove(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    func setCategories(_ categories: Set<UNNotificationCategory>) {
        center.setNotificationCategories(categories)
    }
}

/// Local notifications only. Permission is requested when reminders are first needed, never at launch.
@MainActor @Observable
final class ReminderService {
    private let center: NotificationCenterProtocol

    init(center: NotificationCenterProtocol = SystemNotificationCenter()) {
        self.center = center
    }

    static let categoryIdentifier = "thank-you"

    /// When the person has chosen to hide notification previews on the lock screen, this text replaces
    /// "Say thanks to {name}." so a name never shows to someone glancing at a locked phone.
    static let category = UNNotificationCategory(
        identifier: categoryIdentifier, actions: [], intentIdentifiers: [],
        hiddenPreviewsBodyPlaceholder: String(localized: "Someone is waiting for a thank-you."), options: []
    )

    private func isAllowed(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    /// Asks the system for permission if it hasn't been asked yet. Returns true when reminders can be delivered.
    func requestPermissionIfNeeded() async -> Bool {
        switch await center.authorizationStatus() {
        case .notDetermined: return await center.requestAuthorization()
        case let status: return isAllowed(status)
        }
    }

    /// True when the user has explicitly denied notifications.
    func isDenied() async -> Bool { await center.authorizationStatus() == .denied }

    /// Makes the scheduled notifications match the plan: stale ones are removed, missing ones added.
    func sync(blessers: [Blesser], days: Int, now: Date = .now) async {
        let plan = ReminderPlan.items(for: blessers, days: days, now: now)
        let existing = await center.pendingIdentifiers().filter { $0.hasPrefix(ReminderPlan.identifierPrefix) }
        center.remove(identifiers: existing)
        guard !plan.isEmpty, isAllowed(await center.authorizationStatus()) else { return }
        center.setCategories([Self.category])
        for item in plan {
            let content = UNMutableNotificationContent()
            content.categoryIdentifier = Self.categoryIdentifier
            content.body = String(localized: "Say thanks to \(item.name).")
            content.sound = .default
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            await center.add(UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger))
        }
    }
}
