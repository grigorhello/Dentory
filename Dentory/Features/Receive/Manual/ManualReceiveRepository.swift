import Foundation

/// Receive manually (MS-127): the products Choose product lists (`ReceivableProductsRepository`), and the receipt.
/// Admin only: the server refuses anyone else, and refuses the receipt of a read-only clinic (MS-142).
protocol ManualReceiveRepository: ReceivableProductsRepository {
    /// `stock_receive` with the one line, referenced as Receive manually: applied now with an idempotency key, or
    /// queued while offline and replayed with the same key (MS-108).
    func receive(_ receipt: ManualReceipt) async throws -> WriteOutcome
}
