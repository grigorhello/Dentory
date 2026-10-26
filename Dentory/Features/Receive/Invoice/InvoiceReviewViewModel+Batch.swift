import Foundation

/// The Lot and Expiry inputs of a Matched or Created line on Review invoice (Appendix B `invoice.line[n].lot` and
/// `.expiry`, MS-130): what the inputs bind to, saved a moment after the last change, at once on Return, before Confirm
/// & receive and when the screen is left, and kept as typed when a save fails or a fresh reading comes in. The change
/// and the save themselves are in `InvoiceReviewViewModel.swift`.
extension InvoiceReviewViewModel {
    /// The Lot input's binding, `$viewModel[lotOf: id]`: up to the 60 characters a lot keeps, saved a moment after the
    /// last change.
    subscript(lotOf id: UUID) -> String {
        get { lines.first { $0.id == id }?.lot ?? "" }
        set {
            let lot = String(newValue.prefix(Self.lotLength))
            changeBatch(of: id) { $0.lot = lot.isEmpty ? nil : lot }
        }
    }

    /// The Expiry input's binding, `$viewModel[expiryOf: id]`, kept as the month's first day.
    subscript(expiryOf id: UUID) -> YearMonth? {
        get { lines.first { $0.id == id }?.expiryMonth.map(YearMonth.init(day:)) }
        set { changeBatch(of: id) { $0.expiryMonth = newValue.map(CalendarDay.init(yearMonth:)) } }
    }

    /// Return on the Lot input saves it straight away.
    func saveBatchNow(of id: UUID) {
        guard unsavedBatchIDs.contains(id) else { return }
        batchSaves[id]?.cancel()
        batchSaves[id] = Task { await self.saveBatch(of: id) }
    }

    /// Saves every lot and expiry still waiting: on leaving the screen, and before Confirm & receive (MS-131).
    func flushPendingSaves() async {
        for id in unsavedBatchIDs {
            batchSaves[id]?.cancel()
            await saveBatch(of: id)
        }
    }

    /// Discard invoice: what was typed is not sent any more.
    func dropPendingSaves() {
        batchSaves.values.forEach { $0.cancel() }
        batchSaves = [:]
        unsavedBatchIDs = []
    }

    /// A line from the server with the lot and expiry typed here, while they are not saved yet.
    func keepingUnsavedBatch(_ fresh: InvoiceLine) -> InvoiceLine {
        guard unsavedBatchIDs.contains(fresh.id), let current = lines.first(where: { $0.id == fresh.id }) else {
            return fresh
        }
        var line = fresh
        line.lot = current.lot
        line.expiryMonth = current.expiryMonth
        return line
    }
}
