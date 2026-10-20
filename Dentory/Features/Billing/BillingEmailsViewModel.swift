import Foundation
import Observation

/// The billing emails sheet (PRD Appendix C `billingEmails`, MS-141): where invoices and receipts go. The first address
/// is the one the Stripe customer bills, labelled Admin, and cannot be removed; others are added and removed here and
/// saved with Done. Stripe emails the first; the others get Dentory's copy of each receipt. It works in read-only mode
/// too, since the link to add a card goes to these addresses.
@MainActor
@Observable
final class BillingEmailsViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    private(set) var state: LoadState = .loading
    private(set) var primary: String?
    private(set) var extra: [String] = []
    var newEmail = "" {
        didSet { if newEmail != oldValue { emailError = nil } }
    }
    private(set) var emailError: String?
    /// A refusal of the save that belongs to no field, shown in the sheet.
    private(set) var generalError: AppError?
    private(set) var isSaving = false
    /// How Done ended: the screen closes the sheet, and shows "Billing emails updated" only after a save.
    enum Outcome: Equatable { case closed, saved }
    private(set) var outcome: Outcome?

    static let limit = 10
    static let savedMessage = "Billing emails updated"

    private let clinicID: UUID
    private let repository: BillingRepository
    private let onSaved: () async -> Void
    private var savedExtra: [String] = []

    init(clinicID: UUID, repository: BillingRepository, onSaved: @escaping () async -> Void = {}) {
        self.clinicID = clinicID
        self.repository = repository
        self.onSaved = onSaved
    }

    func load() async {
        do {
            show(try await repository.billingEmails(clinicID: clinicID))
            state = .loaded
        } catch {
            state = .failed(AppError(error))
        }
    }

    var canAdd: Bool {
        !newEmail.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var hasChanges: Bool { extra != savedExtra }

    /// Checks the address and lists it; it is saved with Done.
    func add() {
        let email = newEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !email.isEmpty else { return }
        guard Self.looksLikeEmail(email) else {
            emailError = "Enter a valid email"
            return
        }
        guard email != primary?.lowercased(), !extra.contains(email) else {
            emailError = "This address is already on the list"
            return
        }
        guard extra.count + 1 < Self.limit else {
            emailError = "Up to \(Self.limit) billing emails"
            return
        }
        extra.append(email)
        newEmail = ""
    }

    func remove(_ email: String) {
        extra.removeAll { $0 == email }
    }

    /// Done: an address still in the field is added first (and Done stops at its error), then the list is saved when it
    /// changed, the server's answer becoming the list; with nothing to save it only closes.
    func save() async {
        guard !isSaving else { return }
        if !newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add()
            guard emailError == nil else { return }
        }
        guard hasChanges else {
            outcome = .closed
            return
        }
        isSaving = true
        generalError = nil
        defer { isSaving = false }
        do {
            show(try await repository.saveBillingEmails(clinicID: clinicID, extra: extra))
            outcome = .saved
            await onSaved()
        } catch {
            let appError = AppError(error)
            if case .validation(let field?, let message) = appError, extra.contains(field) {
                emailError = "\(field): \(message)"
            } else {
                generalError = appError == .network ? .unknown("No connection") : appError
            }
        }
    }

    private func show(_ emails: [String]) {
        primary = emails.first
        extra = Array(emails.dropFirst())
        savedExtra = extra
    }

    /// The server's shape check: one @, a dot in the domain, no spaces.
    nonisolated static func looksLikeEmail(_ text: String) -> Bool {
        text.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
    }
}
