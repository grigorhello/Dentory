import Foundation

/// The templates and history of frames f11 and f12 for previews and UI tests.
struct DemoProceduresRepository: ProceduresRepository {
    func templates(clinicID: UUID) async throws -> [ProcedureTemplateSummary] {
        ProcedureTemplateSummary.demo
    }

    func history(clinicID: UUID, after: ProcedureEventSummary?, limit: Int) async throws -> [ProcedureEventSummary] {
        let events = ProcedureEventSummary.demo
        let start = after.flatMap { last in events.firstIndex { $0.id == last.id }.map { $0 + 1 } } ?? 0
        return Array(events.dropFirst(start).prefix(limit))
    }
}

extension ProcedureTemplateSummary {
    /// f11's templates: Root canal is short of Rubber dam, the others are covered.
    nonisolated static let demo: [ProcedureTemplateSummary] = [
        demo(1, "Root canal", items: 12, notAvailable: 1, runOut: 1),
        demo(2, "Cleaning", items: 7),
        demo(3, "Filling", items: 12),
        demo(4, "Crown", items: 10),
        demo(5, "Extraction", items: 8)
    ]

    private nonisolated static func demo(
        _ number: Int, _ name: String, items: Int, notAvailable: Int = 0, runOut: Int = 0
    ) -> ProcedureTemplateSummary {
        ProcedureTemplateSummary(
            id: UUID(uuidString: String(format: "d0000000-0000-4000-8000-0000000003%02d", number)) ?? UUID(),
            name: name, itemCount: items, notAvailableCount: notAvailable, runOutCount: runOut
        )
    }
}

extension ProcedureEventSummary {
    /// f11's history, newest first; Root canal is the one Home shows as the latest procedure.
    nonisolated static let demo: [ProcedureEventSummary] = [
        ProcedureEventSummary(
            id: UUID(uuidString: "00000000-0000-4000-8000-0000000000e1") ?? UUID(), name: "Root canal",
            startedAt: Date(timeIntervalSince1970: 1_790_882_040), // Oct 1 · 3:14 PM in New York
            startedByName: "Sarah Mitchell", itemCount: 12, cancelledAt: nil
        ),
        ProcedureEventSummary(
            id: UUID(uuidString: "00000000-0000-4000-8000-0000000000e2") ?? UUID(), name: "Cleaning",
            startedAt: Date(timeIntervalSince1970: 1_790_868_000), // Oct 1 · 11:20 AM
            startedByName: "Michael Reyes", itemCount: 7, cancelledAt: nil
        ),
        ProcedureEventSummary(
            id: UUID(uuidString: "00000000-0000-4000-8000-0000000000e3") ?? UUID(), name: "Filling",
            startedAt: Date(timeIntervalSince1970: 1_790_791_500), // Sep 30 · 2:05 PM
            startedByName: "Sarah Mitchell", itemCount: 12, cancelledAt: nil
        )
    ]
}
