import SwiftData
import Foundation

// MARK: - Legacy backup format (schemaVersion 1)
// Kept so backups made before the exchange format still restore. New backups are ExchangeFile (schema 2).

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
    case unreadable
    case olderBackup
    case notAFullBackup
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .notABackup:
            String(localized: "This isn't a Count 'Em Blessingz file.")
        case .unsupportedVersion:
            String(localized: "This file is from a newer version of the app.")
        case .corrupt:
            String(localized: "This file is damaged, so nothing was changed.")
        case .unreadable:
            String(localized: "That file couldn't be read.")
        case .olderBackup:
            String(localized: "This is an older backup. Use Restore from backup instead.")
        case .tooLarge:
            String(localized: "That file is too large to be a Count 'Em Blessingz file.")
        case .notAFullBackup:
            String(localized: "This file only has some entries, so it can't replace everything. Use Import from file to merge it.")
        }
    }
}

// MARK: - Service

struct ExportService {
    let context: ModelContext

    private static let posix = Locale(identifier: "en_US_POSIX")

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
                DecimalCoding.text(blessing.amount),
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
        try Data(csv().utf8).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    // MARK: Exchange files and backup

    /// Entries (and the people they belong to) as an exchange file.
    /// `.full` is everything; `includeBackupExtras` adds settings, conversion log and per-person and
    /// per-entry details so Restore is lossless. `.sinceLastExport` is only entries edited after the last share.
    func exchangeFile(kind: ExchangeFile.Kind, includeBackupExtras: Bool = false, now: Date = .now) throws -> ExchangeFile {
        let settings = try context.fetch(FetchDescriptor<AppSettings>()).first ?? AppSettings()
        let allBlessers = try context.fetch(FetchDescriptor<Blesser>(sortBy: [SortDescriptor(\.createdAt)]))
        var blessings = try context.fetch(FetchDescriptor<Blessing>(sortBy: [SortDescriptor(\.date)]))
        if kind == .sinceLastExport {
            let since = settings.lastExportAt ?? .distantPast
            blessings = blessings.filter { $0.updatedAt > since }
        }
        let referenced = Set(blessings.compactMap { $0.blesser?.id })
        let blessers = kind == .full ? allBlessers : allBlessers.filter { referenced.contains($0.id) }
        let extras = includeBackupExtras && kind == .full

        var settingsDTO: ExchangeFile.SettingsDTO?
        var conversions: [ExchangeFile.ConversionDTO]?
        if extras {
            settingsDTO = .init(
                hasOnboarded: settings.hasOnboarded, countryCode: settings.countryCode,
                currencyCode: settings.currencyCode, themeID: settings.themeID,
                faceIDEnabled: settings.faceIDEnabled, hideAmounts: settings.hideAmounts,
                goal: settings.goal, reminderDays: settings.reminderDays
            )
            let log = try context.fetch(FetchDescriptor<CurrencyConversion>(sortBy: [SortDescriptor(\.date)]))
            conversions = log.map {
                .init(date: $0.date, fromCode: $0.fromCode, toCode: $0.toCode, rate: $0.rate,
                      convertedAmounts: $0.convertedAmounts, count: $0.count)
            }
        }
        return ExchangeFile(
            schemaVersion: ExchangeFile.currentSchemaVersion, exportedAt: now,
            exportedBy: settings.effectiveDeviceLabel, deviceID: settings.deviceID,
            currencyCode: settings.currencyCode, kind: kind,
            blessers: blessers.map {
                .init(id: $0.id, name: $0.name, nameKey: $0.nameKey,
                      thankYouPending: extras ? $0.thankYouPending : nil, createdAt: extras ? $0.createdAt : nil)
            },
            blessings: blessings.map {
                .init(
                    id: $0.id, blesserID: $0.blesser?.id, amount: $0.amount, currencyCode: $0.currencyCode,
                    date: $0.date, occasion: $0.occasionRaw, method: $0.methodRaw, note: $0.note,
                    updatedAt: $0.updatedAt, photo: $0.photoData,
                    originalAmount: extras ? $0.originalAmount : nil,
                    originalCurrencyCode: extras ? $0.originalCurrencyCode : nil
                )
            },
            settings: settingsDTO, conversions: conversions
        )
    }

    /// How many entries "Share changes since last export" would include.
    func changedEntryCount() throws -> Int {
        let since = try context.fetch(FetchDescriptor<AppSettings>()).first?.lastExportAt ?? .distantPast
        return try context.fetchCount(FetchDescriptor<Blessing>(predicate: #Predicate { $0.updatedAt > since }))
    }

    /// The lossless backup: a `.full` exchange file with all extras.
    func backupFile(now: Date = .now) throws -> ExchangeFile {
        try exchangeFile(kind: .full, includeBackupExtras: true, now: now)
    }

    func backupData(now: Date = .now) throws -> Data {
        try ExchangeFileCodec.encode(backupFile(now: now))
    }

    func writeBackup(now: Date = .now) throws -> URL {
        let url = Self.tempURL(name: "CountEmBlessingz-backup-\(Self.dayStamp(now)).\(ExchangeFile.fileExtension)")
        try backupData(now: now).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    // MARK: Restore

    /// Replaces everything on this device with the file. Validates first; rolls back if inserting fails.
    /// Accepts current `.full` files and schema-1 backups. A file without extras (a plain "share all")
    /// replaces the entries and keeps this device's settings.
    func restore(from data: Data) throws {
        try restore(file: try ExchangeFileCodec.decode(data, allowLegacy: true))
    }

    /// Same, for a file that was already read and checked (the Settings flow reads it off the main thread).
    func restore(file: ExchangeFile) throws {
        guard file.kind == .full else { throw ExportError.notAFullBackup }
        let rollback = try backupFile()
        let previousExport = try context.fetch(FetchDescriptor<AppSettings>()).first?.lastExportAt
        do {
            try replaceAll(with: file)
        } catch {
            try? replaceAll(with: rollback)
            try? context.fetch(FetchDescriptor<AppSettings>()).first?.lastExportAt = previousExport
            throw error
        }
    }

    private func replaceAll(with file: ExchangeFile) throws {
        try deleteAllData()
        try context.save()

        let settings = try context.fetch(FetchDescriptor<AppSettings>()).first ?? {
            let created = AppSettings(); context.insert(created); return created
        }()
        // This phone keeps its own identity (deviceID, sharing name). Nothing was shared since the replace.
        settings.lastExportAt = nil
        if let s = file.settings {
            settings.hasOnboarded = s.hasOnboarded
            settings.countryCode = s.countryCode
            settings.currencyCode = s.currencyCode
            settings.themeID = s.themeID
            settings.faceIDEnabled = s.faceIDEnabled
            settings.hideAmounts = s.hideAmounts
            settings.goal = s.goal
            settings.reminderDays = s.reminderDays
        } else if settings.currencyCode != file.currencyCode {
            // Entries carry their own currency; keep the pot's currency consistent with them.
            settings.currencyCode = file.currencyCode
            if let country = CountryCatalog.all.first(where: { $0.currencyCode == file.currencyCode }) {
                settings.countryCode = country.code
            }
        }

        var blessersByID: [UUID: Blesser] = [:]
        for dto in file.blessers {
            let blesser = Blesser(name: dto.name)
            blesser.id = dto.id
            blesser.thankYouPending = dto.thankYouPending ?? false
            blesser.createdAt = dto.createdAt ?? .now
            context.insert(blesser)
            blessersByID[dto.id] = blesser
        }
        for dto in file.blessings {
            let blessing = Blessing(amount: dto.amount, currencyCode: dto.currencyCode, date: dto.date)
            blessing.id = dto.id
            blessing.occasionRaw = dto.occasion
            blessing.methodRaw = dto.method
            blessing.note = dto.note
            blessing.photoData = dto.photo
            blessing.updatedAt = dto.updatedAt
            blessing.originalAmount = dto.originalAmount
            blessing.originalCurrencyCode = dto.originalCurrencyCode
            context.insert(blessing)
            blessing.blesser = dto.blesserID.flatMap { blessersByID[$0] }
        }
        for dto in file.conversions ?? [] {
            context.insert(CurrencyConversion(
                date: dto.date, fromCode: dto.fromCode, toCode: dto.toCode,
                rate: dto.rate, convertedAmounts: dto.convertedAmounts, count: dto.count
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

// MARK: - Sharing

/// The two files "Share my entries" offers, built together so both describe the same moment.
struct SharePayload {
    let allFile: ExchangeFile
    let changesFile: ExchangeFile

    var changeCount: Int { changesFile.blessings.count }
}

extension ExportService {
    func sharePayload(now: Date = .now) throws -> SharePayload {
        SharePayload(
            allFile: try exchangeFile(kind: .full, now: now),
            changesFile: try exchangeFile(kind: .sinceLastExport, now: now)
        )
    }

    /// Called when a "changes since last export" file is actually handed to the system share sheet.
    /// The baseline becomes the time the file was *built* (not now), so anything edited while the share sheet
    /// was open is still included next time. It never moves backwards.
    func markShared(_ file: ExchangeFile) throws {
        guard file.kind == .sinceLastExport,
              let settings = try context.fetch(FetchDescriptor<AppSettings>()).first
        else { return }
        if let last = settings.lastExportAt, last >= file.exportedAt { return }
        settings.lastExportAt = file.exportedAt
        try context.save()
    }

    static func shareFileName(_ kind: ExchangeFile.Kind, now: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let label = kind == .full ? "entries" : "changes"
        return "CountEmBlessingz-\(label)-\(formatter.string(from: now)).\(ExchangeFile.fileExtension)"
    }
}
