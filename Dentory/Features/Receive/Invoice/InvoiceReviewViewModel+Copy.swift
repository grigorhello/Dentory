import Foundation

/// What Review invoice's lines say (f23, PRD §6.5, Appendix B `invoice`, the ticket's wording): each state's line and
/// question, the amounts as read, the two choices a line waits for, the Lot and Expiry inputs, and the summary over
/// Confirm & receive. The state and the intents are in `InvoiceReviewViewModel.swift`.
extension InvoiceReviewViewModel {
    static let expiryLabel = "Expiry"
    /// Short enough for half a line on an iPhone, as the frame's empty month input.
    static let expiryPlaceholder = "Month"
    static let lotLabel = "Lot (optional)"
    static let lotPlaceholder = "Free text"
    static let noExpiryHint = "No expiry → listed under Missing expiry."
    static let confirmTitle = "Confirm & receive"
    static let undoTitle = "Undo"
    /// Until MS-131 receives the delivery.
    static let confirmArrivesLater = "Receiving the delivery arrives with its own ticket."
    /// What a lot keeps (`invoice_line_batch`).
    static let lotLength = 60

    /// The line under the raw text: the product, or what the line needs.
    func headline(for line: InvoiceLine) -> String {
        switch line.state {
        case .matched: line.productName ?? line.raw
        case .possibleMatch: line.suggestedProductName.map { "Is this \($0)?" } ?? "Not in your inventory"
        case .newProduct: "Not in your inventory"
        case .needsReview: "Looks like a fee, not a product"
        case .created: "\(line.productName ?? line.suggestedName ?? line.raw) · new product"
        case .skipped: "Ignored · not added to inventory"
        }
    }

    /// The sentence over the choices of a line waiting for one.
    func question(for line: InvoiceLine) -> String? {
        switch line.state {
        case .possibleMatch: "Name differs slightly from your product."
        case .newProduct: "No product with this name exists yet."
        case .needsReview: "Fees and surcharges should not go into stock."
        case .matched, .created, .skipped: nil
        }
    }

    /// "5 boxes · $49.80": the quantity in the unit it was read in and the price of one, in the invoice's currency;
    /// "1 · $4.80" for a fee without a unit. A part the invoice does not show is left out.
    func amount(for line: InvoiceLine) -> String? {
        let quantity = line.qty.map { qty in
            guard let unit = line.unit, !unit.isEmpty else { return formatters.number(qty) }
            let word = qty == 1 ? ClinicFormatters.singular(of: unit) : ClinicFormatters.plural(of: unit)
            return "\(formatters.number(qty)) \(word)"
        }
        let price = (line.unitPrice ?? Self.unitPrice(of: line)).map(formatters.unitCost)
        let parts = [quantity, price].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The two buttons of a line waiting for a choice, `.a` then `.b`: Yes, match and No, create new; Add new and Pick
    /// existing; Ignore and Pick product. None for a resolved line.
    func choices(for line: InvoiceLine) -> (first: Choice, second: Choice)? {
        switch line.state {
        case .possibleMatch: (.yesMatch, .createNew)
        case .newProduct: (.addNew, .pickExisting)
        case .needsReview: (.ignore, .pickProduct)
        case .matched, .created, .skipped: nil
        }
    }

    static func title(of choice: Choice) -> String {
        switch choice {
        case .yesMatch: "Yes, match"
        case .createNew: "No, create new"
        case .addNew: "Add new"
        case .pickExisting: "Pick existing"
        case .ignore: "Ignore"
        case .pickProduct: "Pick product"
        }
    }

    /// The primary button of a pair; Ignore is tertiary like its partner (f23).
    static func isPrimary(_ choice: Choice) -> Bool {
        choice == .yesMatch || choice == .addNew
    }

    /// "3 of 4 lines will increase inventory." once every line is resolved, else "Resolve every line to continue."
    var summary: String {
        guard allResolved else { return "Resolve every line to continue." }
        let receiving = lines.filter(\.increasesInventory).count
        return "\(receiving) of \(lines.count) \(lines.count == 1 ? "line" : "lines") will increase inventory."
    }

    /// The month the wheels open on while none is chosen: this month in the clinic's time zone.
    var openingMonth: YearMonth { YearMonth(day: formatters.thisMonth) }

    /// Three years back to ten ahead, as Add expiry offers them, stretched to the line's month.
    func expiryYears(for line: InvoiceLine) -> ClosedRange<Int> {
        formatters.expiryYears(including: line.expiryMonth)
    }

    /// "Mar 2027".
    func monthTitle(_ month: YearMonth) -> String {
        formatters.shortMonth(CalendarDay(yearMonth: month))
    }

    /// The toast's line once New product created the product for a line: "Tempbond NE · add expiry on the line".
    static func createdDetail(_ line: InvoiceLine) -> String {
        "\(line.productName ?? line.suggestedName ?? line.raw) · add expiry on the line"
    }

    /// The price of one when the invoice gives only the line's amount.
    private static func unitPrice(of line: InvoiceLine) -> Decimal? {
        guard let total = line.lineTotal, let qty = line.qty, qty != 0 else { return nil }
        return total / qty
    }
}
