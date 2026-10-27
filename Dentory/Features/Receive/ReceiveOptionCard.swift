import SwiftUI

/// One way to receive on Receive delivery (f22): an icon in a circle, the title over one line saying what it takes,
/// and a chevron. Take a photo is the screen's dark featured card; the others sit on cream. The icon goes over the text
/// at the accessibility text sizes, where beside it "manually" broke (MS-149).
struct ReceiveOptionCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let icon: Icon
    let title: String
    let detail: String
    var isFeatured = false
    let action: () -> Void

    var body: some View {
        let iconAndText = AnyLayout.row(stacked: dynamicTypeSize.isAccessibilitySize, spacing: Spacing.lg)
        Button(action: action) {
            HStack(spacing: Spacing.lg) {
                iconAndText {
                    IconView(icon, size: 22)
                        .foregroundStyle(foreground)
                        .frame(width: ControlHeight.md, height: ControlHeight.md)
                        .background(isFeatured ? Color.ms.inkMid : Color.ms.surfacePage, in: Circle())
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(title).textStyle(.bodyStrong16).foregroundStyle(foreground)
                        Text(detail)
                            .textStyle(.body14)
                            .foregroundStyle(isFeatured ? Color.ms.mute : Color.ms.textBody)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Spacing.sm)
                IconView(.chevronRight, size: 24).foregroundStyle(foreground)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg + Spacing.xxs)
            .background(
                isFeatured ? Color.ms.surfaceDark : Color.ms.surfaceCard,
                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var foreground: Color {
        isFeatured ? .ms.textOnDark : .ms.ink
    }
}

#Preview("Options") {
    VStack(spacing: Spacing.md) {
        ReceiveOptionCard(
            icon: .camera, title: "Take a photo", detail: "Invoice or packing slip.", isFeatured: true
        ) {}
        ReceiveOptionCard(icon: .upload, title: "Upload PDF or image", detail: "From files or email.") {}
        ReceiveOptionCard(icon: .penLine, title: "Receive manually", detail: "No invoice, or a single item.") {}
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
