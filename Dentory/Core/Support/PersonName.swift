/// Names as the screens show them: "Sarah" for "Sarah Mitchell" in history rows and cards.
nonisolated enum PersonName {
    /// The first word of a full name, except that a doctor goes by title and last name, as the prototype calls
    /// Dr. Daniel Kim "Dr. Kim"; empty for an empty name.
    static func first(of fullName: String) -> String {
        let words = fullName.split(separator: " ")
        guard let first = words.first else { return "" }
        guard ["dr", "dr."].contains(first.lowercased()), words.count > 1, let last = words.last else {
            return String(first)
        }
        return "Dr. \(last)"
    }
}
