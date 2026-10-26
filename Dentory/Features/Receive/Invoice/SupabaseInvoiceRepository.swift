import Foundation
import Supabase

/// The pages go to Storage, the invoice through `invoice_create`, the reading through the `extract_invoice` Edge
/// Function; `invoice_detail` and `invoice_create` decode straight into `InvoiceSummary`.
struct SupabaseInvoiceRepository: InvoiceRepository {
    let client: SupabaseClient

    func upload(_ document: InvoiceDocument, clinicID: UUID) async throws {
        let bucket = client.storage.from(InvoiceFiles.bucket)
        do {
            for (index, page) in document.pages.enumerated() {
                let path = InvoiceFiles.path(
                    clinicID: clinicID, invoiceID: document.id, page: index + 1, kind: page.kind
                )
                try await bucket.upload(
                    path, data: page.data,
                    options: FileOptions(contentType: InvoiceFiles.contentType(of: page.kind), upsert: true)
                )
            }
        } catch {
            throw AppError(error)
        }
    }

    func create(_ document: InvoiceDocument, clinicID: UUID) async throws -> InvoiceSummary {
        let params: [String: AnyJSON] = [
            "p_clinic_id": .string(clinicID.uuidString.lowercased()),
            "p_invoice_id": .string(document.id.uuidString.lowercased()),
            "p_source": .string(document.source.rawValue),
            "p_file_kind": .string(document.kind.rawValue),
            "p_file_count": .integer(document.pages.count)
        ]
        do {
            return try await client.rpc("invoice_create", params: params).execute().value
        } catch {
            throw AppError(error)
        }
    }

    func startReading(invoiceID: UUID) async throws {
        let body: [String: AnyJSON] = ["invoice_id": .string(invoiceID.uuidString.lowercased())]
        do {
            try await client.functions.invoke("extract_invoice", options: FunctionInvokeOptions(body: body))
        } catch {
            throw AppError(functionError: error)
        }
    }

    func invoice(id: UUID) async throws -> InvoiceSummary {
        do {
            return try await client
                .rpc("invoice_detail", params: ["p_invoice_id": id.uuidString.lowercased()])
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }

    func discard(invoiceID: UUID) async throws {
        do {
            try await client
                .rpc("invoice_discard", params: ["p_invoice_id": invoiceID.uuidString.lowercased()])
                .execute()
        } catch {
            throw AppError(error)
        }
    }
}
