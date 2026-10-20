import Foundation

/// The clinic as Clinic settings edits it (f33, PRD §6.9, MS-100 D14), read from `clinics` with the client's decoder
/// (snake_case keys) and saved through `clinic_settings_save`.
nonisolated struct ClinicSettings: Codable, Equatable, Sendable {
    var name: String
    var city: String?
    /// ISO 3166 alpha-2, as "CA".
    var country: String
    /// ISO 4217, as "CAD".
    var currency: String
    /// IANA name, as "America/Toronto".
    var timeZone: String
    /// {30, 60, 90}, {60, 90} or {90} (MS-100 D8).
    var expiryThresholds: [Int]
    var emailDigest: Bool
    var logoPath: String?
}

/// Expiry warning (f33, MS-100 D8): which thresholds raise an Expiring alert; a batch is Expiring within the largest.
nonisolated enum ExpiryWarning: CaseIterable, Hashable, Sendable {
    case thirtySixtyNinety
    case sixtyNinety
    case ninetyOnly

    init(thresholds: [Int]) {
        self = Self.allCases.first { $0.thresholds == thresholds.sorted() } ?? .thirtySixtyNinety
    }

    var thresholds: [Int] {
        switch self {
        case .thirtySixtyNinety: [30, 60, 90]
        case .sixtyNinety: [60, 90]
        case .ninetyOnly: [90]
        }
    }

    var label: String {
        switch self {
        case .thirtySixtyNinety: "30, 60 and 90 days"
        case .sixtyNinety: "60 and 90 days"
        case .ninetyOnly: "90 days only"
        }
    }
}
