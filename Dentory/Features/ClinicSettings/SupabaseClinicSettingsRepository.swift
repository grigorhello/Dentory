import Foundation
import Supabase

/// The clinic's row, `clinic_settings_save`, and the logo through `ClinicLogoStorage`.
struct SupabaseClinicSettingsRepository: ClinicSettingsRepository {
    let client: SupabaseClient

    func settings(clinicID: UUID) async throws -> ClinicSettings {
        do {
            return try await client.from("clinics")
                .select("name, city, country, currency, time_zone, expiry_thresholds, email_digest, logo_path")
                .eq("id", value: clinicID.uuidString)
                .single()
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }

    func save(clinicID: UUID, settings: ClinicSettings) async throws {
        do {
            let params = ClinicSettingsParams(clinicID: clinicID, settings: settings)
            try await client.rpc("clinic_settings_save", params: params).execute()
        } catch {
            throw AppError(error)
        }
    }

    func uploadLogo(clinicID: UUID, imageData: Data) async throws {
        try await ClinicLogoStorage(client: client).upload(clinicID: clinicID, imageData: imageData)
    }

    func logo(path: String) async throws -> Data {
        try await ClinicLogoStorage(client: client).download(path: path)
    }
}

/// `clinic_settings_save`'s arguments; the client's encoder writes them in snake_case.
nonisolated struct ClinicSettingsParams: Encodable, Sendable {
    let pClinicId: UUID
    let pName: String
    let pCity: String
    let pCountry: String
    let pCurrency: String
    let pTimeZone: String
    let pExpiryThresholds: [Int]
    let pEmailDigest: Bool

    init(clinicID: UUID, settings: ClinicSettings) {
        pClinicId = clinicID
        pName = settings.name
        pCity = settings.city ?? ""
        pCountry = settings.country
        pCurrency = settings.currency
        pTimeZone = settings.timeZone
        pExpiryThresholds = settings.expiryThresholds
        pEmailDigest = settings.emailDigest
    }
}
