import Foundation
import Supabase

/// `product_detail` answers one JSON object; its rows decode with the client's decoder (snake_case keys).
/// Stock writes go through `WriteCoordinator`: online now with an idempotency key, queued offline (MS-108).
struct SupabaseProductDetailRepository: ProductDetailRepository {
    let client: SupabaseClient
    let writes: WriteCoordinator

    func detail(productID: UUID) async throws -> ProductDetail {
        let payload: ProductDetailPayload
        do {
            payload = try await client
                .rpc("product_detail", params: ["p_product_id": productID.uuidString.lowercased()])
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
        guard let product = payload.product else { throw AppError.notFound }
        return ProductDetail(
            id: product.id,
            name: product.name,
            categoryName: product.categoryName,
            unit: product.unit,
            packUnit: product.packUnit,
            packSize: product.packSize,
            minimum: product.minimum,
            target: product.target,
            tracking: product.tracking,
            location: product.location,
            status: product.status,
            quantity: product.quantity,
            unopened: product.unopened,
            openCount: product.openCount,
            missingExpiryQuantity: product.missingExpiryQty,
            usedInLast30Days: payload.usedIn30Days,
            lastCountedAt: payload.lastCountedAt,
            toBuyItemID: payload.toBuyItemId,
            batches: payload.batches.map {
                ProductBatch(id: $0.id, expiryMonth: $0.expiryMonth, lot: $0.lot, quantity: $0.qty)
            },
            openBottles: payload.openItems.map {
                OpenBottle(id: $0.id, openedAt: $0.openedAt, openedByName: $0.openedByName)
            },
            history: payload.history.map {
                StockTransaction(
                    id: $0.id, type: $0.type, delta: $0.delta,
                    quantityBefore: $0.qtyBefore, quantityAfter: $0.qtyAfter,
                    reason: $0.reason, referenceLabel: $0.refLabel, at: $0.at, byName: $0.byName
                )
            }
        )
    }

    func addToBuy(clinicID: UUID, productID: UUID, quantity: Decimal, userID: UUID) async throws -> UUID {
        let row: [String: AnyJSON] = [
            "clinic_id": .string(clinicID.uuidString.lowercased()),
            "product_id": .string(productID.uuidString.lowercased()),
            "qty": .double(NSDecimalNumber(decimal: quantity).doubleValue),
            "qty_edited": .bool(false),
            "source": .string("manual"),
            "added_by": .string(userID.uuidString.lowercased())
        ]
        do {
            let inserted: ToBuyInsertedRow = try await client
                .from("to_buy_items")
                .insert(row)
                .select("id")
                .single()
                .execute()
                .value
            return inserted.id
        } catch {
            throw AppError(error)
        }
    }

    func removeFromToBuy(itemID: UUID) async throws {
        do {
            try await client.from("to_buy_items").delete().eq("id", value: itemID.uuidString).execute()
        } catch {
            throw AppError(error)
        }
    }

    func adjust(
        productID: UUID, actualQuantity: Decimal, reason: AdjustmentReason, note: String?
    ) async throws -> WriteOutcome {
        try await writes.write(
            "stock_adjust",
            params: StockAdjustParams(
                pProductId: productID, pActualQty: actualQuantity, pReason: reason.rawValue, pNote: note
            )
        )
    }

    func undoAdjustment(actionID: UUID) async throws {
        _ = try await writes.write("undo_action", params: UndoActionParams(pActionId: actionID))
    }
}

/// The parameters of `stock_adjust`; the coordinator adds `p_idempotency_key`. A missing note is sent as
/// null, not left out: PostgREST matches the function by its full parameter list.
nonisolated struct StockAdjustParams: Encodable, Sendable {
    let pProductId: UUID
    let pActualQty: Decimal
    let pReason: String
    let pNote: String?

    private enum CodingKeys: String, CodingKey {
        case pProductId, pActualQty, pReason, pNote
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pProductId, forKey: .pProductId)
        try container.encode(pActualQty, forKey: .pActualQty)
        try container.encode(pReason, forKey: .pReason)
        try container.encode(pNote, forKey: .pNote)
    }
}

/// The parameters of `undo_action`.
nonisolated struct UndoActionParams: Encodable, Sendable {
    let pActionId: UUID
}

/// The object `product_detail` returns. Its keys avoid a digit-led component: the snake_case decoder
/// would read `used_30d` as `used30D` and fail.
nonisolated struct ProductDetailPayload: Decodable, Sendable {
    let product: ProductDetailProductRow?
    let usedIn30Days: Decimal
    let lastCountedAt: Date?
    let toBuyItemId: UUID?
    let batches: [ProductDetailBatchRow]
    let openItems: [ProductDetailOpenItemRow]
    let history: [ProductDetailHistoryRow]
}

nonisolated struct ProductDetailProductRow: Decodable, Sendable {
    let id: UUID
    let name: String
    let categoryName: String?
    let unit: String
    let packUnit: String?
    let packSize: Int?
    let minimum: Decimal
    let target: Decimal
    let tracking: TrackingMode
    let location: String?
    let status: ProductStatus
    let quantity: Decimal
    let unopened: Decimal
    let openCount: Int
    let missingExpiryQty: Decimal
}

nonisolated struct ProductDetailBatchRow: Decodable, Sendable {
    let id: UUID
    let expiryMonth: CalendarDay?
    let lot: String?
    let qty: Decimal
}

nonisolated struct ProductDetailOpenItemRow: Decodable, Sendable {
    let id: UUID
    let openedAt: Date
    let openedByName: String
}

nonisolated struct ProductDetailHistoryRow: Decodable, Sendable {
    let id: UUID
    let type: TransactionType
    let delta: Decimal
    let qtyBefore: Decimal
    let qtyAfter: Decimal
    let reason: String?
    let refLabel: String?
    let at: Date
    let byName: String
}

nonisolated struct ToBuyInsertedRow: Decodable, Sendable {
    let id: UUID
}
