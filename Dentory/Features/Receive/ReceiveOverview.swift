import Foundation

/// What Receive delivery lists under its three options (f22), as `receive_overview` answers it: the invoices still
/// being read, ready to review or whose reading failed, newest first, and the To buy lines marked Ordered. Decoded with
/// the client's decoder (`JSONDecoder.supabase`, snake_case keys) and cached with its encoder.
nonisolated struct ReceiveOverview: Codable, Equatable, Sendable {
    let invoices: [PendingInvoice]
    let waiting: [WaitingItem]
}
