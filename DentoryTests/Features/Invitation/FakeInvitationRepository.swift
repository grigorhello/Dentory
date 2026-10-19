import Foundation
@testable import Dentory

final class FakeInvitationRepository: InvitationRepository, @unchecked Sendable {
    var lookupResult: Result<Invitation?, Error>
    var acceptResult: Result<Void, Error> = .success(())
    var acceptDelay: Duration = .zero
    private(set) var lookups: [String] = []
    struct Accept: Equatable {
        let token: String
        let fullName: String
        let password: String
    }

    private(set) var accepts: [Accept] = []

    init(lookupResult: Result<Invitation?, Error> = .success(.fixture)) {
        self.lookupResult = lookupResult
    }

    func invitation(token: String) async throws -> Invitation? {
        lookups.append(token)
        return try lookupResult.get()
    }

    func accept(token: String, fullName: String, password: String) async throws {
        accepts.append(Accept(token: token, fullName: fullName, password: password))
        if acceptDelay > .zero { try await Task.sleep(for: acceptDelay) }
        try acceptResult.get()
    }
}

extension Invitation {
    nonisolated static let fixture = Invitation(
        clinicName: "Smile Dental",
        invitedByName: "Sarah Mitchell",
        role: .staff,
        email: "priya@smiledental.ca",
        fullName: "Priya Patel",
        expiresAt: Session.demoNow.addingTimeInterval(6 * 86_400)
    )
}
