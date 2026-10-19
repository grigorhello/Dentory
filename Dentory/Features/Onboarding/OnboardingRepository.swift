import Foundation

/// One invitation row of step 3.
nonisolated struct TeamInvite: Equatable, Sendable {
    let email: String
    let role: MembershipRole
}

/// Creates the clinic and records the team invitations (MS-111). The auth user comes from `AuthServicing`.
protocol OnboardingRepository: Sendable {
    /// `clinic_create`: the clinic, its admin membership, the profile and the default categories, in one
    /// call that returns the existing clinic when the user already has one.
    func createClinic(
        name: String, city: String, country: String, timeZone: String, fullName: String
    ) async throws -> UUID
    /// Stores the logo under `logos/{clinic_id}/` and points the clinic at it.
    func uploadLogo(clinicID: UUID, imageData: Data) async throws
    /// Sends one invitation email per address through the `invite_member` function (MS-112) and returns how
    /// many went out. A refusal of one address throws `AppError.validation(field: thatAddress, message:)`,
    /// so the screen can show it under that row.
    func invite(clinicID: UUID, invites: [TeamInvite]) async throws -> Int
}
