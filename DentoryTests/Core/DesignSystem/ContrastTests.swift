import Testing
import UIKit
@testable import Dentory

/// PRD §7 and MS-149: every text color the design system draws on a surface reaches 4.5:1 (WCAG's relative
/// luminance), the status colors on their own soft tints included.
struct ContrastTests {
    /// A text token and the surface token the components draw it on.
    private static let pairs: [(text: String, surface: String)] = [
        ("ink", "canvas"), ("ink", "canvasSoft"), ("ink", "canvasSunken"),
        ("body", "canvas"), ("body", "canvasSoft"), ("body", "canvasSunken"),
        ("bodyMid", "canvas"), ("bodyMid", "canvasSoft"),
        ("primary", "canvas"), ("primary", "canvasSoft"), ("primary", "primarySoft"),
        ("success", "successSoft"), ("success", "canvas"), ("success", "canvasSoft"),
        ("warning", "warningSoft"), ("warning", "canvas"), ("warning", "canvasSoft"),
        ("danger", "dangerSoft"), ("danger", "canvas"), ("danger", "canvasSoft"),
        ("info", "infoSoft"),
        ("onPrimary", "primary"), ("onPrimary", "ink"), ("onPrimary", "danger"),
        ("canvasSoft", "ink"), ("mute", "ink")
    ]

    @Test func everyTextColorReachesFourAndAHalfToOne() throws {
        for pair in Self.pairs {
            let ratio = try contrast(of: pair.text, on: pair.surface)
            #expect(ratio >= 4.5, "\(pair.text) on \(pair.surface) is only \(ratio):1")
        }
    }

    private func contrast(of text: String, on surface: String) throws -> Double {
        let first = try luminance(of: text)
        let second = try luminance(of: surface)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private func luminance(of name: String) throws -> Double {
        let color = try #require(UIColor(named: "Colors/\(name)"), "\(name) is missing")
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        #expect(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha), "\(name) is not an RGB color")
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private func linear(_ component: CGFloat) -> Double {
        let value = Double(component)
        return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
}
