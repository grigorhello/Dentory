import SwiftUI
import UIKit

/// The clinic logo's picker label: the 72 pt tap-to-upload placeholder of f3 with its picture icon, or the chosen
/// image, beside "Clinic logo" and a hint (sign-up's, or Clinic settings' "Tap to replace."). The picker that holds it
/// is labelled "Clinic logo" and gives VoiceOver the same hint (MS-149).
struct LogoPickerLabel: View {
    /// Sign-up's hint (f3). Nonisolated, so the default below keeps the initializer callable from the picker's
    /// Sendable label closure.
    nonisolated static let uploadHint = "Tap to upload. Optional, square works best."

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let logoData: Data?
    var hint = LogoPickerLabel.uploadHint

    var body: some View {
        HStack(spacing: Spacing.lg) {
            placeholder
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Clinic logo").textStyle(.bodyStrong16).foregroundStyle(Color.ms.ink)
                Text(hint)
                    .textStyle(.body14)
                    .foregroundStyle(Color.ms.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: Spacing.xs) {
            if let data = logoData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                IconView(.image, size: 24).foregroundStyle(Color.ms.textSecondary)
                // At the accessibility text sizes the word no longer fits the square ("L…"); "Clinic logo" beside it
                // says the same (MS-149).
                if !dynamicTypeSize.isAccessibilitySize {
                    Text("Logo").textStyle(.caption12).foregroundStyle(Color.ms.textSecondary)
                }
            }
        }
        .frame(width: 72, height: 72)
        .background(Color.ms.surfaceCard, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .strokeBorder(Color.ms.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }
}
