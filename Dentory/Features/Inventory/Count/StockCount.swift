import Foundation

/// One Count stock session (PRD §6.4, MS-121): the quantity counted for each product the person touched.
/// A row counts unopened stock only, so a multi-use product leaves its open bottles out, which is also what
/// `stock_count_apply` compares the count with. Kept as a draft on the device until applied or discarded.
nonisolated struct StockCount: Codable, Equatable, Sendable {
    let clinicID: UUID
    let userID: UUID
    /// When Count stock was tapped; Apply count reports the seconds since (MS-147).
    let startedAt: Date?
    /// Touched rows only; a row nobody touched stays at its estimate and is not sent.
    private(set) var counted: [UUID: Int]

    init(clinicID: UUID, userID: UUID, startedAt: Date? = nil, counted: [UUID: Int] = [:]) {
        self.clinicID = clinicID
        self.userID = userID
        self.startedAt = startedAt
        self.counted = counted
    }

    /// From Count stock to `date`, in whole seconds; 0 when the start is unknown.
    func seconds(until date: Date) -> Int {
        guard let startedAt else { return 0 }
        return max(Int(date.timeIntervalSince(startedAt).rounded()), 0)
    }

    /// What the row is compared with: the unopened quantity, which for a countable product is all of it.
    static func estimate(of product: ProductSummary) -> Decimal {
        product.unopened
    }

    /// The stepper's value: the count once the row was touched, else the estimate as a whole number. A
    /// physical count is never negative, so a negative estimate starts the row at 0.
    func value(for product: ProductSummary) -> Int {
        counted[product.id] ?? Self.wholeNumber(Self.estimate(of: product))
    }

    /// True when the row was counted and the count differs from the estimate: a correction to apply.
    func isCorrection(_ product: ProductSummary) -> Bool {
        guard let value = counted[product.id] else { return false }
        return Decimal(value) != Self.estimate(of: product)
    }

    /// The corrected products, in the order given.
    func corrections(among products: [ProductSummary]) -> [ProductSummary] {
        products.filter(isCorrection)
    }

    mutating func set(_ value: Int, for product: ProductSummary) {
        counted[product.id] = max(value, 0)
    }

    /// Undo on a review row: the row goes back to its estimate.
    mutating func reset(_ productID: UUID) {
        counted[productID] = nil
    }

    private static func wholeNumber(_ value: Decimal) -> Int {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        return max(NSDecimalNumber(decimal: rounded).intValue, 0)
    }

    // MARK: - Draft file

    // The draft holds the counts as lines, so the file stays readable JSON.
    private enum CodingKeys: String, CodingKey {
        case clinicID, userID, startedAt, lines
    }

    private struct Line: Codable {
        let productID: UUID
        let counted: Int
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clinicID = try container.decode(UUID.self, forKey: .clinicID)
        userID = try container.decode(UUID.self, forKey: .userID)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        let lines = try container.decode([Line].self, forKey: .lines)
        counted = Dictionary(lines.map { ($0.productID, $0.counted) }, uniquingKeysWith: { _, last in last })
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(clinicID, forKey: .clinicID)
        try container.encode(userID, forKey: .userID)
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        let lines = counted
            .map { Line(productID: $0.key, counted: $0.value) }
            .sorted { $0.productID.uuidString < $1.productID.uuidString }
        try container.encode(lines, forKey: .lines)
    }
}
