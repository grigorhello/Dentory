import Foundation

/// What `procedure_template_save` answers: the template's id, the name it was stored under ("Untitled procedure"
/// when none was typed) and how many supplies it lists.
nonisolated struct SavedProcedureTemplate: Decodable, Equatable, Sendable {
    let id: UUID
    let name: String
    let itemCount: Int
}
