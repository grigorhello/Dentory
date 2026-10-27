import SwiftUI

/// Two fields side by side, as Counted in beside Received as (f21), or a field and its button. Once the text is too
/// large for both on a line, the second goes under the first instead of cutting either one: from the xxLarge text size
/// on an iPhone, at the accessibility sizes in an iPad's wider column (MS-149). The fields are not rebuilt when the
/// layout changes, so focus and what is typed stay.
struct FieldRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// Between the two side by side; one under the other they are `Spacing.md` apart, as a stack's fields are.
    var spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = Spacing.md, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        let layout = isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: spacing))
        layout { content() }
    }

    private var isStacked: Bool {
        horizontalSizeClass == .regular ? dynamicTypeSize.isAccessibilitySize : dynamicTypeSize >= .xxLarge
    }
}

#Preview("Field rows") {
    @Previewable @State var unit = ""
    @Previewable @State var packUnit = ""
    VStack(spacing: Spacing.xl) {
        ForEach([DynamicTypeSize.large, .xxLarge], id: \.self) { size in
            FieldRow {
                MSTextField("Counted in", text: $unit, placeholder: "e.g. cartridges")
                MSTextField("Received as", text: $packUnit, placeholder: "e.g. box")
            }
            .dynamicTypeSize(size)
        }
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
