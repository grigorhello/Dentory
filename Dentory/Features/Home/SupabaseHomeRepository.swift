import Foundation
import Supabase

/// Rows decode with the client's decoder, which `SupabaseClientProvider` sets to `JSONDecoder.supabase`
/// (snake_case keys); `SupabaseRowDecodingTests` decodes sample PostgREST payloads with it.
///
/// One row of `clinic_attention`, the latest `procedure_events` row with its item count and starter,
/// and `alerts_unseen` for the bell's dot.
struct SupabaseHomeRepository: HomeRepository {
    let client: SupabaseClient

    func summary(clinicID: UUID) async throws -> HomeSummary {
        do {
            async let attention = attentionRow(clinicID: clinicID)
            async let latest = latestProcedure(clinicID: clinicID)
            async let unseen = hasUnseenAlerts(clinicID: clinicID)
            let (row, procedure, hasUnseen) = try await (attention, latest, unseen)
            return HomeSummary(
                toBuyCount: row.toBuyCount,
                expiringBatchCount: row.expiringBatchCount,
                missingExpiryProductCount: row.missingExpiryProductCount,
                inventoryValue: row.inventoryValue,
                valueAtRisk90: row.valueAtRisk90,
                latestProcedure: procedure,
                hasUnseenAlerts: hasUnseen
            )
        } catch {
            throw AppError(error)
        }
    }

    private func attentionRow(clinicID: UUID) async throws -> HomeAttentionRow {
        try await client.from("clinic_attention")
            .select()
            .eq("clinic_id", value: clinicID.uuidString)
            .single()
            .execute()
            .value
    }

    private func latestProcedure(clinicID: UUID) async throws -> LatestProcedure? {
        let events: [HomeEventRow] = try await client.from("procedure_events")
            .select("id, name, started_at, started_by, procedure_event_items(count)")
            .eq("clinic_id", value: clinicID.uuidString)
            .is("cancelled_at", value: nil)
            .order("started_at", ascending: false)
            .limit(1)
            .execute()
            .value
        guard let event = events.first else { return nil }
        let members: [HomeMemberRow] = try await client.from("memberships")
            .select("full_name")
            .eq("clinic_id", value: clinicID.uuidString)
            .eq("user_id", value: event.startedBy.uuidString)
            .limit(1)
            .execute()
            .value
        return LatestProcedure(
            id: event.id,
            name: event.name,
            startedAt: event.startedAt,
            supplyCount: event.procedureEventItems.first?.count ?? 0,
            startedByFirstName: PersonName.first(of: members.first?.fullName ?? "")
        )
    }

    /// An alert on the member's Alerts list that opened after their last visit to it (or any, when they never
    /// visited). The server counts what `activity_alerts` lists for them, so a delivery waiting for review lights
    /// only an admin's bell and an archived product's alert lights none.
    private func hasUnseenAlerts(clinicID: UUID) async throws -> Bool {
        try await client
            .rpc("alerts_unseen", params: ["p_clinic_id": clinicID.uuidString.lowercased()])
            .execute()
            .value
    }

}

nonisolated struct HomeAttentionRow: Decodable {
    let toBuyCount: Int
    let expiringBatchCount: Int
    let missingExpiryProductCount: Int
    let inventoryValue: Decimal
    let valueAtRisk90: Decimal
}

nonisolated struct HomeEventRow: Decodable {
    let id: UUID
    let name: String
    let startedAt: Date
    let startedBy: UUID
    let procedureEventItems: [HomeCountRow]
}

nonisolated struct HomeCountRow: Decodable {
    let count: Int
}

nonisolated struct HomeMemberRow: Decodable {
    let fullName: String
}

