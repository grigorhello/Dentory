/// Names as the screens show them: "Sarah" for "Sarah Mitchell" in history rows and cards.
nonisolated enum PersonName {
    /// The first word of a full name; empty for an empty name.
    static func first(of fullName: String) -> String {
        String(fullName.split(separator: " ").first ?? "")
    }
}
