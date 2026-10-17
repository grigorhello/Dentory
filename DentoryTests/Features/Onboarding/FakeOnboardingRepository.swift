import Foundation
@testable import Dentory

final class FakeOnboardingRepository: OnboardingRepository, @unchecked Sendable {
    var clinicResult: Result<UUID, Error>
    var inviteResult: Result<Int, Error> = .success(0)
    struct ClinicCall: Equatable {
        let name: String
        let city: String
        let country: String
        let timeZone: String
        let fullName: String
    }

    private(set) var clinics: [ClinicCall] = []
    private(set) var logos: [UUID] = []
    private(set) var invites: [(clinicID: UUID, invites: [TeamInvite])] = []

    init(clinicResult: Result<UUID, Error> = .success(Session.demo.clinicID)) {
        self.clinicResult = clinicResult
    }

    func createClinic(
        name: String, city: String, country: String, timeZone: String, fullName: String
    ) async throws -> UUID {
        clinics.append(ClinicCall(name: name, city: city, country: country, timeZone: timeZone, fullName: fullName))
        let id = try clinicResult.get()
        return id
    }

    func uploadLogo(clinicID: UUID, imageData: Data) async throws {
        logos.append(clinicID)
    }

    func invite(clinicID: UUID, invites: [TeamInvite]) async throws -> Int {
        self.invites.append((clinicID, invites))
        return try inviteResult.get()
    }
}
