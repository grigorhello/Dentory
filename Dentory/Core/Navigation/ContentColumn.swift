import SwiftUI

extension View {
    /// The content column of every screen (PRD §7): 720 pt at most inside the 20 pt page gutter, centred on a wide
    /// screen, as f36 to f38 draw it on an iPad. On a phone the gutter alone sets the width.
    func contentColumn(alignment: Alignment = .leading) -> some View {
        frame(maxWidth: PageLayout.contentMaxWidth, alignment: alignment)
            .padding(.horizontal, Spacing.page)
            .frame(maxWidth: .infinity)
    }
}
