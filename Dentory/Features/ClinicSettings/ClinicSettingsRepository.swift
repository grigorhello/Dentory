import Foundation

/// Clinic settings for the admin (MS-139): the clinic's fields, the save, and its logo in Storage.
protocol ClinicSettingsRepository: Sendable {
    func settings(clinicID: UUID) async throws -> ClinicSettings
    /// Throws `AppError.validation(field:)` with the sentence for the field it refuses ("name", "country", ...).
    func save(clinicID: UUID, settings: ClinicSettings) async throws
    func uploadLogo(clinicID: UUID, imageData: Data) async throws
    func logo(path: String) async throws -> Data
}
