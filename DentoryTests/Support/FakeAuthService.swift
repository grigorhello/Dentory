import Foundation
@testable import Dentory

final class FakeAuthService: AuthServicing, @unchecked Sendable {
    var storedSession: Session?
    var signInResult: Result<Session, Error>
    var restoreError: Error?
    var signInDelay: Duration = .zero
    private(set) var signOutCount = 0
    private(set) var signIns: [(email: String, password: String)] = []

    init(storedSession: Session? = nil, signInResult: Result<Session, Error> = .success(.demo)) {
        self.storedSession = storedSession
        self.signInResult = signInResult
    }

    var storedAccount: Account?
    var signUpResult: Result<Account, Error> = .success(Account(userID: UUID(), email: "new@clinic.com", fullName: "New Admin"))
    struct SignUp: Equatable {
        let fullName: String
        let email: String
        let password: String
    }

    private(set) var signUps: [SignUp] = []

    func restore() async throws -> RestoredSession {
        if let restoreError { throw restoreError }
        if let storedSession { return .signedIn(storedSession) }
        if let storedAccount { return .needsClinic(storedAccount) }
        return .none
    }

    func signUp(fullName: String, email: String, password: String) async throws -> Account {
        signUps.append(SignUp(fullName: fullName, email: email, password: password))
        let account = try signUpResult.get()
        storedAccount = account
        return account
    }

    func signIn(email: String, password: String) async throws -> Session {
        signIns.append((email, password))
        if signInDelay > .zero { try await Task.sleep(for: signInDelay) }
        return try signInResult.get()
    }

    func signOut() async throws {
        signOutCount += 1
        storedSession = nil
    }
}
