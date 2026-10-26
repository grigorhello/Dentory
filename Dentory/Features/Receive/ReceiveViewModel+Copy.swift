import Foundation

/// What Receive delivery says (f22, PRD §6.5, Appendix B `receive`): the line under the options, each row's caption
/// and quantity, and the toasts of a capture that cannot go on. The state and the intents are in
/// `ReceiveViewModel.swift`.
extension ReceiveViewModel {
    static let reassurance = "Nothing affects inventory until you confirm."
    static let continueTitle = "Continue reviewing"

    /// "Patterson · 8:55 AM" today, "Invoice · Yesterday" while the supplier is not read yet, "Patterson · Sep 28".
    func invoiceLine(for invoice: PendingInvoice) -> String {
        let supplier = invoice.supplier.flatMap { $0.isEmpty ? nil : $0 } ?? "Invoice"
        let when = switch formatters.daysSince(invoice.createdAt) {
        case ...0: formatters.time(invoice.createdAt)
        case 1: "Yesterday"
        default: formatters.monthDay(invoice.createdAt)
        }
        return "\(supplier) · \(when)"
    }

    /// "Patterson · ordered Oct 1", or "Ordered Oct 1" for a product without a supplier.
    func waitingLine(for item: WaitingItem) -> String {
        let date = formatters.monthDay(item.orderedAt)
        guard let supplier = item.supplier, !supplier.isEmpty else { return "Ordered \(date)" }
        return "\(supplier) · ordered \(date)"
    }

    /// The quantity ordered, in the product's counted unit, as To buy shows it ("60").
    func quantityText(for item: WaitingItem) -> String {
        formatters.number(item.quantity)
    }

    /// "60 needles ordered", for VoiceOver, which reads the bare figure without its unit.
    func spokenQuantity(for item: WaitingItem) -> String {
        "\(formatters.quantity(item.quantity, unit: item.unit)) ordered"
    }

    /// A capture that cannot go on, as a toast: the size limit, or pages that could not be read.
    static func message(for error: InvoiceCaptureError) -> Message {
        switch error {
        case .tooLarge(.file):
            Message(title: "This file is over 20 MB", detail: "Choose a smaller PDF or image.")
        case .tooLarge(.camera):
            Message(title: "The pages are over 20 MB", detail: "Use fewer pages.")
        case .tooManyPages:
            Message(title: "Up to 20 pages per invoice", detail: "Scan or choose fewer pages.")
        case .unreadable(.file):
            Message(title: "Couldn't open this file", detail: "Try again, or choose another one.")
        case .unreadable(.camera):
            Message(title: "Couldn't read the pages", detail: "Try again.")
        case .scannerFailed:
            Message(title: "Couldn't scan", detail: "Upload a PDF or image instead.")
        }
    }
}
