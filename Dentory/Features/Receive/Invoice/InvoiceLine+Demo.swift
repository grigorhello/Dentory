import Foundation

/// The demo clinic's invoice lines (`DemoInvoiceRepository`): f23's four, as `supabase/seed-demo.sql` has them, and a
/// line settled the way the line functions settle it.
extension InvoiceLine {
    /// f23's lines: SEPTO matched to Septocaine through Patterson's alias, the endo kit a Possible match, Temp-Bond a
    /// New product and the surcharge a fee; `id(n)` names the nth.
    static func demo(numbered id: (Int) -> UUID) -> [InvoiceLine] {
        let septocaine = ProductSummary.demo[0]
        let endoKit = ProductSummary.demo[1]
        return [
            InvoiceLine(
                id: id(1), number: 1, raw: "SEPTO 4% 1:100K 50/BX", qty: 5, unit: "boxes", unitPrice: 49.8,
                lineTotal: 249, kind: .product, state: .matched, readState: .matched, readProductID: septocaine.id,
                productID: septocaine.id, productName: septocaine.name, suggestedProductID: nil,
                suggestedProductName: nil, suggestedName: "Septo 4% 1:100K", suggestedUnit: "boxes", lot: nil,
                expiryMonth: nil
            ),
            InvoiceLine(
                id: id(2), number: 2, raw: "ENDO FILE KIT 15-40 21MM", qty: 4, unit: "boxes", unitPrice: 45,
                lineTotal: 180, kind: .product, state: .possibleMatch, readState: .possibleMatch, readProductID: nil,
                productID: nil, productName: nil, suggestedProductID: endoKit.id, suggestedProductName: endoKit.name,
                suggestedName: "Endo file kit 15-40 21MM", suggestedUnit: "boxes", lot: nil, expiryMonth: nil
            ),
            InvoiceLine(
                id: id(3), number: 3, raw: "TEMPBOND NE 1PK", qty: 1, unit: "pack", unitPrice: 26.4, lineTotal: 26.4,
                kind: .product, state: .newProduct, readState: .newProduct, readProductID: nil, productID: nil,
                productName: nil, suggestedProductID: nil, suggestedProductName: nil, suggestedName: "Tempbond NE",
                suggestedUnit: "packs", lot: nil, expiryMonth: nil
            ),
            InvoiceLine(
                id: id(4), number: 4, raw: "HANDLING / FUEL SURCHARGE", qty: 1, unit: nil, unitPrice: 4.8,
                lineTotal: 4.8, kind: .fee, state: .needsReview, readState: .needsReview, readProductID: nil,
                productID: nil, productName: nil, suggestedProductID: nil, suggestedProductName: nil,
                suggestedName: "Handling / fuel surcharge", suggestedUnit: "units", lot: nil, expiryMonth: nil
            )
        ]
    }

    /// The line in another state, as a product or none.
    func settled(_ state: State, productID: UUID?, productName: String?) -> InvoiceLine {
        InvoiceLine(
            id: id, number: number, raw: raw, qty: qty, unit: unit, unitPrice: unitPrice, lineTotal: lineTotal,
            kind: kind, state: state, readState: readState, readProductID: readProductID, productID: productID,
            productName: productName, suggestedProductID: suggestedProductID,
            suggestedProductName: suggestedProductName, suggestedName: suggestedName, suggestedUnit: suggestedUnit,
            lot: lot, expiryMonth: expiryMonth
        )
    }
}
