import Testing
import SwiftData
import Foundation
@testable import CountEmBlessingz

@MainActor private var retained: [ModelContainer] = []

@MainActor
private func seededContext() throws -> (ModelContext, AppSettings) {
    let container = try ModelContainer(
        for: Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    retained.append(container)
    let settings = SeedData.insert(into: container.mainContext)
    try container.mainContext.save()
    return (container.mainContext, settings)
}

@MainActor
struct SharePayloadTests {
    @Test func bothFilesDescribeTheSameMoment() throws {
        let (context, settings) = try seededContext()
        settings.deviceLabel = "Dad's phone"
        let now = Date.now
        let payload = try ExportService(context: context).sharePayload(now: now)
        #expect(payload.allFile.kind == .full && payload.changesFile.kind == .sinceLastExport)
        #expect(payload.allFile.exportedAt == now && payload.changesFile.exportedAt == now)
        #expect(payload.allFile.exportedBy == "Dad's phone" && payload.changesFile.exportedBy == "Dad's phone")
        #expect(payload.allFile.blessings.count == 15)
        #expect(payload.changeCount == 15)                                  // never shared: everything is a change
    }

    @Test func sharedFilesCarryNoPrivateSettings() throws {
        let (context, _) = try seededContext()
        let payload = try ExportService(context: context).sharePayload()
        for file in [payload.allFile, payload.changesFile] {
            #expect(file.settings == nil && file.conversions == nil)
            #expect(file.blessers.allSatisfy { $0.thankYouPending == nil })
        }
    }

    @Test func fileNamesUseTheExtensionAndKind() {
        let day = Date(timeIntervalSince1970: 1_750_000_000)
        #expect(ExportService.shareFileName(.full, now: day).hasPrefix("CountEmBlessingz-entries-2025-"))
        #expect(ExportService.shareFileName(.sinceLastExport, now: day).hasPrefix("CountEmBlessingz-changes-2025-"))
        #expect(ExportService.shareFileName(.full, now: day).hasSuffix(".blessingz"))
    }
}

@MainActor
struct MarkSharedTests {
    @Test func changesFileAdvancesTheBaselineToWhenItWasBuilt() throws {
        let (context, settings) = try seededContext()
        let service = ExportService(context: context)
        let built = Date.now
        let payload = try service.sharePayload(now: built)

        // An entry edited while the share sheet was open must still be included next time.
        let edited = try #require(try context.fetch(FetchDescriptor<Blessing>()).first)
        edited.updatedAt = built.addingTimeInterval(30)

        try service.markShared(payload.changesFile)
        #expect(settings.lastExportAt == built)
        #expect(try service.changedEntryCount() == 1)
        #expect(try service.exchangeFile(kind: .sinceLastExport).blessings.map(\.id) == [edited.id])
    }

    @Test func sharingEverythingDoesNotMoveTheBaseline() throws {
        let (context, settings) = try seededContext()
        let service = ExportService(context: context)
        try service.markShared(try service.sharePayload().allFile)
        #expect(settings.lastExportAt == nil)                              // only "changes" files count
    }

    @Test func baselineNeverMovesBackwards() throws {
        let (context, settings) = try seededContext()
        let service = ExportService(context: context)
        let early = try service.sharePayload(now: Date(timeIntervalSince1970: 1_700_000_000)).changesFile
        let late = try service.sharePayload(now: Date(timeIntervalSince1970: 1_800_000_000)).changesFile
        try service.markShared(late)
        try service.markShared(early)                                      // e.g. a late duplicate callback
        try service.markShared(late)
        #expect(settings.lastExportAt == late.exportedAt)
    }

    @Test func eraseAndRestoreResetTheBaseline() throws {
        let (context, settings) = try seededContext()
        let service = ExportService(context: context)
        settings.lastExportAt = .now
        let data = try service.backupData()
        try service.restore(from: data)
        #expect(settings.lastExportAt == nil)
        settings.lastExportAt = .now
        try service.eraseAll()
        #expect(settings.lastExportAt == nil)
    }
}

@MainActor
struct SharingNameTests {
    @Test func theNameAppearsInTheFileAndFallsBackToTheDeviceName() throws {
        let (context, settings) = try seededContext()
        let service = ExportService(context: context)
        settings.deviceLabel = ""
        #expect(try service.exchangeFile(kind: .full).exportedBy == settings.effectiveDeviceLabel)
        #expect(!settings.effectiveDeviceLabel.isEmpty)
        settings.deviceLabel = "  Ah Ma  "
        #expect(try service.exchangeFile(kind: .full).exportedBy == "Ah Ma")
    }

    @Test func deviceIDStaysTheSameAcrossFiles() throws {
        let (context, settings) = try seededContext()
        let service = ExportService(context: context)
        let first = try service.exchangeFile(kind: .full), second = try service.exchangeFile(kind: .sinceLastExport)
        #expect(first.deviceID == settings.deviceID && second.deviceID == settings.deviceID)
    }
}
