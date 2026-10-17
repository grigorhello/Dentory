import Foundation
import Supabase
import Testing
@testable import MediSave

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

    @Test func fieldErrorsCarryThePRDCopy() {
        #expect(AppError.unknownEmail == .validation(field: "email", message: "No account with this email."))
        #expect(AppError.wrongPassword == .validation(field: "password", message: "Wrong password."))
    }
}
