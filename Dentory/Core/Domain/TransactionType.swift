/// The kinds of ledger rows the stock engine writes (MS-106).
nonisolated enum TransactionType: String, Codable, Sendable {
    case receiving
    case procedure
    case count
    case adjustment
    case disposal
    case cancellation
}
