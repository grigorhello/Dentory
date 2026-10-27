#if DEBUG
import SwiftUI

struct CatalogColorsSection: View {
    private let swatches: [(String, Color)] = [
        ("primary", .ms.primary), ("primaryHover", .ms.primaryHover), ("primaryActive", .ms.primaryActive),
        ("primarySoft", .ms.primarySoft), ("onPrimary", .ms.onPrimary),
        ("ink", .ms.ink), ("inkSoft", .ms.inkSoft), ("inkMid", .ms.inkMid), ("body", .ms.body),
        ("bodyMid", .ms.bodyMid), ("mute", .ms.mute), ("line", .ms.line),
        ("canvas", .ms.canvas), ("canvasSoft", .ms.canvasSoft), ("canvasSunken", .ms.canvasSunken),
        ("success", .ms.success), ("successSoft", .ms.successSoft), ("warning", .ms.warning),
        ("warningSoft", .ms.warningSoft), ("danger", .ms.danger), ("dangerSoft", .ms.dangerSoft),
        ("info", .ms.info), ("infoSoft", .ms.infoSoft)
    ]

    var body: some View {
        CatalogSection("Colors") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: Spacing.sm)], spacing: Spacing.sm) {
                ForEach(swatches, id: \.0) { name, color in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(color)
                            .frame(height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .strokeBorder(Color.ms.line, lineWidth: 1)
                            )
                        CatalogCaption(name)
                    }
                }
            }
        }
    }
}

struct CatalogTypeSection: View {
    var body: some View {
        CatalogSection("Type") {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(TextStyle.allCases, id: \.self) { style in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(sample(for: style))
                            .textStyle(style)
                            .textCase(style == .eyebrow14 ? .uppercase : nil)
                            .foregroundStyle(Color.ms.ink)
                        CatalogCaption(String(describing: style))
                    }
                }
            }
        }
    }

    private func sample(for style: TextStyle) -> String {
        switch style {
        case .display48: "$12,420"
        case .display32: "Smile Dental"
        case .title24: "Adjust inventory"
        case .title20: "Review invoice"
        case .eyebrow14: "Needs attention"
        case .mono: "SEPTO 4% 1:100K 50/BX"
        case .button18: "Start procedure · 6 items"
        case .button14: "Yes, match"
        default: "12 supplies · 1 not available. Add or remove items before you start."
        }
    }
}

struct CatalogShapeSection: View {
    var body: some View {
        CatalogSection("Shape and elevation") {
            HStack(alignment: .top, spacing: Spacing.lg) {
                shape("sm 6", radius: Radius.sm)
                shape("md 12", radius: Radius.md)
                shape("pill", radius: Radius.pill)
            }
            HStack(alignment: .top, spacing: Spacing.lg) {
                elevation("hairline") { $0.msHairline() }
                elevation("soft") { $0.msShadow(Shadow.soft) }
                elevation("md") { $0.msShadow(Shadow.md) }
                elevation("lg") { $0.msShadow(Shadow.lg) }
            }
            .padding(.bottom, Spacing.lg)
            HStack(alignment: .bottom, spacing: Spacing.sm) {
                ForEach(spacingSteps, id: \.self) { step in
                    VStack(spacing: Spacing.xs) {
                        Rectangle().fill(Color.ms.primarySoft).frame(width: 24, height: step)
                        CatalogCaption("\(Int(step))")
                    }
                }
            }
        }
    }

    private let spacingSteps = [
        Spacing.xxs, Spacing.xs, Spacing.sm, Spacing.md, Spacing.lg, Spacing.xl, Spacing.xxl, Spacing.xxxl
    ]

    private func shape(_ name: String, radius: CGFloat) -> some View {
        VStack(spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.ms.canvasSunken)
                .frame(width: 64, height: 40)
            CatalogCaption(name)
        }
    }

    private func elevation(_ name: String, apply: (AnyView) -> some View) -> some View {
        VStack(spacing: Spacing.xs) {
            apply(AnyView(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color.ms.canvas)
                    .frame(width: 64, height: 40)
            ))
            CatalogCaption(name)
        }
    }
}

struct CatalogIconsSection: View {
    var body: some View {
        CatalogSection("Icons · Lucide 20 pt") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: Spacing.sm)], spacing: Spacing.sm) {
                ForEach(Icon.allCases, id: \.self) { icon in
                    IconView(icon)
                        .foregroundStyle(Color.ms.ink)
                        .frame(width: 44, height: 44)
                        .accessibilityLabel(icon.rawValue)
                }
            }
        }
    }
}
#endif
