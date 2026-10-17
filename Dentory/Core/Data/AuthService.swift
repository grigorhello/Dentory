import Foundation
import Supabase

/// Sign in, sign up, sign out and session restore. Returns the app's `Session`, never Supabase types.
protocol AuthServicing: Sendable {
    /// What the device holds: nothing, a session, or a user who has not created a clinic yet. Throws
    /// `AppError.forbidden` when the stored user's membership was revoked; the device session is dropped.
    func restore() async throws -> RestoredSession
    /// Throws `AppError.validation(field: "email" | "password", …)` with the PRD copy for a refused
    /// sign-in, `AppError.forbidden` when the account has no active membership.
    func signIn(email: String, password: String) async throws -> Session
    /// Creates the auth user (admin sign-up step 1). Throws `AppError.emailTaken` for a known address.
    func signUp(fullName: String, email: String, password: String) async throws -> Account
    func signOut() async throws
}

extension AppError {
    static let unknownEmail = AppError.validation(field: "email", message: "No account with this email.")
    static let wrongPassword = AppError.validation(field: "password", message: "Wrong password.")
    static let emailTaken = AppError.validation(
        field: "email", message: "An account with this email already exists. Sign in instead."
    )
}

struct SupabaseAuthService: AuthServicing {
    let client: SupabaseClient

    func restore() async throws -> RestoredSession {
        guard let stored = client.auth.currentSession else { return .none }
        do {
            return .signedIn(try await session(for: stored.user))
        } catch AppError.notFound {
            if try await hasAnyMembership(user: stored.user) {
                // The membership was revoked (or never accepted): drop the device session.
                try? await client.auth.signOut()
                throw AppError.forbidden
            }
            // Signed up, no clinic yet: admin sign-up resumes at step 2.
            return .needsClinic(Account(
                userID: stored.user.id,
                email: stored.user.email ?? "",
                fullName: stored.user.userMetadata["full_name"]?.stringValue ?? ""
            ))
        }
    }

    func signUp(fullName: String, email: String, password: String) async throws -> Account {
        do {
            let response = try await client.auth.signUp(
                email: email, password: password, data: ["full_name": .string(fullName)]
            )
            return Account(userID: response.user.id, email: response.user.email ?? email, fullName: fullName)
        } catch let error as AuthError {
            throw Self.appError(for: error)
        } catch {
            throw AppError(error)
        }
    }

    private func hasAnyMembership(user: User) async throws -> Bool {
        let rows: [MembershipStatusRow]
        do {
            rows = try await client.from("memberships")
                .select("status")
                .eq("user_id", value: user.id.uuidString)
                .limit(1)
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
        return !rows.isEmpty
    }

    func signIn(email: String, password: String) async throws -> Session {
        let user: User
        do {
            user = try await client.auth.signIn(email: email, password: password).user
        } catch let error as AuthError {
            throw Self.appError(for: error)
        } catch {
            throw AppError(error)
        }
        do {
            return try await session(for: user)
        } catch AppError.notFound {
            try? await client.auth.signOut()
            throw AppError.forbidden
        }
    }

    /// Supabase answers a wrong password and an unknown email alike (`invalid_credentials`), so both
    /// show under the password field; `user_not_found` is the one case it names the email.
    static func appError(for error: AuthError) -> AppError {
        guard case .api(_, let code, _, _) = error else { return AppError(error) }
        switch code {
        case .userNotFound: return .unknownEmail
        case .invalidCredentials: return .wrongPassword
        case .emailNotConfirmed: return .validation(field: "email", message: "Confirm your email first.")
        case .userAlreadyExists, .emailExists: return .emailTaken
        case .weakPassword: return .validation(field: "password", message: "At least 8 characters.")
        default: return .unknown(error.localizedDescription)
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
nonisolated struct MembershipRow: Decodable {
    let role: MembershipRole
    let fullName: String
    let clinic: MembershipClinicRow
}

nonisolated struct MembershipClinicRow: Decodable {
    let id: UUID
    let name: String
    let currency: String
    let timeZone: String
}

nonisolated struct MembershipStatusRow: Decodable {
    let status: String
}
