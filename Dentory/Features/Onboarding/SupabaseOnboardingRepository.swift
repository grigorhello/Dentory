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
        try await ClinicLogoStorage(client: client).upload(clinicID: clinicID, imageData: imageData)
    }

    /// One `invite_member` call per address, in order: each records the invited row with a fresh token and
    /// sends the email. The first refusal stops the loop and names its address in `AppError.validation(field:)`.
    func invite(clinicID: UUID, invites: [TeamInvite]) async throws -> Int {
        for invite in invites {
            let body: [String: AnyJSON] = [
                "clinic_id": .string(clinicID.uuidString.lowercased()),
                "email": .string(invite.email),
                "role": .string(invite.role.rawValue)
            ]
            do {
                try await client.functions.invoke("invite_member", options: FunctionInvokeOptions(body: body))
            } catch {
                let appError = AppError(functionError: error)
                if case .validation(_, let message) = appError {
                    throw AppError.validation(field: invite.email, message: message)
                }
                throw appError
            }
        }
        return invites.count
    }
}
