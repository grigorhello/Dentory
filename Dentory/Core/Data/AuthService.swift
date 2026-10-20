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
    static let tooManyRequests = AppError.validation(
        field: "email", message: "Too many requests. Wait a minute, then try again."
    )
    static let shortPassword = AppError.validation(field: "password", message: "At least 8 characters.")
    static let longPassword = AppError.validation(field: "password", message: "At most 72 characters.")
    static let leakedPassword = AppError.validation(
        field: "password", message: "This password is known from data leaks. Choose another one."
    )
    static let simplePassword = AppError.validation(
        field: "password", message: "Use a mix of letters, digits and symbols."
    )
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
        if case .weakPassword(_, let reasons) = error { return weakPasswordError(reasons: reasons) }
        guard case .api(_, let code, _, _) = error else { return AppError(error) }
        switch code {
        case .userNotFound: return .unknownEmail
        case .invalidCredentials: return .wrongPassword
        case .emailNotConfirmed: return .validation(field: "email", message: "Confirm your email first.")
        case .userAlreadyExists, .emailExists: return .emailTaken
        case .samePassword: return .samePassword
        default: return .unknown(error.localizedDescription)
        }
    }

    /// This device only: the member stays signed in on their other devices (PRD §6.1, MS-110).
    func signOut() async throws {
        do {
            try await client.auth.signOut(scope: .local)
        } catch {
            throw AppError(error)
        }
    }

    func sendPasswordReset(email: String) async throws {
        do {
            try await client.auth.resetPasswordForEmail(email, redirectTo: passwordResetRedirect)
        } catch let error as AuthError {
            if let refusal = Self.resetRequestError(for: error) { throw refusal }
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
            throw Self.newPasswordError(for: error)
        } catch {
            throw AppError(error)
        }
    }

    /// `POST /recover` answers an unknown address with 200 before any limit applies, so a refusal only a known
    /// address can get (its own email limit, a recipient the project's mailer may not reach) reads as sent: the
    /// screen must not tell who has an account (MS-113). What it refuses for every address is a malformed one
    /// and a burst of requests from this device. Nil means the confirmation shows.
    static func resetRequestError(for error: AuthError) -> AppError? {
        guard case .api(_, let code, _, _) = error else { return AppError(error) }
        switch code {
        case .validationFailed: return .invalidEmail
        case .overRequestRateLimit: return .tooManyRequests
        case .overEmailSendRateLimit, .emailAddressNotAuthorized: return nil
        default: return .unknown(error.localizedDescription)
        }
    }

    /// `PUT /user` refuses a new password as weak (with reasons), as the current one, or past 72 bytes
    /// (`validation_failed`); every refusal shows under the field in the app's own words.
    static func newPasswordError(for error: AuthError) -> AppError {
        if case .api(_, .validationFailed, _, _) = error { return .longPassword }
        return appError(for: error)
    }

    /// supabase-swift reports `weak_password` as its own case, with GoTrue's reasons: `length`, `characters`
    /// (the project's character rules) and `pwned` (leaked-password protection).
    static func weakPasswordError(reasons: [String]) -> AppError {
        if reasons.contains("pwned") { return .leakedPassword }
        if reasons.contains("characters") { return .simplePassword }
        return .shortPassword
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
                .select(
                    "role, full_name, clinic:clinics(id, name, currency, time_zone, subscription_status, trial_ends_at)"
                )
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
            timeZone: row.clinic.timeZone,
            subscriptionStatus: row.clinic.subscriptionStatus,
            trialEndsAt: row.clinic.trialEndsAt
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
    let subscriptionStatus: SubscriptionStatus
    let trialEndsAt: Date
}
