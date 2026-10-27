import Testing
@testable import Dentory

/// A new password needs 8 characters; the hint says so only while 1 to 7 are typed.
struct NewPasswordTests {
    @Test func eightCharactersAreEnough() {
        #expect(!NewPassword.isLongEnough("smiledn"))
        #expect(NewPassword.isLongEnough("smiledne"))
    }

    @Test func theHintShowsOnlyWhileThePasswordIsTooShort() {
        #expect(NewPassword.hint(for: "") == nil)
        #expect(NewPassword.hint(for: "s") == "At least 8 characters")
        #expect(NewPassword.hint(for: "smiledn") == "At least 8 characters")
        #expect(NewPassword.hint(for: "smiledne") == nil)
    }
}
