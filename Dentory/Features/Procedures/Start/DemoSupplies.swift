import Foundation

/// The demo clinic's supplies as the templates use them: the Inventory demo rows plus the template products the
/// Inventory frames do not list (`supabase/seed-demo.sql`), each with its stock.
nonisolated enum DemoSupplies {
    /// Countable products of the templates that are not among `ProductSummary.demo`, offered by Add item too.
    static let extraProducts: [ProductSummary] = [
        product(1, "Needle 27g short", "Anesthetic", "needles", 40, location: "Operatory 1 · Drawer A"),
        product(2, "Paper points", "Endodontics", "packs", 5, location: "Operatory 2 · Drawer B"),
        product(3, "Prophy angle", "Preventive", "angles", 30, location: "Hygiene · Drawer A"),
        product(4, "Patient bib", "Disposable", "bibs", 180, location: "Sterilization · Shelf 1"),
        product(5, "Matrix band", "Restorative", "bands", 35, location: "Operatory 1 · Drawer B"),
        product(6, "Microbrushes", "Restorative", "brushes", 80, location: "Operatory 1 · Drawer B"),
        product(7, "Retraction cord", "Restorative", "packs", 3, location: "Operatory 1 · Drawer B"),
        product(8, "Gauze", "Surgical", "packs", 8, location: "Operatory 2 · Drawer A"),
        product(9, "Suture", "Surgical", "packs", 4, location: "Operatory 2 · Drawer A")
    ]

    /// A multi-use product's unit and stock.
    struct Bottle: Sendable {
        let unit: String
        let unopened: Decimal
        let open: Int
    }

    /// Multi-use products of the templates that are not among `ProductSummary.demo`.
    static let extraBottles: [String: Bottle] = [
        "Topical anesthetic gel": Bottle(unit: "jars", unopened: 1, open: 1),
        "Sodium hypochlorite": Bottle(unit: "bottles", unopened: 1, open: 1),
        "Prophy paste jar": Bottle(unit: "jars", unopened: 1, open: 1),
        "Fluoride varnish": Bottle(unit: "tubes", unopened: 2, open: 1),
        "Etch gel 37%": Bottle(unit: "syringes", unopened: 1, open: 1),
        "Composite A3": Bottle(unit: "syringes", unopened: 2, open: 1),
        "Impression material PVS": Bottle(unit: "cartridges", unopened: 5, open: 1),
        "Hemostatic gel": Bottle(unit: "syringes", unopened: 2, open: 0)
    ]

    /// The supply of a template: the demo product by name with the template's default quantity.
    static func item(_ name: String, _ defaultQty: Decimal) -> ProcedureTemplateItem {
        if let row = (ProductSummary.demo + extraProducts).first(where: { $0.name == name }) {
            return ProcedureTemplateItem(
                id: row.id, name: row.name, unit: row.unit, tracking: row.tracking, defaultQty: defaultQty,
                quantity: row.quantity, unopened: row.unopened, openCount: row.openCount
            )
        }
        let bottle = extraBottles[name] ?? Bottle(unit: "bottles", unopened: 0, open: 0)
        return ProcedureTemplateItem(
            id: id(for: name), name: name, unit: bottle.unit, tracking: .multiUse, defaultQty: defaultQty,
            quantity: bottle.unopened + Decimal(bottle.open), unopened: bottle.unopened, openCount: bottle.open
        )
    }

    // swiftlint:disable:next function_parameter_count
    private static func product(
        _ number: Int, _ name: String, _ category: String, _ unit: String, _ quantity: Decimal, location: String
    ) -> ProductSummary {
        ProductSummary(
            id: UUID(uuidString: String(format: "00000000-0000-4000-8000-0000000002%02x", number)) ?? UUID(),
            name: name, categoryName: category, unit: unit, tracking: .countable, location: location,
            quantity: quantity, unopened: quantity, openCount: 0, minimum: 1, status: .healthy
        )
    }

    /// A stable id per extra multi-use product, so the same bottle keeps its id across templates.
    private static func id(for name: String) -> UUID {
        let index = extraBottles.keys.sorted().firstIndex(of: name) ?? 0
        return UUID(uuidString: String(format: "00000000-0000-4000-8000-0000000002%02x", 0x80 + index)) ?? UUID()
    }
}

extension ProcedureTemplateDetail {
    /// The demo clinic's five templates (`supabase/seed-demo.sql`), with the ids of `ProcedureTemplateSummary.demo`.
    nonisolated static let demo: [ProcedureTemplateDetail] = [
        detail(0, [
            ("Septocaine 4% 1:100,000", 2), ("Needle 27g short", 1), ("Nitrile gloves M", 2),
            ("Rubber dam latex-free", 1), ("Endo file kit #15-40", 1), ("Gutta percha F2", 1), ("Paper points", 1),
            ("Suction tips", 1), ("Topical anesthetic gel", 0), ("Sodium hypochlorite", 0), ("Root canal sealer", 0),
            ("Surface disinfectant", 0)
        ]),
        detail(1, [
            ("Prophy angle", 1), ("Nitrile gloves M", 2), ("Suction tips", 1), ("Patient bib", 1),
            ("Prophy paste jar", 0), ("Fluoride varnish", 0), ("Surface disinfectant", 0)
        ]),
        detail(2, [
            ("Septocaine 4% 1:100,000", 1), ("Needle 27g short", 1), ("Nitrile gloves M", 2), ("Suction tips", 1),
            ("Matrix band", 1), ("Microbrushes", 2), ("Topical anesthetic gel", 0), ("Etch gel 37%", 0),
            ("Bonding agent", 0), ("Composite A2", 0), ("Composite A3", 0), ("Surface disinfectant", 0)
        ]),
        detail(3, [
            ("Septocaine 4% 1:100,000", 2), ("Needle 27g short", 1), ("Nitrile gloves M", 2), ("Suction tips", 1),
            ("Retraction cord", 1), ("Topical anesthetic gel", 0), ("Impression material PVS", 0),
            ("Alginate impression", 0), ("Temporary cement", 0), ("Surface disinfectant", 0)
        ]),
        detail(4, [
            ("Septocaine 4% 1:100,000", 2), ("Needle 27g short", 1), ("Nitrile gloves M", 2), ("Gauze", 4),
            ("Suture", 1), ("Topical anesthetic gel", 0), ("Hemostatic gel", 0), ("Surface disinfectant", 0)
        ])
    ]

    private nonisolated static func detail(_ index: Int, _ items: [(String, Decimal)]) -> ProcedureTemplateDetail {
        let summary = ProcedureTemplateSummary.demo[index]
        return ProcedureTemplateDetail(
            id: summary.id, name: summary.name, items: items.map { DemoSupplies.item($0.0, $0.1) }
        )
    }
}
