import Foundation
import Supabase
import Testing
@testable import Dentory

struct AppErrorFunctionsTests {
    private func failure(_ status: Int, _ json: String) -> AppError {
        AppError(functionError: FunctionsError.httpError(code: status, data: Data(json.utf8)))
    }

    @Test func aRefusedFieldKeepsItsSentence() {
        let conflict = #"{"error":{"code":"conflict","message":"priya@x.ca is already on the team","field":"email"}}"#
        #expect(failure(409, conflict) == .validation(field: "email", message: "priya@x.ca is already on the team"))
        #expect(failure(400, #"{"error":{"code":"validation","message":"At least 8 characters.","field":"password"}}"#)
            == .validation(field: "password", message: "At least 8 characters."))
    }

    @Test func goneRefusedAndReadOnlyMapToTheirCases() {
        let gone = #"{"error":{"code":"invitation_expired","message":"This invitation has expired."}}"#
        #expect(failure(410, gone) == .notFound)
        #expect(failure(401, #"{"error":{"code":"unauthorized","message":"Sign in first."}}"#) == .forbidden)
        #expect(failure(403, #"{"error":{"code":"forbidden","message":"Only an admin can invite"}}"#) == .forbidden)
        #expect(failure(403, #"{"error":{"code":"read_only","message":"The clinic is read-only"}}"#) == .readOnly)
    }

    @Test func aServiceThatIsDownOrNotSetUpSaysSo() {
        let unavailable = #"{"error":{"code":"billing_unavailable","message":"Billing isn't set up yet. Try again later."}}"#
        #expect(failure(503, unavailable) == .validation(field: nil, message: "Billing isn't set up yet. Try again later."))
        #expect(failure(502, "") == .unknown("The server answered 502"))
    }

    @Test func anUnreadableBodyStillMaps() {
        #expect(failure(400, "not json") == .validation(field: nil, message: "Couldn't save. Try again."))
        #expect(failure(500, "") == .unknown("The server answered 500"))
        let resend = #"{"error":{"code":"unknown","message":"Resend answered 401"}}"#
        #expect(failure(500, resend) == .unknown("Resend answered 401"))
    }

    @Test func otherErrorsFallBackToTheGeneralMapping() {
        #expect(AppError(functionError: URLError(.notConnectedToInternet)) == .network)
        #expect(AppError(functionError: AppError.forbidden) == .forbidden)
    }
}
