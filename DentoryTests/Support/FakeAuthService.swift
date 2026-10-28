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
    var verifyResult: Result<PasswordReset, Error> = .success(.demoLink)
    var updatePasswordResult: Result<Void, Error> = .success(())
    var linkSignInResult: Result<Void, Error> = .success(())
    /// The session `restore()` answers once the link's account signs in, as the recovery session would.
    var sessionAfterReset: Session? = .demo
    private(set) var resetEmails: [String] = []
    private(set) var verifiedTokenHashes: [String] = []
    private(set) var updatedPasswords: [String] = []
    /// The links whose account signed in on the device.
    private(set) var linkSignIns: [PasswordReset] = []

    func sendPasswordReset(email: String) async throws {
        resetEmails.append(email)
        try resetResult.get()
    }

    func verifyPasswordReset(tokenHash: String) async throws -> PasswordReset {
        verifiedTokenHashes.append(tokenHash)
        return try verifyResult.get()
    }

    /// Like the link's own client: the device's stored session is not touched.
    func updatePassword(_ password: String, for reset: PasswordReset) async throws -> PasswordReset {
        updatedPasswords.append(password)
        try updatePasswordResult.get()
        return reset
    }

    func signIn(with reset: PasswordReset) async throws {
        linkSignIns.append(reset)
        try linkSignInResult.get()
        storedSession = sessionAfterReset
        storedAccount = nil
    }
}

extension PasswordReset {
    /// A good link of the demo admin, Sarah.
    static let demoLink = PasswordReset(
        userID: Session.demo.userID, email: "sarah@smiledental.ca", accessToken: "access", refreshToken: "refresh"
    )
}
