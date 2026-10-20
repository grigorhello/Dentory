import Foundation

/// A country of the sign-up select (f3): ISO 3166 alpha-2 code and its localized name.
nonisolated struct Country: Hashable, Sendable, Identifiable {
    let code: String
    let name: String

    var id: String { code }

    /// Every region the locale can name, sorted by name; the device's region first in the picker.
    static func all(locale: Locale = .current) -> [Country] {
        Locale.Region.isoRegions
            .filter { $0.identifier.count == 2 && $0.subRegions.isEmpty }
            .compactMap { region in
                locale.localizedString(forRegionCode: region.identifier)
                    .map { Country(code: region.identifier, name: $0) }
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func current(locale: Locale = .current, in countries: [Country]) -> Country? {
        guard let code = locale.region?.identifier else { return nil }
        return countries.first { $0.code == code }
    }
}
