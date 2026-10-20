import Foundation

/// Where Account leads on the Home stack; each screen arrives with its own ticket.
enum AccountRoute: Hashable {
    /// MS-138.
    case team
    /// MS-139, Admin only.
    case settings
    /// MS-140, Admin only.
    case billing
}
