import Foundation
import Supabase

/// Categories and products through PostgREST under the clinic's policies, plus the two MS-117 functions.
struct SupabaseProductFormRepository: ProductFormRepository {
    let client: SupabaseClient

    func categories(clinicID: UUID) async throws -> [ProductCategory] {
        do {
            return try await client
                .from("categories")
                .select("id, name")
                .eq("clinic_id", value: clinicID.uuidString)
                .order("position")
                .order("name")
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }

    func findOrCreateCategory(clinicID: UUID, name: String) async throws -> ProductCategory {
        do {
            return try await client
                .rpc(
                    "category_find_or_create",
                    params: ["p_clinic_id": clinicID.uuidString.lowercased(), "p_name": name]
                )
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }

    func createProduct(clinicID: UUID, draft: ProductDraft) async throws -> UUID {
        var row = Self.row(for: draft)
        row["clinic_id"] = .string(clinicID.uuidString.lowercased())
        do {
            let inserted: ProductIDRow = try await client
                .from("products")
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

    func updateProduct(id: UUID, draft: ProductDraft) async throws {
        do {
            // `.single()` turns an update the policies let through for nobody into a refusal instead of silence.
            let _: ProductIDRow = try await client
                .from("products")
                .update(Self.row(for: draft))
                .eq("id", value: id.uuidString)
                .select("id")
                .single()
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }

    /// The columns the sheet owns; the stock columns belong to the engine.
    private static func row(for draft: ProductDraft) -> [String: AnyJSON] {
        [
            "name": .string(draft.name),
            "category_id": draft.categoryID.map { .string($0.uuidString.lowercased()) } ?? .null,
            "unit": .string(draft.unit),
            "pack_unit": draft.packUnit.map(AnyJSON.string) ?? .null,
            "pack_size": draft.packSize.map { .integer($0) } ?? .null,
            "tracking": .string(draft.tracking.rawValue),
            "minimum": .double(NSDecimalNumber(decimal: draft.minimum).doubleValue),
            "target": .double(NSDecimalNumber(decimal: draft.target).doubleValue),
            "supplier": draft.supplier.map(AnyJSON.string) ?? .null,
            "location": draft.location.map(AnyJSON.string) ?? .null
        ]
    }
}

nonisolated struct ProductIDRow: Decodable, Sendable {
    let id: UUID
}
