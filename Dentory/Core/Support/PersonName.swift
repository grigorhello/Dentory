/// Names as the screens show them: "Sarah" for "Sarah Mitchell" in history rows and cards.
nonisolated enum PersonName {
    /// The first word of a full name; empty for an empty name.
    static func first(of fullName: String) -> String {
        String(fullName.split(separator: " ").first ?? "")
    }

    /// "SM" for "Sarah Mitchell", "DK" for "Dr. Daniel Kim": the first letters of the first and last names, a "Dr."
    /// left out (f29, f31); one letter for a single name, empty for an empty one.
    static func initials(of fullName: String) -> String {
        let words = fullName.split(separator: " ").filter { !["dr", "dr."].contains($0.lowercased()) }
        guard let first = words.first?.first else { return "" }
        guard words.count > 1, let last = words.last?.first else { return String(first).uppercased() }
        return "\(first)\(last)".uppercased()
    }
}
