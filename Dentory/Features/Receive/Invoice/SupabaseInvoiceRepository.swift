import Foundation
import Supabase

/// The pages go to Storage, the invoice through `invoice_create`, the reading through the `extract_invoice` Edge
/// Function; `invoice_detail` and `invoice_create` decode straight into `InvoiceSummary`, and the line functions
/// (MS-130) into `InvoiceLine`. Receiving and its Undo go through `WriteCoordinator` (MS-131): online now with an
/// idempotency key, queued offline (MS-108). A received invoice's file is deleted online only (MS-146).
struct SupabaseInvoiceRepository: InvoiceRepository {
    let client: SupabaseClient
    let writes: WriteCoordinator

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

    /// `invoice_discard` first, so a delivery received meanwhile on another device is refused with the server's
    /// sentence and keeps its pages (MS-131); then the pages go, whether the invoice was set aside or never created
    /// (Receive manually instead during the upload, which `invoice_discard` answers with nothing). The invoices bucket
    /// lets an admin delete them, read-only or not, but never a received invoice's; `invoice_discard` refuses a
    /// read-only clinic.
    func discard(invoiceID: UUID, clinicID: UUID) async throws {
        do {
            try await client
                .rpc("invoice_discard", params: ["p_invoice_id": invoiceID.uuidString.lowercased()])
                .execute()
            try await client.storage
                .from(InvoiceFiles.bucket)
                .remove(paths: InvoiceFiles.allPaths(clinicID: clinicID, invoiceID: invoiceID))
        } catch {
            throw AppError(error)
        }
    }

    // MARK: - The file (MS-146)

    /// `invoice_file_delete` first: the received invoice lets go of its folder, which the invoices bucket protects
    /// while a received invoice holds it, then every name its pages can have is deleted (Storage passes over the
    /// missing ones), and the invoice is read again. A deletion cut short leaves a page, which the answer shows
    /// (`hasFile`), so it is offered again; asked again, `invoice_file_delete` changes nothing and the pages left go.
    func deleteFile(invoiceID: UUID, clinicID: UUID) async throws -> InvoiceSummary {
        do {
            try await client
                .rpc("invoice_file_delete", params: ["p_invoice_id": invoiceID.uuidString.lowercased()])
                .execute()
            try await client.storage
                .from(InvoiceFiles.bucket)
                .remove(paths: InvoiceFiles.allPaths(clinicID: clinicID, invoiceID: invoiceID))
        } catch {
            throw AppError(error)
        }
        return try await invoice(id: invoiceID)
    }

    // MARK: - Receiving (MS-131)

    func confirm(invoiceID: UUID) async throws -> WriteOutcome {
        try await writes.write("invoice_confirm", params: InvoiceConfirmParams(pInvoiceId: invoiceID))
    }

    func undoConfirm(actionID: UUID) async throws {
        _ = try await writes.write("undo_action", params: UndoActionParams(pActionId: actionID))
    }

    // MARK: - Lines (MS-130)

    func matchLine(_ lineID: UUID, to productID: UUID) async throws -> InvoiceLine {
        try await line("invoice_line_match", lineID, ["p_product_id": .string(productID.uuidString.lowercased())])
    }

    func createLine(_ lineID: UUID, as productID: UUID) async throws -> InvoiceLine {
        try await line("invoice_line_create", lineID, ["p_product_id": .string(productID.uuidString.lowercased())])
    }

    func skipLine(_ lineID: UUID) async throws -> InvoiceLine {
        try await line("invoice_line_skip", lineID)
    }

    func reopenLine(_ lineID: UUID) async throws -> InvoiceLine {
        try await line("invoice_line_reopen", lineID)
    }

    func setBatch(of lineID: UUID, lot: String?, expiryMonth: CalendarDay?) async throws -> InvoiceLine {
        try await line("invoice_line_batch", lineID, [
            "p_lot": lot.map(AnyJSON.string) ?? .null,
            "p_expiry_month": expiryMonth.map { .string($0.isoString) } ?? .null
        ])
    }

    /// One of the line functions, which answer the line as it now stands.
    private func line(
        _ function: String, _ lineID: UUID, _ params: [String: AnyJSON] = [:]
    ) async throws -> InvoiceLine {
        var params = params
        params["p_line_id"] = .string(lineID.uuidString.lowercased())
        do {
            return try await client.rpc(function, params: params).execute().value
        } catch {
            throw AppError(error)
        }
    }
}
