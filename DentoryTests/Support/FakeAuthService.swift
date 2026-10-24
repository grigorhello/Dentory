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
    var signUpResult: Result<Account, Error> = .success(
        Account(userID: UUID(), email: "new@clinic.com", fullName: "New Admin")
    )
    struct SignUp: Equatable {
        let fullName: String
        let email: String
        let password: String
    }

    private(set) var signUps: [SignUp] = []

    private(set) var restoreCount = 0
    /// How long `restore()` takes to answer; the answer is what was stored when it was called.
    var restoreDelay: Duration = .zero

    func restore() async throws -> RestoredSession {
        restoreCount += 1
        let answer = storedAnswer()
        if restoreDelay > .zero { try await Task.sleep(for: restoreDelay) }
        return try answer.get()
    }

    private func storedAnswer() -> Result<RestoredSession, Error> {
        if let restoreError { return .failure(restoreError) }
        if let storedSession { return .success(.signedIn(storedSession)) }
        if let storedAccount { return .success(.needsClinic(storedAccount)) }
        return .success(.none)
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

    var resetResult: Result<Void, Error> = .success(())
    var verifyResult: Result<Void, Error> = .success(())
    var updatePasswordResult: Result<Void, Error> = .success(())
    /// The session `restore()` answers once the new password is saved, as the recovery session would.
    var sessionAfterReset: Session? = .demo
    private(set) var resetEmails: [String] = []
    private(set) var verifiedTokenHashes: [String] = []
    private(set) var updatedPasswords: [String] = []

    func sendPasswordReset(email: String) async throws {
        resetEmails.append(email)
        try resetResult.get()
    }

    func verifyPasswordReset(tokenHash: String) async throws {
        verifiedTokenHashes.append(tokenHash)
        try verifyResult.get()
    }

    func updatePassword(_ password: String) async throws {
        updatedPasswords.append(password)
        try updatePasswordResult.get()
        storedSession = sessionAfterReset
    }
}
