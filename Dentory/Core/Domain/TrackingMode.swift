/// How a product is counted (PRD §4): by unit, or as bottles, syringes and kits that are opened one at a time.
nonisolated enum TrackingMode: String, Codable, Sendable {
    case countable
    case multiUse = "multi_use"
}
