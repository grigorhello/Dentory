import Foundation

/// Screens Activity pushes on the stack it was opened in.
enum ActivityRoute: Hashable {
    /// Product detail, for a product's alert (`activity.alert[id]`).
    case product(UUID)
    /// Review invoice for the invoice a receipt in History came from, an admin's (MS-131): read-only once received.
    case invoice(UUID)
}
