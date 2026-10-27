import SwiftUI

/// The dark featured card of f6: Start a procedure, then the latest procedure with Edit usage.
struct ProcedureCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let latest: LatestProcedure?
    let startedAtText: String
    let onStart: () -> Void
    let onEditUsage: (UUID) -> Void

    var body: some View {
        CardView(variant: .dark) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Eyebrow("Procedure", color: .ms.mute)
                    .accessibilityAddTraits(.isHeader)
                MSButton("Start a procedure", icon: .clipboardCheck, action: onStart)
                    .accessibilityIdentifier("home.procedure.start")
                if let latest {
                    Rectangle().fill(Color.ms.inkMid).frame(height: 1)
                    latestLine
                    latestRow(latest)
                }
            }
        }
    }

    /// Latest, then when it started at the end of the line; under it at the accessibility text sizes, where beside the
    /// eyebrow the time broke ("3:14 P / M", MS-149).
    private var latestLine: some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let layout = AnyLayout.row(stacked: isStacked, alignment: .firstTextBaseline, stackedSpacing: Spacing.xxs)
        return layout {
            Eyebrow("Latest", color: .ms.mute)
            if !isStacked {
                Spacer()
            }
            Text(startedAtText).textStyle(.body14).foregroundStyle(Color.ms.mute)
        }
    }

    /// The procedure and its supplies, Edit usage beside them; under them at the accessibility text sizes, where beside
    /// the button both broke mid-word ("supplie / s", "usag / e", MS-149).
    private func latestRow(_ latest: LatestProcedure) -> some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let layout = AnyLayout.row(stacked: isStacked, stackedSpacing: Spacing.md)
        return layout {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(latest.name).textStyle(.bodyStrong16).foregroundStyle(Color.ms.textOnDark)
                Text(supplies(latest)).textStyle(.body14).foregroundStyle(Color.ms.mute)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("home.procedure.latest")
            if !isStacked {
                Spacer(minLength: Spacing.sm)
            }
            Button {
                onEditUsage(latest.id)
            } label: {
                Label("Edit usage", icon: .pencil)
            }
            .buttonStyle(.ms(.outlineOnDark, size: .small))
            .accessibilityIdentifier("home.procedure.editUsage")
        }
    }

    private func supplies(_ latest: LatestProcedure) -> String {
        let count = "\(latest.supplyCount) \(latest.supplyCount == 1 ? "supply" : "supplies")"
        return Caption.joined(count, latest.startedByFirstName)
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
