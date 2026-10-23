import SwiftUI
import UIKit

/// The clinic logo's picker label: the 72 pt tap-to-upload placeholder of f3, or the chosen image, beside "Clinic logo"
/// and a hint (sign-up's, or Clinic settings' "Tap to replace.").
struct LogoPickerLabel: View {
    let logoData: Data?
    var hint = "Tap to upload. Optional, square works best."

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
                IconView(.camera, size: 24).foregroundStyle(Color.ms.textSecondary)
                Text("Logo").textStyle(.caption12).foregroundStyle(Color.ms.textSecondary)
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
