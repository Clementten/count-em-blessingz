import Foundation

struct Country: Identifiable, Hashable {
    let code: String          // ISO 3166 alpha-2
    let name: String
    let currencyCode: String  // ISO 4217
    var id: String { code }
}

enum CountryCatalog {
    static let all: [Country] = {
        Locale.Region.isoRegions
            .map(\.identifier)
            .filter { $0.count == 2 }
            .compactMap { code -> Country? in
                guard let name = Locale.current.localizedString(forRegionCode: code),
                      let currency = Locale(identifier: "en_\(code)").currency?.identifier
                else { return nil }
                return Country(code: code, name: name, currencyCode: currency)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()

    /// The country for the device's region, if it is in the catalog.
    static var deviceDefault: Country? {
        guard let region = Locale.current.region?.identifier else { return nil }
        return country(code: region)
    }

    static func country(code: String) -> Country? {
        all.first { $0.code == code }
    }

    static func search(_ query: String) -> [Country] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.currencyCode.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
