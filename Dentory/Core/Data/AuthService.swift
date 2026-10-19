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
    /// Emails a password reset link (MS-113). Succeeds the same way for an unknown address, so the screen
    /// never tells who has an account. Throws `AppError.validation(field: "email", …)` for a malformed
    /// address or too many requests.
    func sendPasswordReset(email: String) async throws
    /// Opens the reset link: signs the link's account in for the password change. Throws
    /// `AppError.notFound` when the link has expired or was already used.
    func verifyPasswordReset(tokenHash: String) async throws
    /// Sets the signed-in account's password. Throws `AppError.validation(field: "password", …)` when the
    /// server refuses it.
    func updatePassword(_ password: String) async throws
}

extension AppError {
    static let unknownEmail = AppError.validation(field: "email", message: "No account with this email.")
    static let wrongPassword = AppError.validation(field: "password", message: "Wrong password.")
    static let emailTaken = AppError.validation(
        field: "email", message: "An account with this email already exists. Sign in instead."
    )
    static let invalidEmail = AppError.validation(field: "email", message: "Enter a valid email address.")
    static let tooManyResetLinks = AppError.validation(
        field: "email", message: "Too many links sent. Wait a minute, then try again."
    )
    static let shortPassword = AppError.validation(field: "password", message: "At least 8 characters.")
    static let samePassword = AppError.validation(
        field: "password", message: "Choose a new password, not the current one."
    )
}

struct SupabaseAuthService: AuthServicing {
    let client: SupabaseClient
    /// Where the reset email's link points: `dentory://reset-password` on the local stack, the universal
    /// `https://app.dentory.ca/reset-password` for the hosted project (MS-100 D12). The email template adds
    /// `?token_hash=…&type=recovery` (`supabase/templates/recovery.html`). Nil leaves it to the project's site URL.
    let passwordResetRedirect: URL?

    func restore() async throws -> RestoredSession {
        guard let stored = client.auth.currentSession else { return .none }
        do {
            return .signedIn(try await session(for: stored.user))
        } catch AppError.notFound {
            // The server says whether this user never had a clinic (`none`) or lost one (`revoked`,
            // `invited`); the memberships table itself hides rows of clinics one no longer belongs to.
            guard try await membershipState() == "none" else {
                try? await client.auth.signOut()
                throw AppError.forbidden
            }
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

    /// `membership_state()`: "active", "none", or the latest non-active status.
    private func membershipState() async throws -> String {
        do {
            return try await client.rpc("membership_state").execute().value
        } catch {
            throw AppError(error)
        }
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
        case .weakPassword: return .shortPassword
        case .samePassword: return .samePassword
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

    func sendPasswordReset(email: String) async throws {
        do {
            try await client.auth.resetPasswordForEmail(email, redirectTo: passwordResetRedirect)
        } catch let error as AuthError {
            throw Self.resetRequestError(for: error)
        } catch {
            throw AppError(error)
        }
    }

    func verifyPasswordReset(tokenHash: String) async throws {
        do {
            try await client.auth.verifyOTP(tokenHash: tokenHash, type: .recovery)
        } catch let error as AuthError {
            throw Self.resetLinkError(for: error)
        } catch {
            throw AppError(error)
        }
    }

    func updatePassword(_ password: String) async throws {
        do {
            try await client.auth.update(user: UserAttributes(password: password))
        } catch let error as AuthError {
            throw Self.appError(for: error)
        } catch {
            throw AppError(error)
        }
    }

    /// `POST /recover` answers an unknown address like a known one; what it does refuse is a malformed
    /// address and a burst of requests.
    static func resetRequestError(for error: AuthError) -> AppError {
        guard case .api(_, let code, _, _) = error else { return AppError(error) }
        switch code {
        case .validationFailed: return .invalidEmail
        case .overEmailSendRateLimit, .overRequestRateLimit: return .tooManyResetLinks
        default: return .unknown(error.localizedDescription)
        }
    }

    /// An expired link and a used one both answer `otp_expired`; the screen offers a new link for either.
    static func resetLinkError(for error: AuthError) -> AppError {
        guard case .api(_, let code, _, _) = error else { return AppError(error) }
        switch code {
        case .otpExpired, .flowStateExpired, .flowStateNotFound: return .notFound
        default: return .unknown(error.localizedDescription)
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
