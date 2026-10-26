import SwiftUI

/// The dark featured card of f6: Start a procedure, then the latest procedure with Edit usage.
struct ProcedureCard: View {
    let latest: LatestProcedure?
    let startedAtText: String
    let onStart: () -> Void
    let onEditUsage: (UUID) -> Void

    var body: some View {
        CardView(variant: .dark) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Eyebrow("Procedure", color: .ms.mute)
                MSButton("Start a procedure", icon: .clipboardCheck, action: onStart)
                    .accessibilityIdentifier("home.procedure.start")
                if let latest {
                    Rectangle().fill(Color.ms.inkMid).frame(height: 1)
                    HStack(alignment: .firstTextBaseline) {
                        Eyebrow("Latest", color: .ms.mute)
                        Spacer()
                        Text(startedAtText).textStyle(.body14).foregroundStyle(Color.ms.mute)
                    }
                    HStack(alignment: .center, spacing: Spacing.md) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(latest.name).textStyle(.title20).foregroundStyle(Color.ms.textOnDark)
                            Text(supplies(latest)).textStyle(.body14).foregroundStyle(Color.ms.mute)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("home.procedure.latest")
                        Spacer(minLength: Spacing.sm)
                        Button {
                            onEditUsage(latest.id)
                        } label: {
                            Label("Edit usage", icon: .pencil)
                        }
                        .buttonStyle(.ms(.outlineOnDark, size: .small))
                        .accessibilityIdentifier("home.procedure.editUsage")
                    }
                }
            }
        }
    }

    private func supplies(_ latest: LatestProcedure) -> String {
        let count = "\(latest.supplyCount) \(latest.supplyCount == 1 ? "supply" : "supplies")"
        return latest.startedByFirstName.isEmpty ? count : "\(count)\u{00A0}· \(latest.startedByFirstName)"
    }
}

/// An icon before a label, at the button's icon size.
private struct Label: View {
    let title: String
    let icon: Icon

    init(_ title: String, icon: Icon) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            IconView(icon, size: MSButtonSize.small.iconSize)
            Text(title)
        }
    }
}

#Preview("Procedure card") {
    VStack(spacing: Spacing.lg) {
        ProcedureCard(
            latest: HomeSummary.demo.latestProcedure,
            startedAtText: "Oct 1 · 3:14 PM",
            onStart: {},
            onEditUsage: { _ in }
        )
        ProcedureCard(latest: nil, startedAtText: "", onStart: {}, onEditUsage: { _ in })
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
