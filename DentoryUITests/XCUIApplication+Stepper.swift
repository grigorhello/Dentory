import XCTest

extension XCUIApplication {
    /// The number element of a quantity stepper (`procDetail.item[…]` gives `procDetail.item[…].value`): adjustable for
    /// VoiceOver, so it is looked up whatever element type XCTest reports for it.
    @MainActor
    func stepperValue(_ identifier: String) -> XCUIElement {
        descendants(matching: .any)["\(identifier).value"].firstMatch
    }

    /// The number a quantity stepper shows. VoiceOver reads it as the element's value, named by the product, with
    /// ", changed" while it differs from its reference, so the number is the value up to the first comma
    /// (`DentoryUITests` and `DentoryE2ETests` share this file).
    @MainActor
    func stepperNumber(_ identifier: String) -> String {
        let value = stepperValue(identifier).value as? String ?? ""
        return value.components(separatedBy: ",").first ?? value
    }
}
