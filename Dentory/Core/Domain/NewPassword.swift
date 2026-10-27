import Foundation

/// The rule every new password follows: admin sign-up (f2), Join (f5) and Set a new password ask for at least 8
/// characters, the auth minimum. The field says so as its placeholder (f2); once 1 to 7 characters are typed it says so
/// under the field too, so a Continue that stays disabled has its reason on screen.
nonisolated enum NewPassword {
    static let minimumLength = 8
    /// The placeholder, and the hint under a password that is still too short.
    static let requirement = "At least 8 characters"

    static func isLongEnough(_ password: String) -> Bool {
        password.count >= minimumLength
    }

    /// `requirement` while 1 to 7 characters are typed; nothing for an empty field or a long enough password.
    static func hint(for password: String) -> String? {
        (1..<minimumLength).contains(password.count) ? requirement : nil
    }
}
