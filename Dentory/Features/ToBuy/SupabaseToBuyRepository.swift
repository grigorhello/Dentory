import Foundation
import Supabase

/// The list and Add item through the MS-128 functions; quantities and removals straight to `to_buy_items` under
/// the MS-105 policies, which let every member change a line still to buy.
struct SupabaseToBuyRepository: ToBuyRepository {
    let client: SupabaseClient

    func items(clinicID: UUID) async throws -> [ToBuyItem] {
        do {
            return try await client
                .rpc("to_buy_list", params: ["p_clinic_id": clinicID.uuidString.lowercased()])
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        try await client.inventoryList(clinicID: clinicID)
    }

    func add(clinicID: UUID, productID: UUID) async throws -> AddedToBuy {
        let params = [
            "p_clinic_id": clinicID.uuidString.lowercased(), "p_product_id": productID.uuidString.lowercased()
        ]
        do {
            return try await client.rpc("to_buy_add", params: params).execute().value
        } catch {
            throw AppError(error)
        }
    }

    func setQuantity(itemID: UUID, quantity: Decimal) async throws {
        let values: [String: AnyJSON] = [
            "qty": .double(NSDecimalNumber(decimal: quantity).doubleValue),
            "qty_edited": .bool(true)
        ]
        do {
            try await client.from("to_buy_items").update(values).eq("id", value: itemID.uuidString).execute()
        } catch {
            throw AppError(error)
        }
    }

    func remove(itemID: UUID) async throws {
        do {
            try await client.from("to_buy_items").delete().eq("id", value: itemID.uuidString).execute()
        } catch {
            throw AppError(error)
        }
    }

    func markOrdered(clinicID: UUID, itemIDs: [UUID]) async throws -> Int {
        let params = ToBuyMarkOrderedParams(pClinicId: clinicID, pItemIds: itemIDs)
        do {
            return try await client.rpc("to_buy_mark_ordered", params: params).execute().value
        } catch {
            throw AppError(error)
        }
    }
}
