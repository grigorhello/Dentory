import SwiftUI

/// The type ladder (`tokens/typography.css`) at the sizes the mobile PRD uses: Outfit for display and eyebrows,
/// Inter for everything else, the system monospaced face for codes. Every style scales with Dynamic Type.
nonisolated enum TextStyle: CaseIterable, Sendable {
    /// A large figure such as the Inventory value total (f10), Outfit 500 48 (`--type-display-lg`).
    case display48
    /// Root screen title, Outfit 500 32.
    case display32
    /// Sheet title, Inter 600 24 (PRD §7; no frame draws a sheet).
    case title24
    /// Pushed screen title as the frames draw it (f13, f20, f34), and section title, Inter 700 20
    /// (`--type-display-xs`).
    case title20
    /// Larger body: inputs, checkbox labels, segment labels, Inter 400 16.
    case body16
    case bodyStrong16
    /// Default body and list row title, Inter 400 14.
    case body14
    case bodyStrong14
    /// Captions and list row second lines, Inter 400 12. Nothing in the app is smaller.
    case caption12
    /// Small badges and counts, Inter 500 12 (`--type-micro`).
    case micro12
    /// Section eyebrow, Outfit 500 14, uppercase with 1 pt tracking (the only uppercase in the system).
    case eyebrow14
    /// Medium button label, Inter 600 18.
    case button18
    /// Small button label, Inter 700 14.
    case button14
    /// Invoice line text and lot numbers, system monospaced 500 13.
    case mono

    var font: Font {
        switch self {
        case .display48: .custom(FontName.outfitMedium, size: 48, relativeTo: .largeTitle)
        case .display32: .custom(FontName.outfitMedium, size: 32, relativeTo: .largeTitle)
        case .title24: .custom(FontName.interSemiBold, size: 24, relativeTo: .title2)
        case .title20: .custom(FontName.interBold, size: 20, relativeTo: .title3)
        case .body16: .custom(FontName.interRegular, size: 16, relativeTo: .callout)
        case .bodyStrong16: .custom(FontName.interSemiBold, size: 16, relativeTo: .callout)
        case .body14: .custom(FontName.interRegular, size: 14, relativeTo: .subheadline)
        case .bodyStrong14: .custom(FontName.interSemiBold, size: 14, relativeTo: .subheadline)
        case .caption12: .custom(FontName.interRegular, size: 12, relativeTo: .caption)
        case .micro12: .custom(FontName.interMedium, size: 12, relativeTo: .caption)
        case .eyebrow14: .custom(FontName.outfitMedium, size: 14, relativeTo: .subheadline)
        case .button18: .custom(FontName.interSemiBold, size: 18, relativeTo: .body)
        case .button14: .custom(FontName.interBold, size: 14, relativeTo: .subheadline)
        case .mono: .system(.footnote, design: .monospaced).weight(.medium)
        }
    }

    /// Letter spacing in points, from the `*-tracking` tokens.
    var tracking: CGFloat {
        switch self {
        case .display32, .eyebrow14: 1
        case .title24: -0.6
        case .title20: -0.5
        case .button14: 0.15
        default: 0
        }
    }
}

/// PostScript names of the bundled fonts (`Resources/Fonts`, registered in `Info.plist`).
nonisolated enum FontName {
    static let outfitRegular = "Outfit-Regular"
    static let outfitMedium = "Outfit-Medium"
    static let outfitSemiBold = "Outfit-SemiBold"
    static let interRegular = "Inter-Regular"
    static let interMedium = "Inter-Medium"
    static let interSemiBold = "Inter-SemiBold"
    static let interBold = "Inter-Bold"

    static let all = [outfitRegular, outfitMedium, outfitSemiBold, interRegular, interMedium, interSemiBold, interBold]
}

extension View {
    /// Applies a type token: font and tracking together, so feature code never names a font or size.
    func textStyle(_ style: TextStyle) -> some View {
        font(style.font).tracking(style.tracking)
    }

    /// A figure on one line: at the largest Dynamic Type sizes it shrinks, down to half, rather than wrap or
    /// truncate ("$12,420").
    func figureStyle(_ style: TextStyle) -> some View {
        textStyle(style).lineLimit(1).minimumScaleFactor(0.5)
    }
}
