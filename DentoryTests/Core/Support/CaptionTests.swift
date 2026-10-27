import Testing
@testable import Dentory

/// Captions keep each "·" on the line of the word before it (MS-136 audit V-16), the dots inside text people typed
/// included.
struct CaptionTests {
    @Test func theSeparatorHasANoBreakSpaceBeforeTheDot() {
        #expect(Caption.separator == "\u{00A0}· ")
    }

    @Test func partsJoinWithTheSeparatorAndEmptyOnesAreLeftOut() {
        #expect(Caption.joined("54 cartridges", "Anesthetic") == "54 cartridges\u{00A0}· Anesthetic")
        #expect(Caption.joined("Oct 1", nil, "", "Sarah") == "Oct 1\u{00A0}· Sarah")
        #expect(Caption.joined(nil, "") == "")
        #expect(Caption.joined(["Received", nil, "Sarah"]) == "Received\u{00A0}· Sarah")
    }

    @Test func aLocationTypedWithDotsKeepsThemOnTheirLine() {
        #expect(
            Caption.joined("est. 54 cartridges", "Operatory 1 · Drawer A")
                == "est. 54 cartridges\u{00A0}· Operatory 1\u{00A0}· Drawer A"
        )
        #expect(Caption.attached("Operatory 1 · Drawer A") == "Operatory 1\u{00A0}· Drawer A")
    }

    @Test func textWithoutDotsIsUnchanged() {
        #expect(Caption.attached("Shelf 2") == "Shelf 2")
        #expect(Caption.attached("Undo\u{00A0}· Damaged") == "Undo\u{00A0}· Damaged")
    }
}
