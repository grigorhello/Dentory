import Foundation

/// Screens Activity pushes on the stack it was opened in.
enum ActivityRoute: Hashable {
    /// Product detail, for a product's alert (`activity.alert[id]`).
    case product(UUID)
}
