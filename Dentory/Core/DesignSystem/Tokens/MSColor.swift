import SwiftUI

/// The Dentory color tokens (`design/.../tokens/colors.css`), one asset-catalog color set per token
/// under `Assets.xcassets/Colors` so each can gain a dark variant later. V1.1 is light only: the app opts out of Dark
/// Mode (`UIUserInterfaceStyle` Light in `project.yml`), so system controls draw light on these colors too.
///
/// Usage: `Color.ms.primary`, `Color.ms.textSecondary`.
nonisolated struct MSColorPalette: Sendable {
    // Brand accent: clinical blue, the one chromatic accent.
    let primary = Color.token("primary")
    let primaryHover = Color.token("primaryHover")
    let primaryActive = Color.token("primaryActive")
    let primarySoft = Color.token("primarySoft")
    let onPrimary = Color.token("onPrimary")

    // Warm ink ladder (coffee, never cool grey).
    let ink = Color.token("ink")
    let inkSoft = Color.token("inkSoft")
    let inkMid = Color.token("inkMid")
    let body = Color.token("body")
    let bodyMid = Color.token("bodyMid")
    let mute = Color.token("mute")
    let line = Color.token("line")

    // Warm surfaces.
    let canvas = Color.token("canvas")
    let canvasSoft = Color.token("canvasSoft")
    let canvasSunken = Color.token("canvasSunken")

    // Inventory semantics: always used as text plus a soft tint, never a large fill.
    let success = Color.token("success")
    let successSoft = Color.token("successSoft")
    let warning = Color.token("warning")
    let warningSoft = Color.token("warningSoft")
    let danger = Color.token("danger")
    let dangerSoft = Color.token("dangerSoft")
    let info = Color.token("info")
    let infoSoft = Color.token("infoSoft")

    // Pressed states of the danger button (the web bundle hard-codes these two).
    let dangerHover = Color.token("dangerHover")
    let dangerActive = Color.token("dangerActive")

    // Semantic aliases.
    var textHeading: Color { ink }
    var textBody: Color { body }
    var textSecondary: Color { bodyMid }
    var textDisabled: Color { mute }
    var textOnDark: Color { canvasSoft }
    var textLink: Color { primary }
    var surfacePage: Color { canvas }
    var surfaceCard: Color { canvasSoft }
    var surfaceRaised: Color { canvas }
    var surfaceDark: Color { ink }
    var borderDefault: Color { line }
    var borderStrong: Color { ink }
    var borderFocus: Color { primary }

    /// The dialog and sheet scrim, the only transparency in the system.
    var scrim: Color { ink.opacity(0.4) }
}

extension Color {
    /// The Dentory palette. The only place colors come from outside `Core/DesignSystem`.
    nonisolated static let ms = MSColorPalette()

    nonisolated fileprivate static func token(_ name: String) -> Color {
        Color("Colors/\(name)", bundle: .main)
    }
}
