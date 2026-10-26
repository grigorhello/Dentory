import Foundation

/// Delete invoice file (MS-146; PRD §9 Privacy: invoice images belong to the clinic and can be deleted by an admin): a
/// received invoice, opened read-only from Activity, offers it in the header's "…" menu while a page of its photo or
/// PDF is still in Storage; once deleted, the screen says so over the lines, which stay, as do the stock received and
/// History. The question's sheet is `DeleteInvoiceFileViewModel`'s; its answer is shown by `fileDeleted(_:)` in
/// `InvoiceViewModel.swift`.
extension InvoiceViewModel {
    static let deleteFileTitle = "Delete invoice file"
    static let fileDeletedTitle = "Invoice file deleted"

    /// The menu offers it on a received invoice that still has its file.
    var canDeleteFile: Bool { state == .received && invoice?.hasFile == true }

    /// Delete invoice file in the menu: the question before anything is deleted.
    func askToDeleteFile() {
        isConfirmingFileDeletion = true
    }

    func keepFile() {
        isConfirmingFileDeletion = false
    }

    /// Under the received notice once the file is gone: "Invoice file deleted · Oct 26 · 2:14 PM · Grigor", when and by
    /// whom, as the received notice says it.
    var fileNotice: String? {
        guard let invoice, state == .received, !invoice.hasFile, let deletedAt = invoice.fileDeletedAt else {
            return nil
        }
        let parts = [
            Self.fileDeletedTitle, formatters.dateTime(deletedAt), invoice.fileDeletedByName.map(PersonName.first(of:))
        ]
        return parts.compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: "\u{00A0}· ")
    }
}
