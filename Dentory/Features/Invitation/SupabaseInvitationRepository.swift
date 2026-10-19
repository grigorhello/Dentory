import Foundation
import Supabase

struct SupabaseInvitationRepository: InvitationRepository {
    let client: SupabaseClient

    func invitation(token: String) async throws -> Invitation? {
        let rows: [InvitationRow]
        do {
            rows = try await client.rpc("invitation_lookup", params: ["p_token": token]).execute().value
        } catch {
            throw AppError(error)
        }
        return rows.first.map(Invitation.init(row:))
    }

    func accept(token: String, fullName: String, password: String) async throws {
        let body: [String: AnyJSON] = [
            "token": .string(token), "full_name": .string(fullName), "password": .string(password)
        ]
        do {
            try await client.functions.invoke("accept_invitation", options: FunctionInvokeOptions(body: body))
        } catch {
            throw AppError(functionError: error)
        }
    }
}

/// A row of `invitation_lookup`.
nonisolated struct InvitationRow: Decodable, Sendable {
    let clinicName: String
    let invitedByName: String
    let memberRole: MembershipRole
    let email: String
    let fullName: String
    let expiresAt: Date
}

extension Invitation {
    nonisolated init(row: InvitationRow) {
        self.init(
            clinicName: row.clinicName,
            invitedByName: row.invitedByName,
            role: row.memberRole,
            email: row.email,
            fullName: row.fullName,
            expiresAt: row.expiresAt
        )
    }
}
