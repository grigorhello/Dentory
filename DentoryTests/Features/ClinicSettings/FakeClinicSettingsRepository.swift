import Foundation
@testable import Dentory

/// Answers `stored`, records each save and logo, and throws `saveFailure` or `logoFailure` when set.
final class FakeClinicSettingsRepository: ClinicSettingsRepository, @unchecked Sendable {
    var stored = ClinicSettings(
        name: "Smile Dental", city: "Toronto", country: "CA", currency: "CAD", timeZone: "America/Toronto",
        expiryThresholds: [30, 60, 90], emailDigest: true, logoPath: nil
    )
    var saveFailure: Error?
    var logoFailure: Error?
    private(set) var saves: [ClinicSettings] = []
    private(set) var logos: [Data] = []

    func settings(clinicID: UUID) async throws -> ClinicSettings {
        stored
    }

    func save(clinicID: UUID, settings: ClinicSettings) async throws {
        if let saveFailure { throw saveFailure }
        saves.append(settings)
        stored = settings
    }

    func uploadLogo(clinicID: UUID, imageData: Data) async throws {
        if let logoFailure { throw logoFailure }
        logos.append(imageData)
    }

    func logo(path: String) async throws -> Data {
        Data("logo".utf8)
    }
}
