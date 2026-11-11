import SwiftData
import Foundation

// MARK: - Backup file format (schemaVersion 1)

struct BackupFile: Codable {
    static let currentSchemaVersion = 1

    struct SettingsDTO: Codable {
        var hasOnboarded: Bool
        var countryCode: String
        var currencyCode: String
        var themeID: String
        var faceIDEnabled: Bool
        var hideAmounts: Bool
        var goal: String                 // Decimal as text, so nothing is lost to floating point
        var reminderDays: Int
    }

    struct BlesserDTO: Codable {
        var id: UUID
        var name: String
        var thankYouPending: Bool
        var createdAt: Date
    }

    struct BlessingDTO: Codable {
        var id: UUID
        var amount: String
        var currencyCode: String
        var date: Date
        var occasionRaw: String
        var methodRaw: String
        var note: String
        var photoData: Data?             // base64 in JSON
        var originalAmount: String?
        var originalCurrencyCode: String?
        var blesserID: UUID?
    }

    struct ConversionDTO: Codable {
        var date: Date
        var fromCode: String
        var toCode: String
        var rate: String
        var convertedAmounts: Bool
        var count: Int
    }

    var schemaVersion: Int
    var exportedAt: Date
    var settings: SettingsDTO
    var blessers: [BlesserDTO]
    var blessings: [BlessingDTO]
    var conversions: [ConversionDTO]
}

enum ExportError: LocalizedError, Equatable {
    case notABackup
    case unsupportedVersion(Int)
    case corrupt

    var errorDescription: String? {
        switch self {
        case .notABackup:
            String(localized: "That file isn't a Count 'Em Blessingz backup.")
        case .unsupportedVersion(let version):
            String(localized: "This backup is from a newer version of the app (format \(version)). Update the app and try again.")
        case .corrupt:
            String(localized: "This backup file is damaged, so nothing was changed.")
        }
    }
}

// MARK: - Service

struct ExportService {
    let context: ModelContext

    private static let posix = Locale(identifier: "en_US_POSIX")

    private static func text(_ value: Decimal) -> String { "\(value)" }
    private static func decimal(_ text: String) -> Decimal? { Decimal(string: text, locale: posix) }

    // MARK: CSV

    private static let csvHeader = "date,name,amount,currency,occasion,method,note"

    func csv() throws -> String {
        let blessings = try context.fetch(FetchDescriptor<Blessing>(sortBy: [SortDescriptor(\.date)]))
        let formatter = ISO8601DateFormatter()
        var lines = [Self.csvHeader]
        for blessing in blessings {
            let fields = [
                formatter.string(from: blessing.date),
                blessing.blesser?.name ?? "",
                Self.text(blessing.amount),
                blessing.currencyCode,
                blessing.occasion.title,
                blessing.method.title,
                blessing.note,
            ]
            lines.append(fields.enumerated().map { index, field in
                // Free-text columns (name, note) are neutralised against spreadsheet formula injection.
                Self.escape(field, neutraliseFormula: index == 1 || index == 6)
            }.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func escape(_ field: String, neutraliseFormula: Bool = false) -> String {
        var value = field
        if neutraliseFormula, let first = value.first, "=+-@\t\r".contains(first) { value = "'" + value }
        guard value.contains(where: { ",\"\n\r".contains($0) }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    func writeCSV(now: Date = .now) throws -> URL {
        let url = Self.tempURL(name: "CountEmBlessingz-\(Self.dayStamp(now)).csv")
        try csv().write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: Backup

    func backupFile(now: Date = .now) throws -> BackupFile {
        let settings = try context.fetch(FetchDescriptor<AppSettings>()).first ?? AppSettings()
        let blessers = try context.fetch(FetchDescriptor<Blesser>(sortBy: [SortDescriptor(\.createdAt)]))
        let blessings = try context.fetch(FetchDescriptor<Blessing>(sortBy: [SortDescriptor(\.date)]))
        let conversions = try context.fetch(FetchDescriptor<CurrencyConversion>(sortBy: [SortDescriptor(\.date)]))
        return BackupFile(
            schemaVersion: BackupFile.currentSchemaVersion,
            exportedAt: now,
            settings: .init(
                hasOnboarded: settings.hasOnboarded, countryCode: settings.countryCode,
                currencyCode: settings.currencyCode, themeID: settings.themeID,
                faceIDEnabled: settings.faceIDEnabled, hideAmounts: settings.hideAmounts,
                goal: Self.text(settings.goal), reminderDays: settings.reminderDays
            ),
            blessers: blessers.map {
                .init(id: $0.id, name: $0.name, thankYouPending: $0.thankYouPending, createdAt: $0.createdAt)
            },
            blessings: blessings.map {
                .init(
                    id: $0.id, amount: Self.text($0.amount), currencyCode: $0.currencyCode, date: $0.date,
                    occasionRaw: $0.occasionRaw, methodRaw: $0.methodRaw, note: $0.note, photoData: $0.photoData,
                    originalAmount: $0.originalAmount.map(Self.text), originalCurrencyCode: $0.originalCurrencyCode,
                    blesserID: $0.blesser?.id
                )
            },
            conversions: conversions.map {
                .init(date: $0.date, fromCode: $0.fromCode, toCode: $0.toCode, rate: Self.text($0.rate),
                      convertedAmounts: $0.convertedAmounts, count: $0.count)
            }
        )
    }

    func backupData(now: Date = .now) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backupFile(now: now))
    }

    func writeBackup(now: Date = .now) throws -> URL {
        let url = Self.tempURL(name: "CountEmBlessingz-backup-\(Self.dayStamp(now)).json")
        try backupData(now: now).write(to: url, options: .atomic)
        return url
    }

    // MARK: Restore

    /// Replaces everything on this device with the backup. Validates first; rolls back if inserting fails.
    func restore(from data: Data) throws {
        let file = try Self.decode(data)
        try Self.validate(file)
        let rollback = try backupFile()
        do {
            try replaceAll(with: file)
        } catch {
            try? replaceAll(with: rollback)
            throw error
        }
    }

    private static func decode(_ data: Data) throws -> BackupFile {
        struct Header: Decodable { let schemaVersion: Int }
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else { throw ExportError.notABackup }
        guard header.schemaVersion == BackupFile.currentSchemaVersion else {
            throw ExportError.unsupportedVersion(header.schemaVersion)
        }
        guard let file = try? JSONDecoder().decode(BackupFile.self, from: data) else { throw ExportError.corrupt }
        return file
    }

    private static func validate(_ file: BackupFile) throws {
        let blesserIDs = file.blessers.map(\.id)
        guard Set(blesserIDs).count == blesserIDs.count,
              Set(file.blessings.map(\.id)).count == file.blessings.count,
              decimal(file.settings.goal) != nil,
              file.blessings.allSatisfy({
                  decimal($0.amount) != nil && ($0.originalAmount.map { decimal($0) != nil } ?? true)
                      && ($0.blesserID.map { Set(blesserIDs).contains($0) } ?? true)
              }),
              file.conversions.allSatisfy({ decimal($0.rate) != nil })
        else { throw ExportError.corrupt }
    }

    private func replaceAll(with file: BackupFile) throws {
        try deleteAllData()
        try context.save()

        let settings = try context.fetch(FetchDescriptor<AppSettings>()).first ?? {
            let created = AppSettings(); context.insert(created); return created
        }()
        let s = file.settings
        settings.hasOnboarded = s.hasOnboarded
        settings.countryCode = s.countryCode
        settings.currencyCode = s.currencyCode
        settings.themeID = s.themeID
        settings.faceIDEnabled = s.faceIDEnabled
        settings.hideAmounts = s.hideAmounts
        settings.goal = Self.decimal(s.goal) ?? 20_000
        settings.reminderDays = s.reminderDays

        var blessersByID: [UUID: Blesser] = [:]
        for dto in file.blessers {
            let blesser = Blesser(name: dto.name)
            blesser.id = dto.id
            blesser.thankYouPending = dto.thankYouPending
            blesser.createdAt = dto.createdAt
            context.insert(blesser)
            blessersByID[dto.id] = blesser
        }
        for dto in file.blessings {
            let blessing = Blessing(amount: Self.decimal(dto.amount) ?? 0, currencyCode: dto.currencyCode, date: dto.date)
            blessing.id = dto.id
            blessing.occasionRaw = dto.occasionRaw
            blessing.methodRaw = dto.methodRaw
            blessing.note = dto.note
            blessing.photoData = dto.photoData
            blessing.originalAmount = dto.originalAmount.flatMap(Self.decimal)
            blessing.originalCurrencyCode = dto.originalCurrencyCode
            context.insert(blessing)
            blessing.blesser = dto.blesserID.flatMap { blessersByID[$0] }
        }
        for dto in file.conversions {
            context.insert(CurrencyConversion(
                date: dto.date, fromCode: dto.fromCode, toCode: dto.toCode,
                rate: Self.decimal(dto.rate) ?? 1, convertedAmounts: dto.convertedAmounts, count: dto.count
            ))
        }
        try context.save()
    }

    // MARK: Erase

    /// Deletes all blessings, blessers and conversion logs, and resets settings (back to onboarding).
    func eraseAll() throws {
        try deleteAllData()
        // Reset the existing row in place: views are bound to it, so deleting it would leave them dangling.
        if let settings = try context.fetch(FetchDescriptor<AppSettings>()).first {
            settings.resetToDefaults()
        } else {
            context.insert(AppSettings())
        }
        try context.save()
    }

    private func deleteAllData() throws {
        for blessing in try context.fetch(FetchDescriptor<Blessing>()) { context.delete(blessing) }
        for blesser in try context.fetch(FetchDescriptor<Blesser>()) { context.delete(blesser) }
        for conversion in try context.fetch(FetchDescriptor<CurrencyConversion>()) { context.delete(conversion) }
    }

    // MARK: Helpers

    private static func tempURL(name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    private static func dayStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = posix
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
