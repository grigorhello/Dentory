import SwiftUI

/// A list row: title (14 ink), one caption line (12 secondary, or a status tone when it warns),
/// and on the right a value, a badge or any trailing view. The chevron appears only when the row navigates.
struct ListRow<Trailing: View>: View {
    let title: String
    var caption: String?
    var captionTone: StatusTone?
    var navigates = false
    var showsDivider = true
    @ViewBuilder let trailing: () -> Trailing

    init(
        _ title: String,
        caption: String? = nil,
        captionTone: StatusTone? = nil,
        navigates: Bool = false,
        showsDivider: Bool = true,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.caption = caption
        self.captionTone = captionTone
        self.navigates = navigates
        self.showsDivider = showsDivider
        self.trailing = trailing
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title).textStyle(.body14).foregroundStyle(Color.ms.ink)
                    if let caption {
                        Text(caption)
                            .textStyle(.caption12)
                            .foregroundStyle(captionTone?.foreground ?? Color.ms.textSecondary)
                    }
                }
                Spacer(minLength: Spacing.sm)
                trailing()
                if navigates {
                    IconView(.chevronRight, size: 20).foregroundStyle(Color.ms.textBody)
                }
            }
            .padding(.vertical, Spacing.md + Spacing.xxs)
            .frame(minHeight: ControlHeight.hitTarget)
            if showsDivider {
                ListDivider()
            }
        }
        .contentShape(Rectangle())
    }
}

extension ListRow where Trailing == EmptyView {
    init(
        _ title: String,
        caption: String? = nil,
        captionTone: StatusTone? = nil,
        navigates: Bool = false,
        showsDivider: Bool = true
    ) {
        self.init(title, caption: caption, captionTone: captionTone, navigates: navigates, showsDivider: showsDivider) {
            EmptyView()
        }
    }
}

extension ListRow where Trailing == ListRowValue {
    /// A row whose right side is a plain value ("54", "$186").
    init(
        _ title: String,
        caption: String? = nil,
        captionTone: StatusTone? = nil,
        value: String,
        navigates: Bool = false,
        showsDivider: Bool = true
    ) {
        self.init(title, caption: caption, captionTone: captionTone, navigates: navigates, showsDivider: showsDivider) {
            ListRowValue(value)
        }
    }
}

/// The right-side value of a row: 16 semibold ink, tabular digits.
struct ListRowValue: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value).textStyle(.bodyStrong16).foregroundStyle(Color.ms.ink).monospacedDigit()
    }
}

extension ListRow where Trailing == StatusBadge {
    /// A row whose right side is a status badge, the small one the Inventory rows draw (f16, f17, f19).
    init(
        _ title: String,
        caption: String? = nil,
        captionTone: StatusTone? = nil,
        badge: StatusBadgeKind,
        navigates: Bool = false,
        showsDivider: Bool = true
    ) {
        self.init(title, caption: caption, captionTone: captionTone, navigates: navigates, showsDivider: showsDivider) {
            StatusBadge(badge, size: .small)
        }
    }
}

#Preview("Rows") {
    ListCard {
        ListRow("Septocaine 4% 1:100,000", caption: "Anesthetic · 54 cartridges", badge: .healthy, navigates: true)
        ListRow("Composite A2", caption: "Current 2 · target 6 · Patterson", value: "4")
        ListRow("Alginate impression", caption: "Lab · Shelf 1", showsDivider: false) {
            QuantityStepper(value: .constant(3), reference: 4, name: "Endo file kit", identifier: "preview.row[3]")
        }
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
