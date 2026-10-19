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

    @Test func aResetRequestIsRefusedOnlyForAMalformedAddressOrTooManyLinks() {
        #expect(SupabaseAuthService.resetRequestError(for: apiError(.validationFailed)) == .invalidEmail)
        #expect(SupabaseAuthService.resetRequestError(for: apiError(.overEmailSendRateLimit)) == .tooManyResetLinks)
        #expect(SupabaseAuthService.resetRequestError(for: apiError(.overRequestRateLimit)) == .tooManyResetLinks)
        #expect(SupabaseAuthService.resetRequestError(for: apiError(.unexpectedFailure, "boom")) == .unknown("boom"))
    }

    @Test func anExpiredOrUsedResetLinkReadsAsNotFound() {
        #expect(SupabaseAuthService.resetLinkError(for: apiError(.otpExpired)) == .notFound)
        #expect(SupabaseAuthService.resetLinkError(for: apiError(.flowStateExpired)) == .notFound)
        #expect(SupabaseAuthService.resetLinkError(for: apiError(.unexpectedFailure, "boom")) == .unknown("boom"))
    }

    @Test func aRefusedNewPasswordShowsUnderThePasswordField() {
        #expect(SupabaseAuthService.appError(for: apiError(.samePassword)) == .samePassword)
        #expect(SupabaseAuthService.appError(for: apiError(.weakPassword)) == .shortPassword)
        #expect(AppError.shortPassword == .validation(field: "password", message: "At least 8 characters."))
    }

    @Test func fieldErrorsCarryThePRDCopy() {
        #expect(AppError.unknownEmail == .validation(field: "email", message: "No account with this email."))
        #expect(AppError.wrongPassword == .validation(field: "password", message: "Wrong password."))
    }
}
