import Foundation
import Supabase

/// The team RPCs, and the `invite_member` Edge Function for invitations and resends.
struct SupabaseTeamRepository: TeamRepository {
    let client: SupabaseClient

    func members(clinicID: UUID) async throws -> [TeamMember] {
        do {
            return try await client
                .rpc("team_members", params: ["p_clinic_id": clinicID.uuidString.lowercased()])
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }

    func invite(clinicID: UUID, fullName: String, email: String, role: MembershipRole) async throws {
        let body: [String: AnyJSON] = [
            "clinic_id": .string(clinicID.uuidString.lowercased()),
            "email": .string(email),
            "role": .string(role.rawValue),
            "full_name": .string(fullName)
        ]
        do {
            try await client.functions.invoke("invite_member", options: FunctionInvokeOptions(body: body))
        } catch {
            throw AppError(functionError: error)
        }
    }

    func setRole(memberID: UUID, role: MembershipRole) async throws {
        do {
            let params = TeamRoleParams(pMembershipId: memberID, pRole: role)
            try await client.rpc("team_set_role", params: params).execute()
        } catch {
            throw AppError(error)
        }
    }

    func remove(memberID: UUID) async throws {
        do {
            try await client.rpc("team_remove", params: ["p_membership_id": memberID.uuidString.lowercased()]).execute()
        } catch {
            throw AppError(error)
        }
    }
}
