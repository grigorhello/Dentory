import Foundation

/// What a push opens (MS-144), as the alert's row in Activity does (MS-133): the product of an out-of-stock or expiring
/// alert, or Receive delivery for a delivery ready to review. The server sends `dentory://product/<id>` and
/// `dentory://delivery`; the same paths on `https://app.dentory.ca` read the same.
nonisolated enum NotificationLink: Equatable, Sendable {
    case product(UUID)
    case delivery

    private static let scheme = "dentory"
    private static let universalHost = "app.dentory.ca"

    /// Nil for any other URL, such as an invitation or a password reset link.
    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let scheme = components.scheme?.lowercased()
        let host = components.host?.lowercased()
        var parts = components.path.split(separator: "/").map { $0.lowercased() }
        if scheme == Self.scheme, let host {
            parts.insert(host, at: 0)
        } else if scheme != "https" || host != Self.universalHost {
            return nil
        }
        switch (parts.first, parts.count) {
        case ("product", 2):
            guard let id = UUID(uuidString: parts[1]) else { return nil }
            self = .product(id)
        case ("delivery", 1):
            self = .delivery
        default:
            return nil
        }
    }
}
