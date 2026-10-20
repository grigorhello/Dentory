import Foundation
import Supabase

/// `billing_summary`, and the `billing_checkout` and `billing_portal` Edge Functions, which answer `{ url }`.
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

    func paymentPage(clinicID: UUID, hasSubscription: Bool) async throws -> URL? {
        let body: [String: AnyJSON] = ["clinic_id": .string(clinicID.uuidString.lowercased())]
        let page: PaymentPage
        do {
            page = try await client.functions.invoke(
                hasSubscription ? "billing_portal" : "billing_checkout", options: FunctionInvokeOptions(body: body)
            )
        } catch {
            throw AppError(functionError: error)
        }
        guard let url = URL(string: page.url), url.scheme == "https" else { throw AppError.unknown("No payment page") }
        return url
    }
}

/// The answer of `billing_checkout` and `billing_portal`.
nonisolated struct PaymentPage: Decodable, Sendable {
    let url: String
}
