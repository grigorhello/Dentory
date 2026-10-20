import Foundation

/// Screens the Procedures tab pushes on its own stack. A past procedure is a placeholder pushed screen until its
/// ticket (MS-124).
enum ProcedureRoute: Hashable {
    /// Adjust, then start (MS-123).
    case start(templateID: UUID)
    /// A past procedure, to edit its usage or cancel it (MS-124).
    case event(UUID)
    /// Edit defaults of a template, or a new one when nil (MS-125).
    case editTemplate(UUID?)
}
