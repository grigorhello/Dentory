import SwiftUI

/// Badge tints. Status is always text plus a soft tint, never color alone and never a large fill.
nonisolated enum StatusTone: CaseIterable, Sendable {
    case neutral, success, warning, danger, info

    var foreground: Color {
        switch self {
        case .neutral: .ms.ink
        case .success: .ms.success
        case .warning: .ms.warning
        case .danger: .ms.danger
        case .info: .ms.info
        }
    }

    var background: Color {
        switch self {
        case .neutral: .ms.canvasSunken
        case .success: .ms.successSoft
        case .warning: .ms.warningSoft
        case .danger: .ms.dangerSoft
        case .info: .ms.infoSoft
        }
    }
}

/// The status words of PRD §7 with their default tone. Pass `tone:` to `StatusBadge` where a frame shows another tint.
nonisolated enum StatusBadgeKind: String, CaseIterable, Sendable {
    case healthy = "Healthy"
    case low = "Low"
    case outOfStock = "Out of stock"
    case expiring = "Expiring"
    case missingExpiry = "Missing expiry"
    case matched = "Matched"
    case possibleMatch = "Possible match"
    case newProduct = "New product"
    case needsReview = "Needs review"
    case created = "Created"
    case skipped = "Skipped"

    var tone: StatusTone {
        switch self {
        case .healthy, .matched, .created: .success
        case .low, .expiring, .possibleMatch: .warning
        case .outOfStock, .needsReview: .danger
        case .missingExpiry, .newProduct: .info
        case .skipped: .neutral
        }
    }
}

nonisolated enum StatusBadgeSize: Sendable {
    case small, medium
}

/// Pill with a status word (`StatusBadge(.low)`) or any short text with a tone (`StatusBadge("in 60 days", tone: .warning)`).
struct StatusBadge: View {
    let text: String
    let tone: StatusTone
    var size: StatusBadgeSize = .medium
    var showsDot = false

    init(
        _ kind: StatusBadgeKind,
        tone: StatusTone? = nil,
        size: StatusBadgeSize = .medium,
        showsDot: Bool = false
    ) {
        self.init(kind.rawValue, tone: tone ?? kind.tone, size: size, showsDot: showsDot)
    }

    init(_ text: String, tone: StatusTone, size: StatusBadgeSize = .medium, showsDot: Bool = false) {
        self.text = text
        self.tone = tone
        self.size = size
        self.showsDot = showsDot
    }

    var body: some View {
        HStack(spacing: 6) {
            if showsDot {
                Circle().fill(tone.foreground).frame(width: 6, height: 6)
            }
            Text(text)
        }
        .textStyle(size == .small ? .micro12 : .bodyStrong14)
        .foregroundStyle(tone.foreground)
        .lineLimit(1)
        .padding(.vertical, size == .small ? Spacing.xxs : Spacing.xs)
        .padding(.horizontal, size == .small ? Spacing.sm : Spacing.md)
        .background(tone.background, in: Capsule())
    }
}

#Preview("Badges") {
    VStack(alignment: .leading, spacing: Spacing.md) {
        ForEach(StatusBadgeKind.allCases, id: \.self) { kind in
            HStack {
                StatusBadge(kind)
                StatusBadge(kind, size: .small, showsDot: true)
            }
        }
        StatusBadge(.healthy, tone: .neutral, showsDot: true)
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
