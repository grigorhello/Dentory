import Foundation
import Supabase

/// Sign in, sign out and session restore. Returns the app's `Session`, never Supabase types.
protocol AuthServicing: Sendable {
    /// The session stored on the device, or nil when signed out.
    func restore() async throws -> Session?
    func signIn(email: String, password: String) async throws -> Session
    func signOut() async throws
}

struct SupabaseAuthService: AuthServicing {
    let client: SupabaseClient

    func restore() async throws -> Session? {
        guard let stored = client.auth.currentSession else { return nil }
        do {
            return try await session(for: stored.user)
        } catch AppError.notFound {
            // A user without an active membership has nothing to see; MS-112 handles invitations.
            return nil
        }
    }

    func signIn(email: String, password: String) async throws -> Session {
        do {
            let auth = try await client.auth.signIn(email: email, password: password)
            return try await session(for: auth.user)
        } catch {
            throw AppError(error)
        }
    }

    func signOut() async throws {
        do {
            try await client.auth.signOut()
        } catch {
            throw AppError(error)
        }
    }

    private func session(for user: User) async throws -> Session {
        let row: MembershipRow
        do {
            row = try await client
                .from("memberships")
                .select("role, full_name, clinic:clinics(id, name, currency, time_zone)")
                .eq("user_id", value: user.id.uuidString)
                .eq("status", value: "active")
                .limit(1)
                .single()
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
        return Session(
            userID: user.id,
            email: user.email ?? "",
            fullName: row.fullName,
            clinicID: row.clinic.id,
            clinicName: row.clinic.name,
            role: row.role,
            currency: row.clinic.currency,
            timeZone: row.clinic.timeZone
        )
    }

}

/// The membership row with its clinic, as the select above shapes it.
private nonisolated struct MembershipRow: Decodable {
    let role: MembershipRole
    let fullName: String
    let clinic: MembershipClinicRow
}

private nonisolated struct MembershipClinicRow: Decodable {
    let id: UUID
    let name: String
    let currency: String
    let timeZone: String
}
