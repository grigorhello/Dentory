import Foundation
import Supabase

/// Rows decode with the client's decoder, which `SupabaseClientProvider` sets to `JSONDecoder.supabase`
/// (snake_case keys); `SupabaseRowDecodingTests` decodes sample PostgREST payloads with it.
///
/// One row of `clinic_attention`, the latest `procedure_events` row with its item count and starter,
/// and the newest open alert against the user's `alert_reads` mark.
struct SupabaseHomeRepository: HomeRepository {
    let client: SupabaseClient

    func summary(clinicID: UUID, userID: UUID) async throws -> HomeSummary {
        do {
            async let attention = attentionRow(clinicID: clinicID)
            async let latest = latestProcedure(clinicID: clinicID)
            async let unseen = hasUnseenAlerts(clinicID: clinicID, userID: userID)
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

    /// An alert opened after the user's last visit to Alerts (or ever, when they never visited).
    private func hasUnseenAlerts(clinicID: UUID, userID: UUID) async throws -> Bool {
        let alerts: [HomeAlertRow] = try await client.from("alerts")
            .select("opened_at")
            .eq("clinic_id", value: clinicID.uuidString)
            .is("resolved_at", value: nil)
            .order("opened_at", ascending: false)
            .limit(1)
            .execute()
            .value
        guard let newest = alerts.first else { return false }
        let reads: [HomeReadRow] = try await client.from("alert_reads")
            .select("last_seen_at")
            .eq("clinic_id", value: clinicID.uuidString)
            .eq("user_id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value
        guard let lastSeen = reads.first?.lastSeenAt else { return true }
        return newest.openedAt > lastSeen
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

nonisolated struct HomeAlertRow: Decodable {
    let openedAt: Date
}

nonisolated struct HomeReadRow: Decodable {
    let lastSeenAt: Date
}
