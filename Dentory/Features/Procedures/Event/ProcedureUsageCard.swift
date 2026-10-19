import SwiftUI

/// "Supplies used / Used" (f14): what the procedure recorded, read-only. A multi-use product reads "Opened a new
/// bottle" or "Used from open bottle" under its name instead of a number.
struct ProcedureUsageCard: View {
    let viewModel: ProcedureEventViewModel
    let items: [ProcedureEventDetail.Item]

    var body: some View {
        ListCard {
            ListHeaderRow("Supplies used", trailing: "Used")
            ForEach(items) { item in
                row(for: item)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("procDetail.used[\(item.id.uuidString.lowercased())]")
            }
        }
    }

    @ViewBuilder private func row(for item: ProcedureEventDetail.Item) -> some View {
        let showsDivider = item.id != items.last?.id
        switch item.tracking {
        case .countable:
            ListRow(item.name, value: viewModel.usage(of: item), showsDivider: showsDivider)
        case .multiUse:
            ListRow(item.name, caption: viewModel.usage(of: item), showsDivider: showsDivider)
        }
    }
}
