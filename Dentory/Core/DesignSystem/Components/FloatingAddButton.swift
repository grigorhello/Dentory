import SwiftUI

/// The round 56 pt + button at the bottom right of a list (PRD §7). The caller positions it.
struct FloatingAddButton: View {
    var label = "Add"
    let action: () -> Void

    init(label: String = "Add", action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            IconView(.plus, size: 24)
        }
        .buttonStyle(FloatingAddButtonStyle())
        .accessibilityLabel(label)
    }
}

struct FloatingAddButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.ms.onPrimary)
            .frame(width: 56, height: 56)
            .background(configuration.isPressed ? Color.ms.primaryActive : Color.ms.primary, in: Circle())
            .msShadow(Shadow.md)
            .animation(Motion.fastAnimation, value: configuration.isPressed)
    }
}

#Preview("Floating add") {
    ZStack(alignment: .bottomTrailing) {
        Color.ms.canvas
        FloatingAddButton(label: "Add item") {}
            .padding(Spacing.page)
    }
}
