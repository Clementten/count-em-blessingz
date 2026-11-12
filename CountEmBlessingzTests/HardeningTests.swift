import Testing
import SwiftUI
import SwiftData
import Foundation
@testable import CountEmBlessingz

private let t0 = Date(timeIntervalSince1970: 1_750_000_000)

private func file(amount: Decimal = 10, name: String = "Lin", note: String = "") -> ExchangeFile {
    let person = UUID()
    return ExchangeFile(
        schemaVersion: 2, exportedAt: t0, exportedBy: "A", deviceID: UUID(), currencyCode: "MYR", kind: .full,
        blessers: [.init(id: person, name: name, nameKey: name.lowercased())],
        blessings: [.init(id: UUID(), blesserID: person, amount: amount, currencyCode: "MYR", date: t0,
                          occasion: "other", method: "cash", note: note, updatedAt: t0)]
    )
}

struct ImportedFileValidationTests {
    @Test(arguments: [Decimal(-1), Decimal(string: "-0.01")!, Decimal(2_000_000_000_000), Decimal(string: "1e30")!])
    func implausibleAmountsAreRejected(amount: Decimal) throws {
        let data = try ExchangeFileCodec.encode(file(amount: amount))
        #expect(throws: ExportError.corrupt) { try ExchangeFileCodec.decode(data) }
    }

    @Test(arguments: [Decimal(0), Decimal(string: "0.01")!, Decimal(1_000_000_000_000)])
    func ordinaryAndEdgeAmountsAreAccepted(amount: Decimal) throws {
        #expect(try ExchangeFileCodec.decode(try ExchangeFileCodec.encode(file(amount: amount))).blessings[0].amount == amount)
    }

    @Test(arguments: ["", "   ", "\n\t"])
    func namelessPeopleAreRejected(name: String) throws {
        #expect(throws: ExportError.corrupt) { try ExchangeFileCodec.decode(try ExchangeFileCodec.encode(file(name: name))) }
    }

    @Test func oversizedTextIsRejected() throws {
        #expect(throws: ExportError.corrupt) {
            try ExchangeFileCodec.decode(try ExchangeFileCodec.encode(file(name: String(repeating: "x", count: 501))))
        }
        #expect(throws: ExportError.corrupt) {
            try ExchangeFileCodec.decode(try ExchangeFileCodec.encode(file(note: String(repeating: "x", count: 20_001))))
        }
    }

    @Test(arguments: [
        Decimal(0), 1, Decimal(string: "0.1")!, Decimal(string: "186.48")!, Decimal(string: "0.0000001")!,
        Decimal(string: "1e-20")!, Decimal(string: "123456789012345678.123456789")!, Decimal(string: "1e28")!, Decimal(-5),
    ])
    func everyDecimalWeWriteIsReadBackExactly(value: Decimal) {
        #expect(DecimalCoding.parse(DecimalCoding.text(value)) == value, "\(DecimalCoding.text(value))")
    }

    @Test(arguments: ["0x10", "1e3", "1E3", "+5", "5.", ".5", "1,000", "12abc", "--5", "NaN", "inf", "", " ", "1 2", "٣"])
    func decimalTextIsStrict(text: String) {
        #expect(DecimalCoding.parse(text) == nil, "\"\(text)\" must not parse")
    }

    @Test func garbageThatLooksLikeNumbersIsRejectedNotCrashing() {
        for amount in ["NaN", "Infinity", "1e999", "--5", "0x10", "", " "] {
            let json = """
            {"schemaVersion":2,"exportedAt":"2026-01-01T00:00:00.000Z","exportedBy":"A","deviceID":"\(UUID())","currencyCode":"MYR","kind":"full",
             "blessers":[{"id":"\(UUID())","name":"Lin","nameKey":"lin"}],
             "blessings":[{"id":"\(UUID())","amount":"\(amount)","currencyCode":"MYR","date":"2026-01-01T00:00:00.000Z","occasion":"other",
             "method":"cash","note":"","updatedAt":"2026-01-01T00:00:00.000Z"}]}
            """
            #expect(throws: ExportError.self) { try ExchangeFileCodec.decode(Data(json.utf8)) }
        }
    }

    @Test func tooLargeAFileIsRefusedWithoutReadingIt() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "huge-\(UUID().uuidString).blessingz")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(ExchangeFile.Limits.maxFileBytes + 1))     // sparse: no real disk used
        try handle.close()
        defer { try? FileManager.default.removeItem(at: url) }
        await #expect(throws: ExportError.tooLarge) { _ = try await ExchangeFileLoader.load(url: url) }
        #expect(ExportError.tooLarge.errorDescription?.isEmpty == false)
    }
}

@MainActor
struct OpenedLinkTests {
    @Test func onlyFilesAreAccepted() {
        let coordinator = ImportCoordinator()
        coordinator.receive(URL(string: "https://example.com/x.blessingz")!)
        #expect(coordinator.pendingURL == nil && coordinator.errorMessage == "This isn't a Count 'Em Blessingz file.")
        coordinator.errorMessage = nil
        coordinator.receive(URL(string: "countem://import?x=1")!)
        #expect(coordinator.pendingURL == nil && coordinator.errorMessage != nil)
        coordinator.errorMessage = nil
        coordinator.receive(URL(fileURLWithPath: "/tmp/a.blessingz"))
        #expect(coordinator.pendingURL != nil && coordinator.errorMessage == nil)
    }
}

@MainActor
struct HiddenAmountsTests {
    @Test func theSavedToastNeverRevealsTheAmountWhenHidden() {
        let shown = BlessingEditorSheet.savedMessage(name: "Aunt Mei", amount: 888, currency: "MYR", hideAmounts: false)
        let hidden = BlessingEditorSheet.savedMessage(name: "Aunt Mei", amount: 888, currency: "MYR", hideAmounts: true)
        #expect(shown.contains("888") && shown.contains("Aunt Mei"))
        #expect(!hidden.contains("888") && hidden == "Saved: Aunt Mei")
    }

    @Test func convertedEntriesShowWhatTheyWereWorthBefore() {
        func line(_ original: Decimal?, _ code: String?, current: Decimal? = 470, _ currency: String = "MYR", hide: Bool = false) -> String? {
            BlessingEditorSheet.originalLine(originalAmount: original, originalCurrency: code, currentAmount: current,
                                             currentCurrency: currency, hideAmounts: hide)
        }
        #expect(line(100, "USD") == "Originally USD 100")                  // converted from another currency
        #expect(line(100, "USD", hide: true) == "Originally USD ••••")      // still private
        #expect(line(888, "MYR", current: 888) == nil)                      // label-only change: nothing to say
        #expect(line(888, "MYR", current: 900) == "Originally MYR 888")     // amount differs
        #expect(line(nil, nil) == nil)                                      // never converted
    }

    @Test func milestoneMagnitudeIsHiddenToo() {
        let shown = BlessingEditorSheet.savedMessage(name: "Mei", amount: 300, currency: "MYR", hideAmounts: false, milestone: 10_000)
        let hidden = BlessingEditorSheet.savedMessage(name: "Mei", amount: 300, currency: "MYR", hideAmounts: true, milestone: 10_000)
        #expect(shown.contains("10k"))
        #expect(!hidden.contains("10") && !hidden.contains("300") && hidden == "Saved: Mei · Milestone reached!")
    }

    @Test func snapshotsAreProtectedAndKeptOutOfBackups() throws {
        let container = try ModelContainer(
            for: Blessing.self, Blesser.self, AppSettings.self, CurrencyConversion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        SeedData.insert(into: context)
        let directory = FileManager.default.temporaryDirectory.appending(path: "snap-\(UUID().uuidString)")
        var service = ImportService(context: context, snapshotDirectory: directory)
        service.now = { .now }
        let other = try ExportService(context: context).exchangeFile(kind: .full)
        var changed = other
        changed.blessings[0].id = UUID()
        var plan = try service.buildPlan(file: changed)
        plan.selectAll()                                    // it looks like a duplicate, so it starts unticked
        try service.commit(plan)
        let excluded = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup
        #expect(excluded == true)
    }
}
