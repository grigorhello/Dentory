import Foundation

/// The demo clinic's settings as f33 draws them, kept in memory: Smile Dental in Toronto, Canadian dollars, 30, 60 and
/// 90 days and the weekly digest on. It refuses a blank name the way the server does.
final class DemoClinicSettingsRepository: ClinicSettingsRepository, @unchecked Sendable {
    private var current = ClinicSettings(
        name: "Smile Dental", city: "Toronto", country: "CA", currency: "CAD", timeZone: "America/Toronto",
        expiryThresholds: [30, 60, 90], emailDigest: true, logoPath: nil
    )
    private var logoData: Data?
    private let lock = NSLock()

    func settings(clinicID: UUID) async throws -> ClinicSettings {
        lock.withLock { current }
    }

    func save(clinicID: UUID, settings: ClinicSettings) async throws {
        guard !settings.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AppError.validation(field: "name", message: "Enter the clinic name")
        }
        lock.withLock { current = settings }
    }

    func uploadLogo(clinicID: UUID, imageData: Data) async throws {
        lock.withLock {
            logoData = imageData
            current.logoPath = "demo/logo.jpg"
        }
    }

    func logo(path: String) async throws -> Data {
        guard let data = lock.withLock({ logoData }) else { throw AppError.notFound }
        return data
    }
}
