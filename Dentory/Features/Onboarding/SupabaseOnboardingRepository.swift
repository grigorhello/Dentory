import Foundation
import Supabase

struct SupabaseOnboardingRepository: OnboardingRepository {
    let client: SupabaseClient

    func createClinic(
        name: String, city: String, country: String, timeZone: String, fullName: String
    ) async throws -> UUID {
        do {
            let params: [String: AnyJSON] = [
                "p_name": .string(name), "p_city": .string(city), "p_country": .string(country),
                "p_time_zone": .string(timeZone), "p_full_name": .string(fullName)
            ]
            return try await client.rpc("clinic_create", params: params).execute().value
        } catch {
            throw AppError(error)
        }
    }

    func uploadLogo(clinicID: UUID, imageData: Data) async throws {
        let path = "\(clinicID.uuidString.lowercased())/logo.jpg"
        do {
            try await client.storage.from("logos").upload(path, data: imageData, options: FileOptions(upsert: true))
            try await client.from("clinics").update(["logo_path": path]).eq("id", value: clinicID.uuidString).execute()
        } catch {
            throw AppError(error)
        }
    }

    func invite(clinicID: UUID, invites: [TeamInvite]) async throws -> Int {
        do {
            let rows: [AnyJSON] = invites.map {
                .object(["email": .string($0.email), "role": .string($0.role.rawValue)])
            }
            let params: [String: AnyJSON] = ["p_clinic_id": .string(clinicID.uuidString), "p_invites": .array(rows)]
            return try await client.rpc("invite_members", params: params).execute().value
        } catch {
            throw AppError(error)
        }
    }
}
