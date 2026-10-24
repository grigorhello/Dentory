import Foundation
import Supabase

extension SupabaseClient {
    /// `inventory_list`: every active product of the clinic with its category, figures and status, in one call.
    /// The Inventory list (MS-115) and Add item on Adjust, then start (MS-123) read it.
    func inventoryList(clinicID: UUID) async throws -> [ProductSummary] {
        do {
            let rows: [InventoryRow] = try await rpc(
                "inventory_list", params: ["p_clinic_id": clinicID.uuidString.lowercased()]
            )
            .execute()
            .value
            return rows.map(ProductSummary.init(row:))
        } catch {
            throw AppError(error)
        }
    }
}
