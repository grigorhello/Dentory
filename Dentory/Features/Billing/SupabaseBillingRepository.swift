import Foundation
import Supabase

/// `billing_summary`, the one row Billing shows; the invoices from `billing_invoices` (admins read them); the
/// billing emails through `billing_emails_list` and `billing_emails_save`, which keep the primary first.
struct SupabaseBillingRepository: BillingRepository {
    let client: SupabaseClient

    func summary(clinicID: UUID) async throws -> BillingSummary {
        do {
            return try await client
                .rpc("billing_summary", params: ["p_clinic_id": clinicID.uuidString.lowercased()])
                .single()
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }

    func invoices(clinicID: UUID) async throws -> [BillingInvoice] {
        do {
            return try await client.from("billing_invoices")
                .select("id, number, issued_at, amount_cents, currency, status")
                .eq("clinic_id", value: clinicID.uuidString.lowercased())
                .order("issued_at", ascending: false)
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }

    func billingEmails(clinicID: UUID) async throws -> [String] {
        do {
            return try await client
                .rpc("billing_emails_list", params: ["p_clinic_id": clinicID.uuidString.lowercased()])
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }

    func saveBillingEmails(clinicID: UUID, extra: [String]) async throws -> [String] {
        do {
            return try await client
                .rpc("billing_emails_save", params: BillingEmailsParams(pClinicId: clinicID, pExtra: extra))
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }
}

/// `billing_emails_save`'s arguments, snake_cased by the client's encoder.
nonisolated struct BillingEmailsParams: Encodable, Sendable {
    let pClinicId: UUID
    let pExtra: [String]
}
