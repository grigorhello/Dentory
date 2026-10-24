import Foundation

/// The link in the password reset email (MS-113, MS-100 D12): `https://app.dentory.ca/reset-password?token_hash=…`
/// (a universal link), or the app's own `dentory://reset-password?token_hash=…`, which the local stack's emails,
/// the web fallback page and the simulator use. The email template builds it from the redirect the app sends
/// (`supabase/templates/recovery.html`).
nonisolated enum PasswordResetLink {
    static let universalHost = "app.dentory.ca"
    static let scheme = "dentory"
    static let path = "reset-password"
    /// The Info.plist key the xcconfig fills: `dentory://reset-password` for Debug, the universal link for Release.
    static let infoKey = "PASSWORD_RESET_URL"
    static let universalRedirect = URL(string: "https://\(universalHost)/\(path)")

    /// The token hash of a reset link; nil for any other URL.
    static func tokenHash(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let scheme = components.scheme?.lowercased()
        let host = components.host?.lowercased()
        let linkPath = components.path.lowercased()
        let isUniversal = scheme == "https" && host == universalHost && linkPath == "/\(path)"
        let isCustom = scheme == Self.scheme && (host == path || linkPath == "/\(path)")
        guard isUniversal || isCustom else { return nil }
        let tokenHash = components.queryItems?
            .first { $0.name == "token_hash" }?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return tokenHash.isEmpty ? nil : tokenHash
    }

    /// Where the reset email points, from the build's Info.plist; the universal link when the key is missing.
    static func redirectURL(bundle: Bundle = .main) -> URL? {
        if let value = bundle.object(forInfoDictionaryKey: infoKey) as? String,
           !value.isEmpty,
           let url = URL(string: value) {
            return url
        }
        return universalRedirect
    }
}

/// Sign in pushes Reset password with what is typed in its email field (`signin.forgot`).
nonisolated struct PasswordResetRoute: Hashable, Sendable {
    let email: String
}
