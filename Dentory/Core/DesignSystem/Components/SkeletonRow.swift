import SwiftUI

/// A loading placeholder row: cream-sunken bars that breathe between full and dim opacity.
/// The pulse is a function of time drawn by a `TimelineView`, not a SwiftUI animation, so it can never
/// leak into the layout around it. It holds still when Reduce Motion is on.
struct SkeletonRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var showsDivider = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            row.opacity(reduceMotion ? 1 : Self.opacity(at: context.date))
        }
        .accessibilityLabel("Loading")
    }

    private var row: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    bar(width: 160, height: 14)
                    bar(width: 100, height: 12)
                }
                Spacer()
                bar(width: 40, height: 14)
            }
            .padding(.vertical, Spacing.md + Spacing.xxs)
            .frame(minHeight: ControlHeight.hitTarget)
            if showsDivider {
                ListDivider()
            }
        }
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Spacing.xs, style: .continuous)
            .fill(Color.ms.canvasSunken)
            .frame(width: width, height: height)
    }

    /// 1 at the start of each breath, 0.45 halfway through, back to 1 after two `Motion.pulse` halves.
    nonisolated static func opacity(at date: Date) -> Double {
        let breath = Motion.pulse * 2
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: breath) / breath
        let wave = (1 + cos(phase * 2 * .pi)) / 2
        return 0.45 + 0.55 * wave
    }
}

#Preview("Skeleton") {
    ListCard {
        SkeletonRow()
        SkeletonRow()
        SkeletonRow(showsDivider: false)
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
