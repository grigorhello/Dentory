import Foundation

/// Which sheet Product detail shows and the view models behind them: Edit and Delete product (MS-117), Adjust
/// (MS-118), Add expiry and Edit batch (MS-119). Each opens only once the detail is loaded.
extension ProductDetailViewModel {
    // MARK: - Edit and Delete product (MS-117)

    func edit() {
        guard detail != nil else { return }
        sheet = .edit
    }

    /// "Save changes" closed the Edit sheet: the screen shows the saved fields.
    func productSaved() async {
        sheet = nil
        await load()
    }

    func askToDelete() {
        sheet = .delete
    }

    func keepProduct() {
        sheet = nil
    }

    var deleteTitle: String { "Delete \(detail?.name ?? "")?" }

    /// "54 cartridges still in stock. The product and its history are archived, not erased. …"
    var deleteMessage: String {
        let archived = "The product and its history are archived, not erased. "
            + "It disappears from Inventory, To buy and procedures."
        guard let detail, detail.quantity > 0 else { return archived }
        return "\(formatters.quantity(detail.quantity, unit: detail.unit)) still in stock. " + archived
    }

    // MARK: - Adjust (MS-118)

    /// The sheet's view model for the loaded product; nil while nothing is loaded.
    func makeAdjustInventoryViewModel() -> AdjustInventoryViewModel? {
        detail.map { AdjustInventoryViewModel(detail: $0, repository: repository, formatters: formatters) }
    }

    func openAdjust() {
        guard detail != nil else { return }
        sheet = .adjust
    }

    // MARK: - Expiry (MS-119)

    func addExpiry() {
        guard detail != nil else { return }
        sheet = .addExpiry
    }

    func editBatch(_ id: UUID) {
        guard detail?.batches.contains(where: { $0.id == id }) == true else { return }
        sheet = .editBatch(id)
    }

    /// The batch sheet's view model for Add expiry or the tapped batch; nil for any other sheet.
    func makeBatchViewModel(for sheet: Sheet) -> BatchViewModel? {
        guard let detail else { return nil }
        let mode: BatchViewModel.Mode
        switch sheet {
        case .addExpiry:
            mode = .add
        case .editBatch(let id):
            guard let batch = detail.batches.first(where: { $0.id == id }) else { return nil }
            mode = .edit(batch)
        default:
            return nil
        }
        return BatchViewModel(detail: detail, mode: mode, repository: repository, formatters: formatters)
    }

    /// Save closed the batch sheet: the fresh detail carries the batches, the status and the history.
    func batchSaved() async {
        sheet = nil
        await load()
    }
}
