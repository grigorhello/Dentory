import Foundation

/// Keeps the count in progress on the device until it is applied or discarded, so the counts survive the
/// app being closed while in the background (MS-121).
protocol CountDraftStoring: Sendable {
    func load() -> StockCount?
    func save(_ count: StockCount)
    func clear()
}
