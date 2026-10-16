import Foundation
@testable import MediSave

final class FakeAuthService: AuthServicing, @unchecked Sendable {
    var storedSession: Session?
    var signInResult: Result<Session, Error>
    var restoreError: Error?
    private(set) var signOutCount = 0
    private(set) var signIns: [(email: String, password: String)] = []

    init(storedSession: Session? = nil, signInResult: Result<Session, Error> = .success(.demo)) {
        self.storedSession = storedSession
        self.signInResult = signInResult
    }

    func restore() async throws -> Session? {
        if let restoreError { throw restoreError }
        return storedSession
    }

    func signIn(email: String, password: String) async throws -> Session {
        signIns.append((email, password))
        return try signInResult.get()
    }

    func signOut() async throws {
        signOutCount += 1
        storedSession = nil
    }
}
