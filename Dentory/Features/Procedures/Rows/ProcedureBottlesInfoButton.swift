import SwiftUI

/// The (i) of "Opened a new one?": a 24 pt icon in secondary text whose 44 pt target reaches past it.
struct ProcedureBottlesInfoButton: View {
    let action: () -> Void

    private let iconSize: CGFloat = 24

    var body: some View {
        Button(action: action) {
            IconView(.info, size: iconSize)
                .foregroundStyle(Color.ms.textSecondary)
                .contentShape(Rectangle().inset(by: -(ControlHeight.hitTarget - iconSize) / 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("About Take new")
        .accessibilityIdentifier("procDetail.bottles.info")
    }
}
