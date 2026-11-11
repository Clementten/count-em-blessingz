import Testing
import SwiftData
import Foundation
@testable import CountEmBlessingz

@MainActor private var retained: [ModelContainer] = []

@MainActor
private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
        for: Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    retained.append(container)
    return container.mainContext
}

@MainActor
struct UpdatedAtTests {
    @Test func setOnCreation() {
        let before = Date.now
        let blessing = Blessing(amount: 10, currencyCode: "MYR")
        #expect(blessing.updatedAt >= before && blessing.updatedAt <= .now)
    }

    @Test func explicitUpdatedAtIsKept() {
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(Blessing(amount: 1, currencyCode: "MYR", updatedAt: when).updatedAt == when)
    }

    @Test func editBumpsIt() throws {
        let context = try makeContext()
        let service = BlessingService(context: context)
        var draft = BlessingDraft(); draft.name = "Mei"; draft.amountText = "100"
        let blessing = try service.add(draft, currency: "MYR", goal: nil, locale: Locale(identifier: "en_US")).blessing
        let old = Date(timeIntervalSince1970: 1_000)
        blessing.updatedAt = old
        draft.amountText = "150"
        try service.update(blessing, with: draft, locale: Locale(identifier: "en_US"))
        #expect(blessing.updatedAt > old)
    }

    @Test func currencyConversionAndMergeBumpIt() throws {
        let context = try makeContext()
        let settings = SeedData.insert(into: context)
        let blessings = try context.fetch(FetchDescriptor<Blessing>())
        let old = Date(timeIntervalSince1970: 1_000)
        blessings.forEach { $0.updatedAt = old }
        try CurrencyConverter.apply(rate: 2, to: "USD", countryCode: "US", labelOnly: false,
                                    blessings: blessings, settings: settings, context: context)
        #expect(blessings.allSatisfy { $0.updatedAt > old })

        blessings.forEach { $0.updatedAt = old }
        let mei = try #require(try BlesserResolver(context: context).find(name: "Aunt Mei"))
        let tan = try #require(try BlesserResolver(context: context).find(name: "Uncle Tan"))
        let tanEntries = tan.blessings
        BlesserService(context: context).merge(tan, into: mei)
        #expect(tanEntries.allSatisfy { $0.updatedAt > old })
    }

    @Test func undoOfDeleteKeepsOriginalUpdatedAt() throws {
        let context = try makeContext()
        let service = BlessingService(context: context)
        var draft = BlessingDraft(); draft.name = "Mei"; draft.amountText = "100"
        let blessing = try service.add(draft, currency: "MYR", goal: nil, locale: Locale(identifier: "en_US")).blessing
        let stamp = Date(timeIntervalSince1970: 1_234_567)
        blessing.updatedAt = stamp
        let snapshot = service.delete(blessing)
        try service.restore(snapshot)
        #expect(try context.fetch(FetchDescriptor<Blessing>()).first?.updatedAt == stamp)
    }
}

@MainActor
struct DeviceSettingsTests {
    @Test func defaults() {
        let a = AppSettings(), b = AppSettings()
        #expect(a.deviceID != b.deviceID)
        #expect(a.deviceLabel.isEmpty && a.lastExportAt == nil)
    }

    @Test func labelFallsBackToDeviceName() {
        let settings = AppSettings()
        #expect(!settings.effectiveDeviceLabel.isEmpty)
        settings.deviceLabel = "  Ah Ma's phone "
        #expect(settings.effectiveDeviceLabel == "Ah Ma's phone")
    }

    @Test func resetKeepsDeviceID() {
        let settings = AppSettings()
        let id = settings.deviceID
        settings.deviceLabel = "X"; settings.lastExportAt = .now
        settings.resetToDefaults()
        #expect(settings.deviceID == id && settings.deviceLabel.isEmpty && settings.lastExportAt == nil)
    }
}
