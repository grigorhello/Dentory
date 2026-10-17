import SwiftUI

/// One of the three "Needs attention" tiles (f6): a big count in its status color, ink at 0, a short label.
struct AttentionTile: View {
    let count: Int
    let label: String
    let tone: StatusTone
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("\(count)")
                    .textStyle(.display32)
                    .foregroundStyle(HomeViewModel.tone(for: count, nonZero: tone).foreground)
                Text(label)
                    .textStyle(.body16)
                    .foregroundStyle(Color.ms.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(Spacing.lg)
            .background(Color.ms.surfaceCard, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) \(label)")
        .accessibilityIdentifier(identifier)
    }
}

/// A value tile (f6): caption above a bold amount.
struct ValueTile: View {
    let label: String
    let value: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(label).textStyle(.body14).foregroundStyle(Color.ms.textSecondary)
                Text(value).textStyle(.title20).foregroundStyle(Color.ms.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .background(Color.ms.surfaceCard, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
        .accessibilityIdentifier(identifier)
    }
}

/// The round cream header buttons of f6 (bell, account), with an optional red dot.
struct HomeHeaderButton: View {
    let icon: Icon
    let label: String
    var showsDot = false
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            IconView(icon, size: 22)
                .foregroundStyle(Color.ms.ink)
                .frame(width: ControlHeight.md, height: ControlHeight.md)
                .background(Color.ms.surfaceCard, in: Circle())
                .overlay(alignment: .topTrailing) {
                    if showsDot {
                        Circle()
                            .fill(Color.ms.danger)
                            .frame(width: Spacing.sm, height: Spacing.sm)
                            .offset(x: -Spacing.sm, y: Spacing.sm)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(showsDot ? "New alerts" : "")
        .accessibilityIdentifier(identifier)
    }
}

#Preview("Tiles") {
    VStack(spacing: Spacing.md) {
        HStack(spacing: Spacing.md) {
            AttentionTile(count: 3, label: "To buy", tone: .warning, identifier: "a") {}
            AttentionTile(count: 2, label: "Expiring soon", tone: .danger, identifier: "b") {}
            AttentionTile(count: 0, label: "Missing expiry", tone: .info, identifier: "c") {}
        }
        HStack(spacing: Spacing.md) {
            ValueTile(label: "Inventory value", value: "$12,420", identifier: "d") {}
            ValueTile(label: "At risk, 90 days", value: "$186", identifier: "e") {}
        }
        HStack { HomeHeaderButton(icon: .bell, label: "Alerts", showsDot: true, identifier: "f") {} }
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
