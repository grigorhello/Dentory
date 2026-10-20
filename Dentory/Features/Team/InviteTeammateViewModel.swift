import Foundation
import Observation

/// "Invite a teammate" (Appendix C `invite`): an optional name, the email, Staff or Admin (Staff by default), and Send
/// invitation through `invite_member`. An address already on the team, or a malformed one, is said under the field.
@MainActor
@Observable
final class InviteTeammateViewModel {
    var name = ""
    var email = "" {
        didSet { emailError = nil }
    }
    var role: MembershipRole = .staff
    private(set) var emailError: String?
    private(set) var isSending = false
    /// A refusal that is not about the address, shown as a toast.
    private(set) var generalError: AppError?

    private let clinicID: UUID
    private let repository: TeamRepository
    private let onSent: () async -> Void

    init(clinicID: UUID, repository: TeamRepository, onSent: @escaping () async -> Void) {
        self.clinicID = clinicID
        self.repository = repository
        self.onSent = onSent
    }

    var canSend: Bool {
        !trimmedEmail.isEmpty && !isSending
    }

    var roleOptions: [SegmentOption<MembershipRole>] {
        [MembershipRole.staff, .admin].map { SegmentOption($0, label: $0.label) }
    }

    func send() async {
        let address = trimmedEmail
        guard Self.looksLikeEmail(address) else {
            emailError = "Enter a valid email"
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            try await repository.invite(
                clinicID: clinicID, fullName: name.trimmingCharacters(in: .whitespacesAndNewlines), email: address,
                role: role
            )
            await onSent()
        } catch {
            let appError = AppError(error)
            if case .validation(let field, let message) = appError, field == "email" || field == nil {
                emailError = message
            } else {
                generalError = appError
            }
        }
    }

    func clearGeneralError() {
        generalError = nil
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// The same check as the server: one @, a dot in the domain, no spaces.
    private static func looksLikeEmail(_ value: String) -> Bool {
        value.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
    }
}
