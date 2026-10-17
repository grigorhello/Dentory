import Testing
import UIKit
@testable import Dentory

/// The tokens point at bundled resources; these fail loudly when a font or asset goes missing.
struct DesignSystemAssetTests {
    @Test func bundledFontsAreRegistered() {
        for name in FontName.all {
            #expect(UIFont(name: name, size: 14) != nil, "\(name) is not registered")
        }
    }

    @Test func everyIconHasAnImage() {
        for icon in Icon.allCases {
            #expect(UIImage(named: "Icons/\(icon.rawValue)") != nil, "\(icon.rawValue) is missing")
        }
    }

    @Test func everyColorTokenHasAnAsset() {
        let names = [
            "primary", "primaryHover", "primaryActive", "primarySoft", "onPrimary",
            "ink", "inkSoft", "inkMid", "body", "bodyMid", "mute", "line",
            "canvas", "canvasSoft", "canvasSunken",
            "success", "successSoft", "warning", "warningSoft", "danger", "dangerSoft", "info", "infoSoft",
            "dangerHover", "dangerActive"
        ]
        for name in names {
            #expect(UIColor(named: "Colors/\(name)") != nil, "\(name) is missing")
        }
    }
}
