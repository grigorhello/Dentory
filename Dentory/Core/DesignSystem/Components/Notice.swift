import SwiftUI

nonisolated enum NoticeTone: CaseIterable, Sendable {
    case info, warning, success, danger

    var statusTone: StatusTone {
        switch self {
        case .info: .info
        case .warning: .warning
        case .success: .success
        case .danger: .danger
        }
    }
}

/// The text button a notice may end with ("Billing" on Home's read-only notice, MS-142).
struct NoticeAction {
    let title: String
    let identifier: String
    let perform: () -> Void
}

/// A soft-tinted box for a notice ("AI read 4 lines. Check each one, then confirm."), in the design system's
/// caption-strong type (600, 14 pt), as the prototype draws every notice (f14's "10 items deducted" banner); with an
/// action, a text button sits under the text.
struct Notice: View {
    let text: String
    var tone: NoticeTone = .info
    var action: NoticeAction?
    /// The text's accessibility identifier, when the notice is a screen's own (`home.notice`).
    var identifier: String?

    init(_ text: String, tone: NoticeTone = .info, action: NoticeAction? = nil, identifier: String? = nil) {
        self.text = text
        self.tone = tone
        self.action = action
        self.identifier = identifier
    }

    var body: some View {
        if let action {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                label
                MSButton(action.title, variant: .text, size: .small, action: action.perform)
                    // The label lines up with the text above; the button's own inset reaches into the notice's.
                    .padding(.leading, -MSButtonSize.small.horizontalPadding)
                    .accessibilityIdentifier(action.identifier)
            }
            .modifier(NoticeBox(tone: tone))
        } else {
            label.modifier(NoticeBox(tone: tone))
        }
    }

    @ViewBuilder private var label: some View {
        let label = Text(text)
            .textStyle(.bodyStrong14)
            .foregroundStyle(tone.statusTone.foreground)
        if let identifier {
            label.accessibilityIdentifier(identifier)
        } else {
            label
        }
    }
}

/// The tinted, rounded box every notice sits in.
private struct NoticeBox: ViewModifier {
    let tone: NoticeTone

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.lg)
            .background(tone.statusTone.background, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

#Preview("Notices") {
    VStack(spacing: Spacing.md) {
        Notice("AI read 4 lines. Check each one, then confirm.")
        Notice("Stock levels update immediately.", tone: .warning)
        Notice("Invoice received. 4 products updated.", tone: .success)
        Notice("Couldn't save. Try again.", tone: .danger)
        Notice(
            "Your free trial has ended. Add a card from the link in your billing email to keep updating stock.",
            tone: .warning, action: NoticeAction(title: "Billing", identifier: "notice.billing") {}
        )
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
