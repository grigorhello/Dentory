import SwiftUI

/// A loading placeholder row: cream-sunken bars that fade in and out (no shimmer, no motion when Reduce Motion is on).
struct SkeletonRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDimmed = false
    var showsDivider = true

    var body: some View {
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
        .opacity(isDimmed ? 0.45 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isDimmed = true
            }
        }
        .accessibilityLabel("Loading")
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Spacing.xs, style: .continuous)
            .fill(Color.ms.canvasSunken)
            .frame(width: width, height: height)
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
