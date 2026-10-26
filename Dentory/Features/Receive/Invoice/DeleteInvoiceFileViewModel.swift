import Foundation
import Observation

/// "Delete the invoice file?" (MS-146, the ticket's sheet; PRD §9 Privacy): over a received invoice opened read-only,
/// Delete file lets the server go of the invoice's photo or PDF and deletes its pages from Storage, one deletion at a
/// time; the stock received and History stay. It is done once no page is left. What went wrong shows above the
/// buttons and the question stays for another try: a deletion is not queued offline.
@MainActor
@Observable
final class DeleteInvoiceFileViewModel {
    static let title = "Delete the invoice file?"
    static let message = "Received stock and history stay. Only the image or PDF is removed."
    static let deleteTitle = "Delete file"
    static let keepTitle = "Keep"

    /// The invoice as the server has it once its file is gone: the screen shows it, with the toast.
    private(set) var deleted: InvoiceSummary?
    /// A refusal or a failure, shown above the buttons.
    private(set) var generalError: AppError?

    private let invoiceID: UUID
    private let clinicID: UUID
    private let repository: InvoiceFileRepository
    private let submitGuard = SubmitGuard()

    init(invoiceID: UUID, clinicID: UUID, repository: InvoiceFileRepository) {
        self.invoiceID = invoiceID
        self.clinicID = clinicID
        self.repository = repository
    }

    var isDeleting: Bool { submitGuard.isBusy }

    /// Delete file. A page the server still finds (the connection lost between letting go of the file and deleting its
    /// pages) fails as a lost connection does, "Couldn't save. Try again.", and Try again deletes what is left.
    func delete() async {
        await submitGuard.run {
            generalError = nil
            do {
                let invoice = try await repository.deleteFile(invoiceID: invoiceID, clinicID: clinicID)
                guard !invoice.hasFile else {
                    generalError = .unknown("A page of the invoice file is left")
                    return
                }
                deleted = invoice
            } catch {
                let error = AppError(error)
                generalError = error == .network ? .unknown("No connection") : error
            }
        }
    }
}
