import Foundation
import Observation

/// Team (f31 Admin, f32 Staff; PRD §6.9, Appendix B `team`): everyone on the clinic, admins first, then Staff, then the
/// invitations still open. An admin invites, and from a row's menu changes a role, resends an invitation, or removes
/// a person after a confirmation; the last admin is kept. The list shows from the cache while a fresh one loads or
/// the network is gone (MS-108).
@MainActor
@Observable
final class TeamViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    /// A toast: "Invitation sent", with what happens next when there is something to add.
    struct Message: Equatable {
        let title: String
        var detail: String?
    }

    /// The sheets the screen shows; one at a time.
    enum Sheet: Identifiable, Equatable {
        case invite
        case remove(TeamMember)

        var id: String {
            switch self {
            case .invite: "invite"
            case .remove(let member): "remove.\(member.id)"
            }
        }
    }

    private(set) var state: LoadState = .loading
    private(set) var members: [TeamMember]
    /// The person whose menu is open (Admin).
    var menuMember: TeamMember?

    /// The menu's dialog: open while a person is chosen; dismissing it forgets them.
    var isMenuPresented: Bool {
        get { menuMember != nil }
        set { if !newValue { menuMember = nil } }
    }
    var sheet: Sheet?
    private(set) var isRemoving = false
    /// A toast the screen shows once.
    private(set) var message: Message?
    let isAdmin: Bool
    let formatters: ClinicFormatters

    private let repository: TeamRepository
    private let cache: ResponseCaching
    private let session: Session
    /// Runs after the admin changed their own role or left, so the app follows (MS-138).
    private let sessionChanged: () async -> Void

    init(
        session: Session, repository: TeamRepository, cache: ResponseCaching, formatters: ClinicFormatters,
        sessionChanged: @escaping () async -> Void = {}
    ) {
        self.session = session
        self.repository = repository
        self.cache = cache
        self.formatters = formatters
        self.sessionChanged = sessionChanged
        isAdmin = session.isAdmin
        members = cache.load([TeamMember].self, for: Self.cacheKey(session.clinicID)) ?? []
    }

    private static func cacheKey(_ clinicID: UUID) -> CacheKey {
        CacheKey(method: "TeamRepository.members", clinicID: clinicID)
    }

    var clinicID: UUID { session.clinicID }

    func load() async {
        do {
            let fresh = try await repository.members(clinicID: session.clinicID)
            members = fresh
            cache.store(fresh, for: Self.cacheKey(session.clinicID))
            state = .loaded
        } catch {
            state = members.isEmpty ? .failed(AppError(error)) : .loaded
        }
    }

    /// Admin: a row opens its menu; Staff read the list only (f32).
    func openMenu(for member: TeamMember) {
        guard isAdmin else { return }
        menuMember = member
    }

    /// Change role to Admin, or to Staff: the last admin stays an admin.
    func changeRole(of member: TeamMember) async {
        let role: MembershipRole = member.role == .admin ? .staff : .admin
        if role == .staff, isLastAdmin(member) {
            message = Message(title: Self.needsAnAdmin)
            return
        }
        do {
            try await repository.setRole(memberID: member.id, role: role)
            await load()
            if member.userID == session.userID { await sessionChanged() }
        } catch {
            message = Message(title: AppError(error).teamMessage)
        }
    }

    /// The invitation again, with a fresh link: "Invitation sent".
    func resend(_ member: TeamMember) async {
        do {
            try await repository.invite(
                clinicID: session.clinicID, fullName: member.fullName, email: member.email, role: member.role
            )
            message = Message(title: "Invitation sent")
            await load()
        } catch {
            message = Message(title: AppError(error).teamMessage)
        }
    }

    /// Remove from clinic or Revoke invitation: asks first, and the last admin stays.
    func askToRemove(_ member: TeamMember) {
        if isLastAdmin(member) {
            message = Message(title: Self.needsAnAdmin)
            return
        }
        sheet = .remove(member)
    }

    func remove(_ member: TeamMember) async {
        isRemoving = true
        defer { isRemoving = false }
        do {
            try await repository.remove(memberID: member.id)
            sheet = nil
            await load()
            if member.userID == session.userID { await sessionChanged() }
        } catch {
            sheet = nil
            message = Message(title: AppError(error).teamMessage)
        }
    }

    func keep() {
        sheet = nil
    }

    func askToInvite() {
        sheet = .invite
    }

    /// The invitation went out: the row is pending, the toast says what happens next.
    func didInvite() async {
        sheet = nil
        message = Message(title: "Invitation sent", detail: "They get a link by email.")
        await load()
    }

    func clearMessage() {
        message = nil
    }

    static let needsAnAdmin = "A clinic needs at least one admin."

    private func isLastAdmin(_ member: TeamMember) -> Bool {
        guard member.role == .admin, !member.isPending else { return false }
        return !members.contains { $0.id != member.id && $0.role == .admin && !$0.isPending }
    }
}

private extension AppError {
    /// The server's sentence for a refused change, else the general one. Team changes are not queued, so no connection
    /// reads as a failed save (PRD §7), not as a change to be retried.
    var teamMessage: String {
        switch self {
        case .validation(_, let message): message
        case .network: AppError.unknown("No connection").userMessage
        default: userMessage
        }
    }
}
