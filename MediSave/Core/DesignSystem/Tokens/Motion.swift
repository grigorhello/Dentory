import SwiftUI

/// Motion (`tokens/elevation.css`): 120 to 180 ms, `cubic-bezier(.2,0,0,1)`, fades and color changes only. No bounces.
nonisolated enum Motion {
    static let fast: TimeInterval = 0.12
    static let base: TimeInterval = 0.18
    /// Half a breath of a loading placeholder; the one motion slower than an interaction.
    static let pulse: TimeInterval = 0.9

    /// The standard easing curve at any duration.
    static func ease(duration: TimeInterval) -> Animation {
        .timingCurve(0.2, 0, 0, 1, duration: duration)
    }

    /// Color and opacity changes on press.
    static var fastAnimation: Animation { ease(duration: fast) }
    /// Sheets, switches, selection changes.
    static var baseAnimation: Animation { ease(duration: base) }
}
