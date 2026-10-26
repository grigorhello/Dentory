import Foundation

/// The fields of sign-up's step 1 (f2), in the order Return moves through them.
nonisolated enum OnboardingAccountField: Hashable, Sendable {
    case name, email, password

    /// Where Return goes; the password has none, since Return there continues.
    var next: OnboardingAccountField? {
        switch self {
        case .name: .email
        case .email: .password
        case .password: nil
        }
    }
}
