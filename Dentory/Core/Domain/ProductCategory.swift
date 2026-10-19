import Foundation

/// A category of the clinic (MS-100 D13): Admin picks one on the New / Edit product sheet or types a new one.
nonisolated struct ProductCategory: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let name: String
}

extension ProductCategory {
    /// The seeded list (D13), for previews and UI tests.
    nonisolated static let demo: [ProductCategory] = [
        "Anesthetic", "Restorative", "Endodontics", "Impression", "Preventive", "Surgical", "PPE",
        "Sterilization", "Disposable", "Other"
    ].enumerated().map { index, name in
        ProductCategory(
            id: UUID(uuidString: String(format: "00000000-0000-4000-8000-0000000000c%01x", index)) ?? UUID(),
            name: name
        )
    }
}
