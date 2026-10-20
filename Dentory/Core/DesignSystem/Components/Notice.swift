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

/// A one-line soft-tinted box for a notice ("AI read 4 lines. Check each one, then confirm."), in the design system's
/// caption-strong type (600, 14 pt), as the prototype draws every notice (f14's "10 items deducted" banner).
struct Notice: View {
    let text: String
    var tone: NoticeTone = .info

    init(_ text: String, tone: NoticeTone = .info) {
        self.text = text
        self.tone = tone
    }

    var body: some View {
        Text(text)
            .textStyle(.bodyStrong14)
            .foregroundStyle(tone.statusTone.foreground)
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
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
