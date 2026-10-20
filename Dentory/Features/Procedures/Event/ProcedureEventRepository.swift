import Foundation

/// A past procedure (MS-124): its record, the products Add item offers while editing, and the two writes, Edit usage
/// and Cancel procedure, both through the write queue of MS-108.
protocol ProcedureEventRepository: Sendable {
    /// `procedure_event_detail`: throws `AppError.notFound` for a procedure the caller cannot see.
    func event(id: UUID) async throws -> ProcedureEventDetail

    /// `inventory_list`: the products Add item offers.
    func products(clinicID: UUID) async throws -> [ProductSummary]

    /// `stock_procedure_edit`: deducts or returns only the difference and records the new usage.
    func editUsage(_ edit: ProcedureUsageEdit) async throws -> WriteOutcome

    /// `stock_procedure_cancel`: returns every countable to its batch and reverses the bottles still open.
    func cancel(eventID: UUID, note: String) async throws -> WriteOutcome
}
