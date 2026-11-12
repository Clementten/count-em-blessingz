import Testing
import SwiftData
import UserNotifications
import Foundation
@testable import CountEmBlessingz

@MainActor private var retained: [ModelContainer] = []

@MainActor
private func context() throws -> ModelContext {
    let container = try ModelContainer(
        for: Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    retained.append(container)
    return container.mainContext
}

private final class FakeCenter: NotificationCenterProtocol {
    var status: UNAuthorizationStatus = .authorized
    var requestResult = true
    var requestCount = 0
    var scheduled: [String: UNNotificationRequest] = [:]

    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization() async -> Bool { requestCount += 1; status = requestResult ? .authorized : .denied; return requestResult }
    func pendingIdentifiers() async -> [String] { Array(scheduled.keys) }
    func add(_ request: UNNotificationRequest) async { scheduled[request.identifier] = request }
    func remove(identifiers: [String]) { identifiers.forEach { scheduled[$0] = nil } }
    var categories: Set<UNNotificationCategory> = []
    func setCategories(_ categories: Set<UNNotificationCategory>) { self.categories = categories }
}

private let day: TimeInterval = 86_400
private let now = Date(timeIntervalSince1970: 1_800_000_000)

@MainActor
private func pendingBlesser(_ name: String, daysAgo: Double, in context: ModelContext, pending: Bool = true) -> Blesser {
    let blesser = Blesser(name: name)
    blesser.thankYouPending = pending
    context.insert(blesser)
    context.insert(Blessing(amount: 100, currencyCode: "MYR", date: now.addingTimeInterval(-daysAgo * day), blesser: blesser))
    return blesser
}

@MainActor
struct ReminderPlanTests {
    @Test func oneItemPerPendingBlesserAtRightDelay() throws {
        let ctx = try context()
        let mei = pendingBlesser("Mei", daysAgo: 1, in: ctx)
        _ = pendingBlesser("Done", daysAgo: 1, in: ctx, pending: false)
        let items = ReminderPlan.items(for: try ctx.fetch(FetchDescriptor<Blesser>()), days: 3, now: now)
        #expect(items.count == 1)
        #expect(items[0].identifier == "thank-\(mei.id.uuidString)")
        #expect(abs(items[0].fireDate.timeIntervalSince(now.addingTimeInterval(2 * day))) < 3_700)   // 1 day ago + 3 days (DST slack)
    }

    @Test func usesLatestBlessingDate() throws {
        let ctx = try context()
        let mei = pendingBlesser("Mei", daysAgo: 10, in: ctx)
        ctx.insert(Blessing(amount: 5, currencyCode: "MYR", date: now, blesser: mei))
        let items = ReminderPlan.items(for: [mei], days: 7, now: now)
        #expect(items.count == 1)
        #expect(abs(items[0].fireDate.timeIntervalSince(now.addingTimeInterval(7 * day))) < 3_700)
    }

    @Test func offAndPastProduceNothing() throws {
        let ctx = try context()
        let mei = pendingBlesser("Mei", daysAgo: 1, in: ctx)
        #expect(ReminderPlan.items(for: [mei], days: 0, now: now).isEmpty)
        #expect(ReminderPlan.items(for: [mei], days: 1, now: now.addingTimeInterval(5 * day)).isEmpty)   // already past
    }
}

@MainActor
struct ReminderServiceTests {
    @Test func syncSchedulesOneNotificationWithMessage() async throws {
        let ctx = try context()
        let mei = pendingBlesser("Mei", daysAgo: 0, in: ctx)
        let center = FakeCenter()
        await ReminderService(center: center).sync(blessers: [mei], days: 3, now: now)
        #expect(center.scheduled.count == 1)
        let request = try #require(center.scheduled["thank-\(mei.id.uuidString)"])
        #expect(request.content.body == "Say thanks to Mei.")
        #expect(request.trigger is UNCalendarNotificationTrigger)
        // Privacy: with lock-screen previews hidden, a placeholder replaces the person's name.
        #expect(request.content.categoryIdentifier == ReminderService.categoryIdentifier)
        #expect(center.categories.first?.identifier == ReminderService.categoryIdentifier)
        #expect(center.categories.first?.hiddenPreviewsBodyPlaceholder == "Someone is waiting for a thank-you.")
        let placeholder = center.categories.first?.hiddenPreviewsBodyPlaceholder ?? ""
        #expect(placeholder.range(of: "Mei") == nil)                    // never the person's name
    }

    @Test func markingThankedRemovesIt() async throws {
        let ctx = try context()
        let mei = pendingBlesser("Mei", daysAgo: 0, in: ctx)
        let center = FakeCenter()
        let service = ReminderService(center: center)
        await service.sync(blessers: [mei], days: 3, now: now)
        #expect(center.scheduled.count == 1)
        mei.thankYouPending = false
        await service.sync(blessers: [mei], days: 3, now: now)
        #expect(center.scheduled.isEmpty)
    }

    @Test func turningRemindersOffAndDeletionRemoveThem() async throws {
        let ctx = try context()
        let mei = pendingBlesser("Mei", daysAgo: 0, in: ctx)
        let center = FakeCenter()
        let service = ReminderService(center: center)
        await service.sync(blessers: [mei], days: 3, now: now)
        await service.sync(blessers: [mei], days: 0, now: now)
        #expect(center.scheduled.isEmpty)
        await service.sync(blessers: [mei], days: 3, now: now)
        await service.sync(blessers: [], days: 3, now: now)          // blesser deleted
        #expect(center.scheduled.isEmpty)
    }

    @Test func syncIsIdempotentAndLeavesOtherNotificationsAlone() async throws {
        let ctx = try context()
        let mei = pendingBlesser("Mei", daysAgo: 0, in: ctx)
        let center = FakeCenter()
        center.scheduled["other"] = UNNotificationRequest(identifier: "other", content: UNMutableNotificationContent(), trigger: nil)
        let service = ReminderService(center: center)
        await service.sync(blessers: [mei], days: 3, now: now)
        await service.sync(blessers: [mei], days: 3, now: now)
        #expect(center.scheduled.count == 2 && center.scheduled["other"] != nil)
    }

    @Test func nothingScheduledWithoutPermission() async throws {
        let ctx = try context()
        let mei = pendingBlesser("Mei", daysAgo: 0, in: ctx)
        let center = FakeCenter()
        center.status = .denied
        await ReminderService(center: center).sync(blessers: [mei], days: 3, now: now)
        #expect(center.scheduled.isEmpty)
    }

    @Test func permissionRequestedOnlyWhenUndetermined() async {
        let fresh = FakeCenter(); fresh.status = .notDetermined
        let service = ReminderService(center: fresh)
        #expect(await service.requestPermissionIfNeeded())
        #expect(await service.requestPermissionIfNeeded())      // now authorized: no second prompt
        #expect(fresh.requestCount == 1)

        let refused = FakeCenter(); refused.status = .notDetermined; refused.requestResult = false
        #expect(await ReminderService(center: refused).requestPermissionIfNeeded() == false)
        #expect(await ReminderService(center: refused).isDenied())
    }
}
