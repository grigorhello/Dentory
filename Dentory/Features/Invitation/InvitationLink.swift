import Foundation

/// The link in the invitation email: `https://app.dentory.ca/invite?token=…` (a universal link, MS-100 D12),
/// or the app's own `dentory://invite?token=…`, which the web fallback page and the simulator use.
nonisolated enum InvitationLink {
    static let universalHost = "app.dentory.ca"
    static let scheme = "dentory"

    /// The token of an invitation link; nil for any other URL.
    static func token(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let scheme = components.scheme?.lowercased()
        let host = components.host?.lowercased()
        let path = components.path.lowercased()
        let isUniversal = scheme == "https" && host == universalHost && path == "/invite"
        let isCustom = scheme == Self.scheme && (host == "invite" || path == "/invite")
        guard isUniversal || isCustom else { return nil }
        let token = components.queryItems?
            .first { $0.name == "token" }?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return token.isEmpty ? nil : token
    }
}
