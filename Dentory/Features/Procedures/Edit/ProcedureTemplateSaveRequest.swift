import Foundation

/// What Save sends from Edit procedure: the template (nil for a new one), the name as typed and the supplies in
/// screen order, each with its default quantity (0 for a multi-use product).
nonisolated struct ProcedureTemplateSaveRequest: Equatable, Sendable {
    nonisolated struct Line: Equatable, Sendable {
        let productID: UUID
        let defaultQuantity: Int
    }

    let clinicID: UUID
    let templateID: UUID?
    let name: String
    let lines: [Line]
}
