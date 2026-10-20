import Foundation
import Supabase

/// Counts the clinic's active memberships with a head request: no rows travel, only the count. Every member may
/// read their clinic's memberships (MS-105). The export goes through the `export_csv` Edge Function, which checks
/// that the caller is the clinic's admin and allows one export every 10 minutes.
struct SupabaseAccountRepository: AccountRepository {
    let client: SupabaseClient

    func teamSize(clinicID: UUID) async throws -> Int {
        do {
            let response = try await client.from("memberships")
                .select("id", head: true, count: .exact)
                .eq("clinic_id", value: clinicID.uuidString)
                .eq("status", value: "active")
                .execute()
            return response.count ?? 0
        } catch {
            throw AppError(error)
        }
    }

    func startExport(clinicID: UUID) async throws -> String {
        let body: [String: AnyJSON] = ["clinic_id": .string(clinicID.uuidString.lowercased())]
        do {
            let started: ExportStarted = try await client.functions.invoke(
                "export_csv", options: FunctionInvokeOptions(body: body)
            )
            return started.email
        } catch {
            throw AppError(functionError: error)
        }
    }
}

/// The answer of `export_csv`: the address the link goes to.
nonisolated struct ExportStarted: Decodable, Sendable {
    let email: String
}
