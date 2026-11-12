import Testing
import SwiftData
import Foundation
import UniformTypeIdentifiers
@testable import CountEmBlessingz

@MainActor private var retained: [ModelContainer] = []

@MainActor
private func makeContext(seed: Bool = true) throws -> ModelContext {
    let container = try ModelContainer(
        for: Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    retained.append(container)
    if seed { SeedData.insert(into: container.mainContext) }
    return container.mainContext
}

private func sampleFile(kind: ExchangeFile.Kind = .full) -> ExchangeFile {
    let mei = UUID(), lin = UUID()
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    return ExchangeFile(
        schemaVersion: 2, exportedAt: date, exportedBy: "Ah Ma's phone", deviceID: UUID(), currencyCode: "MYR", kind: kind,
        blessers: [.init(id: mei, name: "Aunt Mei", nameKey: "aunt mei"), .init(id: lin, name: "Lin", nameKey: "lin")],
        blessings: [
            .init(id: UUID(), blesserID: mei, amount: Decimal(string: "0.1")!, currencyCode: "MYR", date: date,
                  occasion: "birthday", method: "cash", note: "tiny, \"quoted\"", updatedAt: date.addingTimeInterval(60), photo: Data([9, 8, 7])),
            .init(id: UUID(), blesserID: lin, amount: Decimal(string: "123456789.123456")!, currencyCode: "MYR", date: date,
                  occasion: "wedding", method: "bank", note: "", updatedAt: date),
        ]
    )
}

struct ExchangeFileFormatTests {
    @Test func roundTripKeepsEveryDigitAndField() throws {
        let file = sampleFile()
        let decoded = try ExchangeFileCodec.decode(try ExchangeFileCodec.encode(file))
        #expect(decoded.blessings == file.blessings)
        #expect(decoded.blessers == file.blessers)
        #expect(decoded.blessings[0].amount == Decimal(string: "0.1")!)
        #expect(decoded.blessings[1].amount == Decimal(string: "123456789.123456")!)
        #expect(decoded.exportedBy == "Ah Ma's phone" && decoded.kind == .full && decoded.schemaVersion == 2)
        #expect(decoded.deviceID == file.deviceID && decoded.currencyCode == "MYR")
    }

    @Test func wireFormatUsesTextAmountsBase64PhotosAndIsoDates() throws {
        let json = try #require(String(data: try ExchangeFileCodec.encode(sampleFile()), encoding: .utf8))
        #expect(json.contains("\"amount\" : \"0.1\""))
        #expect(json.contains("\"photo\" : \"CQgH\""))                 // base64 of 09 08 07
        #expect(json.contains("\"kind\" : \"full\""))
        #expect(json.contains("2023-11-14T22:13:20.000Z"))
        #expect(!json.contains("settings"))                              // extras are omitted when absent
    }

    @Test func roundTrippedTimesAreNeverLaterThanTheOriginal() throws {
        var file = sampleFile()
        var worst: TimeInterval = 0
        for index in 0..<500 {
            // Irregular sub-millisecond values, including ones that sit right on a rounding edge.
            let date = Date(timeIntervalSince1970: 1_700_000_000 + Double(index) * 0.000_731 + 0.000_5)
            file.blessings[0].updatedAt = date
            let back = try ExchangeFileCodec.decode(try ExchangeFileCodec.encode(file)).blessings[0].updatedAt
            #expect(back <= date, "index \(index)")
            worst = max(worst, date.timeIntervalSince(back))
        }
        #expect(worst < 0.001)                                           // and never more than 1 ms earlier
    }

    @Test func sinceLastExportKindRoundTrips() throws {
        let decoded = try ExchangeFileCodec.decode(try ExchangeFileCodec.encode(sampleFile(kind: .sinceLastExport)))
        #expect(decoded.kind == .sinceLastExport)
    }

    @Test func extensionAndTypeAreDeclared() {
        #expect(ExchangeFile.fileExtension == "blessingz")
        #expect(UTTypeBlessingzIsJSON())
    }

    private func UTTypeBlessingzIsJSON() -> Bool {
        UTType.blessingzExchange.conforms(to: .json) && UTType.blessingzExchange.identifier == "com.clemzzz.countemblessingz.exchange"
    }
}

struct ExchangeFileErrorTests {
    @Test(arguments: [
        ("hello", ExportError.notABackup),
        ("{\"foo\":1}", ExportError.notABackup),
        ("{\"schemaVersion\":99}", ExportError.unsupportedVersion(99)),
        ("{\"schemaVersion\":2}", ExportError.corrupt),
        ("{\"schemaVersion\":1}", ExportError.olderBackup),
    ])
    func friendlyErrors(text: String, expected: ExportError) {
        #expect(throws: expected) { try ExchangeFileCodec.decode(Data(text.utf8)) }
        #expect(expected.errorDescription?.isEmpty == false)
    }

    @Test func messagesMatchTheSpec() {
        #expect(ExportError.notABackup.errorDescription == "This isn't a Count 'Em Blessingz file.")
        #expect(ExportError.unsupportedVersion(3).errorDescription == "This file is from a newer version of the app.")
    }

    @Test func truncatedFileIsCorrupt() throws {
        let data = try ExchangeFileCodec.encode(sampleFile())
        #expect(throws: ExportError.corrupt) { try ExchangeFileCodec.decode(data.prefix(data.count - 40)) }
    }

    @Test func danglingPersonReferenceIsCorrupt() throws {
        var file = sampleFile()
        file.blessings[0].blesserID = UUID()
        #expect(throws: ExportError.corrupt) { try ExchangeFileCodec.decode(try ExchangeFileCodec.encode(file)) }
    }

    @Test func duplicateIDsAreCorrupt() throws {
        var file = sampleFile()
        file.blessings[1].id = file.blessings[0].id
        #expect(throws: ExportError.corrupt) { try ExchangeFileCodec.decode(try ExchangeFileCodec.encode(file)) }
    }

    @Test func loaderReadsOffMainAndReportsUnreadable() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("t-\(UUID().uuidString).blessingz")
        try ExchangeFileCodec.encode(sampleFile()).write(to: url)
        let file = try await ExchangeFileLoader.load(url: url)
        #expect(file.blessings.count == 2)
        await #expect(throws: ExportError.unreadable) {
            _ = try await ExchangeFileLoader.load(url: url.appendingPathExtension("missing"))
        }
    }
}

@MainActor
struct ExchangeExportTests {
    @Test func fullShareHasNoExtrasButBackupDoes() throws {
        let service = ExportService(context: try makeContext())
        let share = try service.exchangeFile(kind: .full)
        #expect(share.settings == nil && share.conversions == nil)
        #expect(share.blessers.allSatisfy { $0.thankYouPending == nil && $0.createdAt == nil })
        #expect(share.blessings.count == 15 && share.kind == .full)

        let backup = try service.backupFile()
        #expect(backup.settings != nil && backup.conversions != nil)
        #expect(backup.blessers.allSatisfy { $0.thankYouPending != nil && $0.createdAt != nil })
    }

    @Test func headerIdentifiesThisDevice() throws {
        let context = try makeContext()
        let settings = try #require(try context.fetch(FetchDescriptor<AppSettings>()).first)
        settings.deviceLabel = "Dad's phone"
        let file = try ExportService(context: context).exchangeFile(kind: .full)
        #expect(file.exportedBy == "Dad's phone" && file.deviceID == settings.deviceID && file.currencyCode == "MYR")
    }

    @Test func sinceLastExportOnlyHasEditedEntriesAndTheirPeople() throws {
        let context = try makeContext()
        let service = ExportService(context: context)
        let settings = try #require(try context.fetch(FetchDescriptor<AppSettings>()).first)
        let all = try context.fetch(FetchDescriptor<Blessing>())
        #expect(try service.exchangeFile(kind: .sinceLastExport).blessings.count == 15)                  // never exported: everything counts

        settings.lastExportAt = .now
        #expect(try service.exchangeFile(kind: .sinceLastExport).blessings.count == 0)
        #expect(try service.exchangeFile(kind: .sinceLastExport).blessings.isEmpty)

        let edited = try #require(all.first { $0.blesser?.name == "Ah Kong" })
        edited.updatedAt = Date.now.addingTimeInterval(5)
        let changes = try service.exchangeFile(kind: .sinceLastExport)
        #expect(changes.kind == .sinceLastExport)
        #expect(changes.blessings.map(\.id) == [edited.id])
        #expect(changes.blessers.map(\.name) == ["Ah Kong"])
        #expect(try service.exchangeFile(kind: .sinceLastExport).blessings.count == 1)
    }
}

@MainActor
struct RestoreFormatTests {
    @Test func restoreKeepsThisDevicesIdentityAndResetsLastExport() throws {
        let context = try makeContext()
        let service = ExportService(context: context)
        let settings = try #require(try context.fetch(FetchDescriptor<AppSettings>()).first)
        settings.deviceLabel = "Mine"; settings.lastExportAt = .now
        let id = settings.deviceID
        let data = try service.backupData()
        try service.restore(from: data)
        let after = try #require(try context.fetch(FetchDescriptor<AppSettings>()).first)
        #expect(after.deviceID == id && after.deviceLabel == "Mine" && after.lastExportAt == nil)
    }

    @Test func plainShareFileReplacesEntriesAndKeepsLocalSettings() throws {
        let context = try makeContext()
        let service = ExportService(context: context)
        let settings = try #require(try context.fetch(FetchDescriptor<AppSettings>()).first)
        settings.themeID = "grand"
        let data = try ExchangeFileCodec.encode(try service.exchangeFile(kind: .full))
        try service.eraseAll()
        settings.themeID = "quiet"; settings.hasOnboarded = true
        try service.restore(from: data)
        #expect(try context.fetchCount(FetchDescriptor<Blessing>()) == 15)
        #expect(settings.themeID == "quiet")                            // no extras, so settings untouched
    }

    @Test func partialFileCannotReplaceEverything() throws {
        let context = try makeContext()
        let service = ExportService(context: context)
        let data = try ExchangeFileCodec.encode(try service.exchangeFile(kind: .sinceLastExport))
        #expect(throws: ExportError.notAFullBackup) { try service.restore(from: data) }
        #expect(try context.fetchCount(FetchDescriptor<Blessing>()) == 15)
    }

    @Test func schemaOneBackupsStillRestore() throws {
        let context = try makeContext(seed: false)
        let mei = UUID(), entry = UUID()
        let legacy = """
        {"schemaVersion":1,"exportedAt":736000000,
         "settings":{"hasOnboarded":true,"countryCode":"MY","currencyCode":"MYR","themeID":"grand","faceIDEnabled":false,"hideAmounts":false,"goal":"5000","reminderDays":3},
         "blessers":[{"id":"\(mei)","name":"Aunt Mei","thankYouPending":true,"createdAt":736000000}],
         "blessings":[{"id":"\(entry)","amount":"888","currencyCode":"MYR","date":736000100,"occasionRaw":"birthday","methodRaw":"cash","note":"hi","blesserID":"\(mei)"}],
         "conversions":[]}
        """
        let service = ExportService(context: context)
        try service.restore(from: Data(legacy.utf8))
        let restored = try #require(try context.fetch(FetchDescriptor<Blessing>()).first)
        #expect(restored.amount == 888 && restored.id == entry && restored.blesser?.name == "Aunt Mei")
        #expect(restored.updatedAt == restored.date)                    // schema 1 had no edit time
        #expect(try context.fetch(FetchDescriptor<AppSettings>()).first?.themeID == "grand")
        // ...but a schema-1 file is not accepted by the merge path.
        #expect(throws: ExportError.olderBackup) { try ExchangeFileCodec.decode(Data(legacy.utf8)) }
    }

    @Test func backupRestoreIsLosslessIncludingExtras() throws {
        let context = try makeContext()
        let service = ExportService(context: context)
        let first = try #require(try context.fetch(FetchDescriptor<Blessing>()).first)
        let id = first.id
        first.originalAmount = Decimal(string: "12.34"); first.originalCurrencyCode = "USD"
        first.blesser?.thankYouPending = true
        let stamp = Date(timeIntervalSince1970: 1_650_000_000)
        first.updatedAt = stamp
        context.insert(CurrencyConversion(fromCode: "USD", toCode: "MYR", rate: Decimal(string: "4.7")!, convertedAmounts: true, count: 1))
        let data = try service.backupData()
        try service.eraseAll()
        try service.restore(from: data)
        let restored = try #require(try context.fetch(FetchDescriptor<Blessing>()).first { $0.id == id })
        #expect(restored.originalAmount == Decimal(string: "12.34") && restored.originalCurrencyCode == "USD")
        #expect(abs(restored.updatedAt.timeIntervalSince(stamp)) < 0.01)
        #expect(restored.blesser?.thankYouPending == true)
        #expect(try context.fetch(FetchDescriptor<CurrencyConversion>()).first?.rate == Decimal(string: "4.7"))
    }
}
