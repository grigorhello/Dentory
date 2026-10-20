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
