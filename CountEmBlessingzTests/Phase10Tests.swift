import Testing
import SwiftData
import Foundation
@testable import CountEmBlessingz

@MainActor private var retained: [ModelContainer] = []

@MainActor
private func makeContext(seed: Bool = true) throws -> ModelContext {
    let container = try ModelContainer(
        for: Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    retained.append(container)
    let context = container.mainContext
    if seed { SeedData.insert(into: context) }
    return context
}

@MainActor
private func snapshot(_ context: ModelContext) throws -> (blessings: Int, blessers: Int, total: Decimal, pending: Set<String>) {
    let blessings = try context.fetch(FetchDescriptor<Blessing>())
    let blessers = try context.fetch(FetchDescriptor<Blesser>())
    return (blessings.count, blessers.count, blessings.reduce(0) { $0 + $1.amount },
            Set(blessers.filter(\.thankYouPending).map(\.name)))
}

@MainActor
struct CSVTests {
    @Test func headerAndRows() throws {
        let lines = try ExportService(context: try makeContext()).csv().split(separator: "\n").map(String.init)
        #expect(lines[0] == "date,name,amount,currency,occasion,method,note")
        #expect(lines.count == 16)
        #expect(lines[1].contains("Dad & Mum,400,MYR,Birthday,Cash"))     // oldest first
    }

    @Test func escapingAndFormulaGuard() {
        #expect(ExportService.escape("a,b") == "\"a,b\"")
        #expect(ExportService.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(ExportService.escape("two\nlines") == "\"two\nlines\"")
        #expect(ExportService.escape("=SUM(A1)", neutraliseFormula: true) == "'=SUM(A1)")
        #expect(ExportService.escape("=SUM(A1)") == "=SUM(A1)")
    }

    @Test func amountsUseDotDecimals() throws {
        let context = try makeContext(seed: false)
        let blesser = Blesser(name: "Mei"); context.insert(blesser)
        context.insert(Blessing(amount: Decimal(string: "12.5")!, currencyCode: "EUR", blesser: blesser))
        #expect(try ExportService(context: context).csv().contains(",Mei,12.5,EUR,"))
    }
}

@MainActor
struct BackupTests {
    @Test func backupEraseRestoreReturnsIdenticalData() throws {
        let context = try makeContext()
        // Exercise optional fields too.
        let first = try #require(try context.fetch(FetchDescriptor<Blessing>()).first)
        let firstID = first.id
        first.photoData = Data([1, 2, 3, 4])
        first.originalAmount = Decimal(string: "186.48")
        first.originalCurrencyCode = "MYR"
        first.note = "note, with \"quotes\""
        context.insert(CurrencyConversion(fromCode: "MYR", toCode: "USD", rate: Decimal(string: "0.21")!, convertedAmounts: true, count: 15))
        try context.save()

        let service = ExportService(context: context)
        let before = try snapshot(context)
        let data = try service.backupData()

        try service.eraseAll()
        let erased = try snapshot(context)
        #expect(erased.blessings == 0 && erased.blessers == 0)

        try service.restore(from: data)
        let after = try snapshot(context)
        #expect(after.blessings == before.blessings)
        #expect(after.blessers == before.blessers)
        #expect(after.total == before.total && after.total == 9_776)
        #expect(after.pending == before.pending)

        let restored = try #require(try context.fetch(FetchDescriptor<Blessing>()).first { $0.id == first.id || $0.note.contains("quotes") })
        #expect(restored.photoData == Data([1, 2, 3, 4]))
        #expect(restored.originalAmount == Decimal(string: "186.48"))
        #expect(restored.note == "note, with \"quotes\"")
        #expect(restored.blesser != nil)
        #expect(try context.fetchCount(FetchDescriptor<CurrencyConversion>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<AppSettings>()) == 1)
    }

    @Test func restoreReplacesRatherThanMerges() throws {
        let context = try makeContext()
        let service = ExportService(context: context)
        let data = try service.backupData()
        let extra = Blesser(name: "Extra"); context.insert(extra)
        context.insert(Blessing(amount: 50, currencyCode: "MYR", blesser: extra))
        try context.save()
        try service.restore(from: data)
        let after = try snapshot(context)
        #expect(after.blessings == 15 && after.blessers == 6 && after.total == 9_776)
    }

    @Test func settingsRoundTrip() throws {
        let context = try makeContext()
        let settings = try #require(try context.fetch(FetchDescriptor<AppSettings>()).first)
        settings.themeID = "quiet"; settings.goal = Decimal(string: "12345.5")!; settings.reminderDays = 7
        let service = ExportService(context: context)
        let data = try service.backupData()
        try service.eraseAll()
        try service.restore(from: data)
        let restored = try #require(try context.fetch(FetchDescriptor<AppSettings>()).first)
        #expect(restored.themeID == "quiet" && restored.goal == Decimal(string: "12345.5")! && restored.reminderDays == 7)
        #expect(restored.hasOnboarded)
    }

    @Test func badFilesGiveFriendlyErrorsAndChangeNothing() throws {
        let context = try makeContext()
        let service = ExportService(context: context)
        let before = try snapshot(context)

        #expect(throws: ExportError.notABackup) { try service.restore(from: Data("hello".utf8)) }
        #expect(throws: ExportError.notABackup) { try service.restore(from: Data("{\"foo\":1}".utf8)) }
        #expect(throws: ExportError.unsupportedVersion(99)) { try service.restore(from: Data("{\"schemaVersion\":99}".utf8)) }
        #expect(throws: ExportError.corrupt) { try service.restore(from: Data("{\"schemaVersion\":1}".utf8)) }

        // Valid shape, but a blessing points at a blesser that isn't in the file.
        var file = try service.backupFile()
        file.blessings[0].blesserID = UUID()
        let encoder = JSONEncoder()
        #expect(throws: ExportError.corrupt) { try service.restore(from: try encoder.encode(file)) }

        // Valid shape, unparseable amount.
        var json = try #require(String(data: try service.backupData(), encoding: .utf8))
        let marker = try #require(json.range(of: "\"amount\" : \""))
        json.insert(contentsOf: "lots", at: marker.upperBound)
        #expect(throws: ExportError.corrupt) { try service.restore(from: Data(json.utf8)) }

        let after = try snapshot(context)
        #expect(after.blessings == before.blessings && after.total == before.total)
        #expect(ExportError.notABackup.errorDescription?.isEmpty == false)
    }

    @Test func eraseResetsSettingsToOnboarding() throws {
        let context = try makeContext()
        try ExportService(context: context).eraseAll()
        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        #expect(settings.count == 1 && settings[0].hasOnboarded == false)
        #expect(try context.fetchCount(FetchDescriptor<Blessing>()) == 0)
    }

    @Test func writesFilesToTempDirectory() throws {
        let service = ExportService(context: try makeContext())
        let csv = try service.writeCSV()
        let json = try service.writeBackup()
        #expect(csv.pathExtension == "csv" && json.pathExtension == "blessingz")
        #expect(FileManager.default.fileExists(atPath: csv.path) && FileManager.default.fileExists(atPath: json.path))
    }
}
