import XCTest

/// Controls a screen keeps under its title while its list scrolls (f16-2, f09-2): where each one is, read before the
/// scroll, so a flow can check after it that every one is still there and still takes a tap.
@MainActor
struct PinnedElements {
    private struct Pinned {
        let name: String
        let element: XCUIElement
        let top: CGFloat
    }

    private let elements: [Pinned]

    init(_ elements: [(name: String, element: XCUIElement)]) {
        self.elements = elements.map { Pinned(name: $0.name, element: $0.element, top: $0.element.frame.minY) }
    }

    func assertInReach(file: StaticString = #filePath, line: UInt = #line) {
        for pinned in elements {
            XCTAssertTrue(pinned.element.isHittable, "\(pinned.name) scrolled away", file: file, line: line)
            XCTAssertEqual(
                pinned.element.frame.minY, pinned.top, accuracy: 1, "\(pinned.name) moved", file: file, line: line
            )
        }
    }
}
