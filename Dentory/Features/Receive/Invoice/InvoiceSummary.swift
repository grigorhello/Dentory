import Foundation

/// One invoice as Review invoice follows it (`invoice_detail`, `invoice_create`): its state and, once read, the
/// header f23 shows ("Patterson Dental · INV-10092 · $449.00") and how many lines were read. Decoded with the client's
/// decoder (`JSONDecoder.supabase`, snake_case keys).
nonisolated struct InvoiceSummary: Codable, Equatable, Identifiable, Sendable {
    nonisolated enum Status: String, Codable, Sendable {
        /// Uploaded, and being read on the server.
        case reading
        /// Read, and waiting for review (MS-130).
        case ready
        /// The reading failed: a clearer photo, or receiving by hand.
        case failed
        /// Received (MS-131).
        case confirmed
        /// Set aside: Receive manually instead, or discarded (MS-130).
        case discarded
    }

    let id: UUID
    let status: Status
    let supplier: String?
    let number: String?
    let total: Decimal?
    /// The currency the invoice is in, when it says.
    let currency: String?
    /// Whether extract_invoice claimed the reading; one that never started is asked again.
    let readingStarted: Bool
    let lineCount: Int
}
