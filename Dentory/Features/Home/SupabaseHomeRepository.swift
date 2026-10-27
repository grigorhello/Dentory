import Foundation
import Supabase

/// Rows decode with the client's decoder, which `SupabaseClientProvider` sets to `JSONDecoder.supabase`
/// (snake_case keys); `SupabaseRowDecodingTests` decodes sample PostgREST payloads with it.
///
/// One row of `clinic_attention`, the latest `procedure_events` row with its item count and starter,
/// and `alerts_unseen` for the bell's dot, all asked for at once.
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

    /// The procedure and the clinic's members come together, the starter being one of the members, so Home waits for
    /// one round trip rather than a second one after the procedure (MS-150).
    private func latestProcedure(clinicID: UUID) async throws -> LatestProcedure? {
        async let latest = latestEvent(clinicID: clinicID)
        async let members = memberNames(clinicID: clinicID)
        guard let event = try await latest else { return nil }
        let names = try await members
        return LatestProcedure(event: event, members: names)
    }

    private func latestEvent(clinicID: UUID) async throws -> HomeEventRow? {
        let events: [HomeEventRow] = try await client.from("procedure_events")
            .select("id, name, started_at, started_by, procedure_event_items(count)")
            .eq("clinic_id", value: clinicID.uuidString)
            .is("cancelled_at", value: nil)
            .order("started_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return events.first
    }

    /// Every membership of the clinic, a handful of rows, invited and removed ones included.
    private func memberNames(clinicID: UUID) async throws -> [HomeMemberRow] {
        try await client.from("memberships")
            .select("user_id, full_name")
            .eq("clinic_id", value: clinicID.uuidString)
            .execute()
            .value
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
    /// Null while the invitation is not accepted.
    let userId: UUID?
    let fullName: String
}

extension LatestProcedure {
    /// Home's procedure from its row and the clinic's members: the starter's first name, empty when their membership
    /// is gone.
    init(event: HomeEventRow, members: [HomeMemberRow]) {
        let starter = members.first { $0.userId == event.startedBy }
        self.init(
            id: event.id,
            name: event.name,
            startedAt: event.startedAt,
            supplyCount: event.procedureEventItems.first?.count ?? 0,
            startedByFirstName: PersonName.first(of: starter?.fullName ?? "")
        )
    }
}
