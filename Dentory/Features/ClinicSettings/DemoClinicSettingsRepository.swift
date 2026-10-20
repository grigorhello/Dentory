import Foundation

/// The demo clinic's settings as f33 draws them, kept in memory: Smile Dental in Toronto, Canadian dollars, 30, 60 and
/// 90 days and the weekly digest on. It refuses a blank name the way the server does, and a save renames the preview
/// session's clinic, as the server's answer to the next session check would.
final class DemoClinicSettingsRepository: ClinicSettingsRepository, @unchecked Sendable {
    private let auth: PreviewAuthService?
    private var current = ClinicSettings(
        name: "Smile Dental", city: "Toronto", country: "CA", currency: "CAD", timeZone: "America/Toronto",
        expiryThresholds: [30, 60, 90], emailDigest: true, logoPath: nil
    )
    private var logoData: Data?
    private let lock = NSLock()

    init(auth: PreviewAuthService? = nil) {
        self.auth = auth
    }

    func settings(clinicID: UUID) async throws -> ClinicSettings {
        lock.withLock { current }
    }

    func save(clinicID: UUID, settings: ClinicSettings) async throws {
        guard !settings.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AppError.validation(field: "name", message: "Enter the clinic name")
        }
        lock.withLock { current = settings }
        if let auth, let session = auth.session {
            auth.session = Session(
                userID: session.userID, email: session.email, fullName: session.fullName, clinicID: session.clinicID,
                clinicName: settings.name, role: session.role, currency: settings.currency, timeZone: settings.timeZone
            )
        }
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
