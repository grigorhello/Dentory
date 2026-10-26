import Foundation

/// Where an invoice's pages go (flow step 1): the private `invoices` bucket, `{clinic_id}/{invoice_id}/page-n.jpg`, or
/// `page-1.pdf` for a PDF, the ids in lower case as the bucket's policy and `invoice_create` read them.
nonisolated enum InvoiceFiles {
    static let bucket = "invoices"

    /// The path of the `number`th page, counted from 1.
    static func path(clinicID: UUID, invoiceID: UUID, page number: Int, kind: InvoiceDocument.PageKind) -> String {
        "\(clinicID.uuidString.lowercased())/\(invoiceID.uuidString.lowercased())/page-\(number).\(kind.rawValue)"
    }

    static func contentType(of kind: InvoiceDocument.PageKind) -> String {
        switch kind {
        case .jpeg: "image/jpeg"
        case .pdf: "application/pdf"
        }
    }
}
