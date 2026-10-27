import Foundation

/// One invoice as Review invoice follows it (`invoice_detail`, `invoice_create`): its state and, once read, the
/// header f23 shows ("Patterson Dental · INV-10092 · $449.00"), how many lines were read and, from `invoice_detail`,
/// the lines themselves (MS-130); once received, when and by whom (MS-131); whether its photo or PDF is still in
/// Storage and, once deleted, when and by whom (MS-146). Decoded with the client's decoder (`JSONDecoder.supabase`,
/// snake_case keys).
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
        /// Set aside: Receive manually instead, or Discard invoice (MS-130).
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
    /// The lines in reading order; `invoice_create` answers none.
    var lines: [InvoiceLine] = []
    /// When the upload finished: where `invoice.confirm`'s `duration_s` starts (MS-147).
    var createdAt: Date?
    /// When the delivery was received, and the full name of the admin who received it (MS-131).
    var confirmedAt: Date?
    var confirmedByName: String?
    /// Whether a page of the invoice's photo or PDF is still in Storage: a received invoice offers Delete invoice file
    /// while it has one (MS-146).
    var hasFile = false
    /// When the file was deleted, and the full name of the admin who deleted it (MS-146).
    var fileDeletedAt: Date?
    var fileDeletedByName: String?
}

nonisolated extension InvoiceSummary {
    private enum CodingKeys: String, CodingKey {
        case id, status, supplier, number, total, currency, readingStarted, lineCount, lines, createdAt, confirmedAt
        case confirmedByName, hasFile, fileDeletedAt, fileDeletedByName
    }

    /// `invoice_create`, `invoice_discard` and a reading's answers carry no lines: they read as none. A server without
    /// MS-146 says nothing of the file: it reads as none, so nothing offers to delete it.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        status = try container.decode(Status.self, forKey: .status)
        supplier = try container.decodeIfPresent(String.self, forKey: .supplier)
        number = try container.decodeIfPresent(String.self, forKey: .number)
        total = try container.decodeIfPresent(Decimal.self, forKey: .total)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        readingStarted = try container.decode(Bool.self, forKey: .readingStarted)
        lineCount = try container.decode(Int.self, forKey: .lineCount)
        lines = try container.decodeIfPresent([InvoiceLine].self, forKey: .lines) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        confirmedAt = try container.decodeIfPresent(Date.self, forKey: .confirmedAt)
        confirmedByName = try container.decodeIfPresent(String.self, forKey: .confirmedByName)
        hasFile = try container.decodeIfPresent(Bool.self, forKey: .hasFile) ?? false
        fileDeletedAt = try container.decodeIfPresent(Date.self, forKey: .fileDeletedAt)
        fileDeletedByName = try container.decodeIfPresent(String.self, forKey: .fileDeletedByName)
    }
}
