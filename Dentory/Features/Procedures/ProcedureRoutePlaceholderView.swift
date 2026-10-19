import SwiftUI

/// A pushed screen that names the ticket bringing the real one.
struct ProcedureRoutePlaceholderView: View {
    let route: ProcedureRoute

    var body: some View {
        Text("\(title) arrives with its own ticket.")
            .textStyle(.body14)
            .foregroundStyle(Color.ms.textSecondary)
            .pushedScreen(title: title, identifier: identifier)
    }

    private var title: String {
        switch route {
        case .start: "Adjust, then start"
        case .event: "Procedure"
        case .editTemplate(let id): id == nil ? "New procedure" : "Edit procedure"
        }
    }

    private var identifier: String {
        switch route {
        case .start, .event: "procDetail"
        case .editTemplate: "procEdit"
        }
    }
}
