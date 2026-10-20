import Foundation
import Observation

/// Account (f29 Admin, f30 Staff), pushed from Home's account button: who is signed in, the Team row with the team's
/// size, the admin's Clinic settings, Billing and Export CSV, Help, and Sign out after a confirmation (PRD §6.9,
/// Appendix B `more`). The team size shows from the cache while a fresh one loads or the network is gone (MS-108).
/// Export CSV asks the server for the clinic's data by email and says where it goes (MS-143).
@MainActor
@Observable
final class AccountViewModel {
    /// The help centre on the production domain (MS-100 D12), a placeholder until Grigor names the page.
    static let helpCentre = URL(string: "https://dentory.ca/help")

    /// A toast: "Export started" with where the link goes, or why it did not start.
    struct Message: Equatable {
        let title: String
        var detail: String?
    }

    /// Active members; nil until the cache or the server has an answer.
    private(set) var teamSize: Int?
    var isConfirmingSignOut = false
    private(set) var isSigningOut = false
    private(set) var isExporting = false
    private(set) var message: Message?
    let isAdmin: Bool

    private let session: Session
    private let repository: AccountRepository
    private let cache: ResponseCaching
    private let signingOut: SigningOut

    init(session: Session, repository: AccountRepository, cache: ResponseCaching, signingOut: SigningOut) {
        self.session = session
        self.repository = repository
        self.cache = cache
        self.signingOut = signingOut
        isAdmin = session.isAdmin
        teamSize = cache.load(Int.self, for: Self.cacheKey(session.clinicID))
    }

    private static func cacheKey(_ clinicID: UUID) -> CacheKey {
        CacheKey(method: "AccountRepository.teamSize", clinicID: clinicID)
    }

    func load() async {
        do {
            let size = try await repository.teamSize(clinicID: session.clinicID)
            teamSize = size
            cache.store(size, for: Self.cacheKey(session.clinicID))
        } catch {
            // The row keeps the last size, or none; the offline banner says why.
        }
    }

    /// "SM", or the first letter of the address for an account without a name.
    var initials: String {
        let initials = PersonName.initials(of: session.fullName)
        return initials.isEmpty ? String(session.email.prefix(1)).uppercased() : initials
    }

    /// "Sarah Mitchell", or the address for an account without a name.
    var name: String {
        session.fullName.isEmpty ? session.email : session.fullName
    }

    /// "Admin · Smile Dental"
    var roleLine: String {
        "\(session.role.label) · \(session.clinicName)"
    }

    /// "3 people", "1 person"; nil until the size is known.
    var teamText: String? {
        teamSize.map { $0 == 1 ? "1 person" : "\($0) people" }
    }

    /// The confirmation's message, and what is lost when changes made offline are still waiting.
    var signOutMessage: String {
        let reassurance = "You can sign in again with your email."
        switch signingOut.unsyncedChangeCount {
        case 0: return reassurance
        case 1: return "\(reassurance) 1 change made offline has not synced and will be lost."
        case let count: return "\(reassurance) \(count) changes made offline have not synced and will be lost."
        }
    }

    /// Export CSV (Admin): the server zips products, batches and transactions and emails the admin a link valid 7
    /// days. A second tap while one starts does nothing; one export every 10 minutes, as the server says.
    func startExport() async {
        guard isAdmin, !isExporting else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            let email = try await repository.startExport(clinicID: session.clinicID)
            let address = email.isEmpty ? session.email : email
            message = Message(title: "Export started", detail: "We'll email it to \(address).")
        } catch {
            message = Message(title: Self.exportRefusal(AppError(error)))
        }
    }

    /// The server's sentence for the 10 minute limit, the permission line for a refusal, else a retry.
    static func exportRefusal(_ error: AppError) -> String {
        switch error {
        case .validation(_, let message): message
        case .forbidden: error.userMessage
        case .network, .notFound, .readOnly, .unknown: "Couldn't start the export. Try again."
        }
    }

    func clearMessage() {
        message = nil
    }

    func askToSignOut() {
        isConfirmingSignOut = true
    }

    func keep() {
        isConfirmingSignOut = false
    }

    /// Clears the device and ends the session; the root then shows Sign in, and this screen leaves with the tabs.
    func signOut() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        await signingOut.signOut()
    }
}
