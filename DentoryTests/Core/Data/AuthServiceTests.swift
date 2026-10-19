import Foundation
import Supabase
import Testing
@testable import Dentory

struct AuthServiceTests {
    @Test func supabaseRefusalsBecomeFieldErrors() {
        #expect(SupabaseAuthService.appError(for: .api(
            message: "Invalid login credentials", errorCode: .invalidCredentials, underlyingData: Data(),
            underlyingResponse: HTTPURLResponse()
        )) == .wrongPassword)
        #expect(SupabaseAuthService.appError(for: .api(
            message: "User not found", errorCode: .userNotFound, underlyingData: Data(),
            underlyingResponse: HTTPURLResponse()
        )) == .unknownEmail)
        let missing = AuthError.sessionMissing
        #expect(SupabaseAuthService.appError(for: missing) == .unknown(missing.localizedDescription))
    }

    private func apiError(_ code: ErrorCode, _ message: String = "refused") -> AuthError {
        .api(message: message, errorCode: code, underlyingData: Data(), underlyingResponse: HTTPURLResponse())
    }

    @Test func aResetRequestIsRefusedOnlyForAMalformedAddressOrTooManyRequests() {
        #expect(SupabaseAuthService.resetRequestError(for: apiError(.validationFailed)) == .invalidEmail)
        #expect(SupabaseAuthService.resetRequestError(for: apiError(.overRequestRateLimit)) == .tooManyRequests)
        #expect(SupabaseAuthService.resetRequestError(for: apiError(.unexpectedFailure, "boom")) == .unknown("boom"))
        #expect(AppError.tooManyRequests == .validation(
            field: "email", message: "Too many requests. Wait a minute, then try again."
        ))
    }

    @Test func refusalsOnlyAKnownAddressGetsReadAsSent() {
        // An unknown address always gets 200, so these would tell that an account exists.
        #expect(SupabaseAuthService.resetRequestError(for: apiError(.overEmailSendRateLimit)) == nil)
        #expect(SupabaseAuthService.resetRequestError(for: apiError(.emailAddressNotAuthorized)) == nil)
    }

    @Test func anExpiredOrUsedResetLinkReadsAsNotFound() {
        #expect(SupabaseAuthService.resetLinkError(for: apiError(.otpExpired)) == .notFound)
        #expect(SupabaseAuthService.resetLinkError(for: apiError(.flowStateExpired)) == .notFound)
        #expect(SupabaseAuthService.resetLinkError(for: apiError(.unexpectedFailure, "boom")) == .unknown("boom"))
    }

    @Test func aRefusedNewPasswordShowsUnderThePasswordField() {
        #expect(SupabaseAuthService.newPasswordError(for: apiError(.samePassword)) == .samePassword)
        #expect(SupabaseAuthService.newPasswordError(for: apiError(.validationFailed)) == .longPassword)
        #expect(SupabaseAuthService.newPasswordError(for: apiError(.unexpectedFailure, "boom")) == .unknown("boom"))
        #expect(AppError.shortPassword == .validation(field: "password", message: "At least 8 characters."))
        #expect(AppError.longPassword == .validation(field: "password", message: "At most 72 characters."))
    }

    @Test func aWeakPasswordShowsItsReason() {
        func weak(_ reasons: [String]) -> AppError {
            SupabaseAuthService.newPasswordError(for: .weakPassword(message: "weak", reasons: reasons))
        }
        #expect(weak(["length"]) == .shortPassword)
        #expect(weak([]) == .shortPassword)
        #expect(weak(["characters"]) == .simplePassword)
        #expect(weak(["length", "pwned"]) == .leakedPassword)
        #expect(AppError.leakedPassword == .validation(
            field: "password", message: "This password is known from data leaks. Choose another one."
        ))
        #expect(AppError.simplePassword == .validation(
            field: "password", message: "Use a mix of letters, digits and symbols."
        ))
    }

    @Test func fieldErrorsCarryThePRDCopy() {
        #expect(AppError.unknownEmail == .validation(field: "email", message: "No account with this email."))
        #expect(AppError.wrongPassword == .validation(field: "password", message: "Wrong password."))
    }
}
