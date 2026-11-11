import Foundation
import UniformTypeIdentifiers
import CoreTransferable

extension UTType {
    /// `.blessingz` files: JSON that opens in Count 'Em Blessingz. Declared in Info.plist (project.yml).
    static let blessingzExchange = UTType(exportedAs: "com.example.countemblessingz.exchange", conformingTo: .json)
}

// MARK: - Decimal and date coding

/// Money travels as text ("186.48") so no digit is ever lost to floating point.
enum DecimalCoding {
    private static let posix = Locale(identifier: "en_US_POSIX")
    static func text(_ value: Decimal) -> String { "\(value)" }
    static func parse(_ text: String) -> Decimal? { Decimal(string: text, locale: posix) }
}

extension KeyedDecodingContainer {
    func decodeDecimal(forKey key: Key) throws -> Decimal {
        let text = try decode(String.self, forKey: key)
        guard let value = DecimalCoding.parse(text) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Not a number: \(text)")
        }
        return value
    }

    func decodeDecimalIfPresent(forKey key: Key) throws -> Decimal? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        return try decodeDecimal(forKey: key)
    }
}

extension KeyedEncodingContainer {
    mutating func encodeDecimal(_ value: Decimal, forKey key: Key) throws {
        try encode(DecimalCoding.text(value), forKey: key)
    }

    mutating func encodeDecimalIfPresent(_ value: Decimal?, forKey key: Key) throws {
        if let value { try encodeDecimal(value, forKey: key) }
    }
}

enum ExchangeDates {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let plain = ISO8601DateFormatter()

    static func string(_ date: Date) -> String { fractional.string(from: date) }
    static func date(_ text: String) -> Date? { fractional.date(from: text) ?? plain.date(from: text) }
}

// MARK: - The file

/// What people share to combine their entries (schemaVersion 2).
/// `kind == .full` backups may also carry the optional "extras" (settings, conversion log, per-person and
/// per-entry details) so Restore is lossless. Merge import ignores every extra.
struct ExchangeFile: Codable {
    static let currentSchemaVersion = 2
    static let fileExtension = "blessingz"

    enum Kind: String, Codable {
        case full
        case sinceLastExport
    }

    struct BlesserDTO: Codable, Equatable {
        var id: UUID
        var name: String
        var nameKey: String
        // extras
        var thankYouPending: Bool?
        var createdAt: Date?
    }

    struct BlessingDTO: Codable, Equatable {
        var id: UUID
        var blesserID: UUID?
        var amount: Decimal
        var currencyCode: String
        var date: Date
        var occasion: String             // Occasion.rawValue
        var method: String               // PaymentMethod.rawValue
        var note: String
        var updatedAt: Date
        var photo: Data?                 // base64 in JSON
        // extras
        var originalAmount: Decimal?
        var originalCurrencyCode: String?

        enum CodingKeys: String, CodingKey {
            case id, blesserID, amount, currencyCode, date, occasion, method, note, updatedAt, photo
            case originalAmount, originalCurrencyCode
        }
    }

    struct SettingsDTO: Codable, Equatable {
        var hasOnboarded: Bool
        var countryCode: String
        var currencyCode: String
        var themeID: String
        var faceIDEnabled: Bool
        var hideAmounts: Bool
        var goal: Decimal
        var reminderDays: Int

        enum CodingKeys: String, CodingKey {
            case hasOnboarded, countryCode, currencyCode, themeID, faceIDEnabled, hideAmounts, goal, reminderDays
        }
    }

    struct ConversionDTO: Codable, Equatable {
        var date: Date
        var fromCode: String
        var toCode: String
        var rate: Decimal
        var convertedAmounts: Bool
        var count: Int

        enum CodingKeys: String, CodingKey { case date, fromCode, toCode, rate, convertedAmounts, count }
    }

    var schemaVersion: Int
    var exportedAt: Date
    var exportedBy: String               // sender's sharing name
    var deviceID: UUID
    var currencyCode: String
    var kind: Kind
    var blessers: [BlesserDTO]
    var blessings: [BlessingDTO]
    // extras (backups only)
    var settings: SettingsDTO?
    var conversions: [ConversionDTO]?

    /// Every blessing must point at a listed person, and ids must be unique.
    func isConsistent() -> Bool {
        let blesserIDs = Set(blessers.map(\.id))
        guard blesserIDs.count == blessers.count,
              Set(blessings.map(\.id)).count == blessings.count
        else { return false }
        return blessings.allSatisfy { $0.blesserID.map(blesserIDs.contains) ?? true }
    }
}

extension ExchangeFile.BlessingDTO {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(UUID.self, forKey: .id),
            blesserID: try c.decodeIfPresent(UUID.self, forKey: .blesserID),
            amount: try c.decodeDecimal(forKey: .amount),
            currencyCode: try c.decode(String.self, forKey: .currencyCode),
            date: try c.decode(Date.self, forKey: .date),
            occasion: try c.decode(String.self, forKey: .occasion),
            method: try c.decode(String.self, forKey: .method),
            note: try c.decode(String.self, forKey: .note),
            updatedAt: try c.decode(Date.self, forKey: .updatedAt),
            photo: try c.decodeIfPresent(Data.self, forKey: .photo),
            originalAmount: try c.decodeDecimalIfPresent(forKey: .originalAmount),
            originalCurrencyCode: try c.decodeIfPresent(String.self, forKey: .originalCurrencyCode)
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(blesserID, forKey: .blesserID)
        try c.encodeDecimal(amount, forKey: .amount)
        try c.encode(currencyCode, forKey: .currencyCode)
        try c.encode(date, forKey: .date)
        try c.encode(occasion, forKey: .occasion)
        try c.encode(method, forKey: .method)
        try c.encode(note, forKey: .note)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(photo, forKey: .photo)
        try c.encodeDecimalIfPresent(originalAmount, forKey: .originalAmount)
        try c.encodeIfPresent(originalCurrencyCode, forKey: .originalCurrencyCode)
    }
}

extension ExchangeFile.SettingsDTO {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            hasOnboarded: try c.decode(Bool.self, forKey: .hasOnboarded),
            countryCode: try c.decode(String.self, forKey: .countryCode),
            currencyCode: try c.decode(String.self, forKey: .currencyCode),
            themeID: try c.decode(String.self, forKey: .themeID),
            faceIDEnabled: try c.decode(Bool.self, forKey: .faceIDEnabled),
            hideAmounts: try c.decode(Bool.self, forKey: .hideAmounts),
            goal: try c.decodeDecimal(forKey: .goal),
            reminderDays: try c.decode(Int.self, forKey: .reminderDays)
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(hasOnboarded, forKey: .hasOnboarded)
        try c.encode(countryCode, forKey: .countryCode)
        try c.encode(currencyCode, forKey: .currencyCode)
        try c.encode(themeID, forKey: .themeID)
        try c.encode(faceIDEnabled, forKey: .faceIDEnabled)
        try c.encode(hideAmounts, forKey: .hideAmounts)
        try c.encodeDecimal(goal, forKey: .goal)
        try c.encode(reminderDays, forKey: .reminderDays)
    }
}

extension ExchangeFile.ConversionDTO {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            date: try c.decode(Date.self, forKey: .date),
            fromCode: try c.decode(String.self, forKey: .fromCode),
            toCode: try c.decode(String.self, forKey: .toCode),
            rate: try c.decodeDecimal(forKey: .rate),
            convertedAmounts: try c.decode(Bool.self, forKey: .convertedAmounts),
            count: try c.decode(Int.self, forKey: .count)
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date, forKey: .date)
        try c.encode(fromCode, forKey: .fromCode)
        try c.encode(toCode, forKey: .toCode)
        try c.encodeDecimal(rate, forKey: .rate)
        try c.encode(convertedAmounts, forKey: .convertedAmounts)
        try c.encode(count, forKey: .count)
    }
}

// MARK: - Codec

enum ExchangeFileCodec {
    static func encode(_ file: ExchangeFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ExchangeDates.string(date))
        }
        return try encoder.encode(file)
    }

    /// Reads a file. Pure (no database), so it can run off the main thread.
    /// `allowLegacy` also accepts schema-1 backups (used by Restore, not by merge import).
    static func decode(_ data: Data, allowLegacy: Bool = false) throws -> ExchangeFile {
        struct Header: Decodable { let schemaVersion: Int }
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else {
            // A cut-off or damaged file of ours still has the entries key; anything else isn't ours at all.
            throw data.range(of: Data("\"blessings\"".utf8)) != nil ? ExportError.corrupt : ExportError.notABackup
        }

        switch header.schemaVersion {
        case 1:
            guard allowLegacy else { throw ExportError.olderBackup }
            guard let legacy = try? JSONDecoder().decode(BackupFile.self, from: data),
                  let file = ExchangeFile(legacy: legacy), file.isConsistent()
            else { throw ExportError.corrupt }
            return file
        case ExchangeFile.currentSchemaVersion:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let text = try decoder.singleValueContainer().decode(String.self)
                guard let date = ExchangeDates.date(text) else {
                    throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date: \(text)"))
                }
                return date
            }
            guard let file = try? decoder.decode(ExchangeFile.self, from: data), file.isConsistent() else {
                throw ExportError.corrupt
            }
            return file
        case let version where version > ExchangeFile.currentSchemaVersion:
            throw ExportError.unsupportedVersion(version)
        default:
            throw ExportError.notABackup
        }
    }
}

extension ExchangeFile {
    /// Upgrades a schema-1 backup so Restore can read files made before the exchange format existed.
    init?(legacy: BackupFile) {
        guard let goal = DecimalCoding.parse(legacy.settings.goal) else { return nil }
        var mapped: [BlessingDTO] = []
        for item in legacy.blessings {
            guard let amount = DecimalCoding.parse(item.amount) else { return nil }
            var original: Decimal?
            if let text = item.originalAmount {
                guard let parsed = DecimalCoding.parse(text) else { return nil }
                original = parsed
            }
            mapped.append(BlessingDTO(
                id: item.id, blesserID: item.blesserID, amount: amount, currencyCode: item.currencyCode,
                date: item.date, occasion: item.occasionRaw, method: item.methodRaw, note: item.note,
                updatedAt: item.date,                       // schema 1 had no edit time
                photo: item.photoData, originalAmount: original, originalCurrencyCode: item.originalCurrencyCode
            ))
        }
        var log: [ConversionDTO] = []
        for item in legacy.conversions {
            guard let rate = DecimalCoding.parse(item.rate) else { return nil }
            log.append(ConversionDTO(date: item.date, fromCode: item.fromCode, toCode: item.toCode, rate: rate,
                                     convertedAmounts: item.convertedAmounts, count: item.count))
        }
        let s = legacy.settings
        self.init(
            schemaVersion: ExchangeFile.currentSchemaVersion, exportedAt: legacy.exportedAt, exportedBy: "",
            deviceID: UUID(), currencyCode: s.currencyCode, kind: .full,
            blessers: legacy.blessers.map {
                BlesserDTO(id: $0.id, name: $0.name, nameKey: BlesserResolver.key(for: $0.name),
                           thankYouPending: $0.thankYouPending, createdAt: $0.createdAt)
            },
            blessings: mapped,
            settings: SettingsDTO(
                hasOnboarded: s.hasOnboarded, countryCode: s.countryCode, currencyCode: s.currencyCode,
                themeID: s.themeID, faceIDEnabled: s.faceIDEnabled, hideAmounts: s.hideAmounts,
                goal: goal, reminderDays: s.reminderDays
            ),
            conversions: log
        )
    }
}

/// Reads a file off the main thread; the caller then builds the review plan on the main actor.
enum ExchangeFileLoader {
    static func load(url: URL, allowLegacy: Bool = false) async throws -> ExchangeFile {
        try await Task.detached(priority: .userInitiated) {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { throw ExportError.unreadable }
            return try ExchangeFileCodec.decode(data, allowLegacy: allowLegacy)
        }.value
    }
}

// MARK: - Sharing

/// A prepared file handed to `ShareLink`. `onShared` runs when the system actually asks for the file.
struct ExchangeShareItem: Transferable {
    let data: Data
    let fileName: String
    let onShared: @Sendable () -> Void

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .blessingzExchange) { item in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(item.fileName)
            try item.data.write(to: url, options: .atomic)
            item.onShared()
            return SentTransferredFile(url)
        }
    }
}
