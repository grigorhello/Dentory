import Foundation
@testable import Dentory

/// Answers `summary`, `invoices` and the billing emails, records each save, and throws `failure` or `saveFailure`.
final class FakeBillingRepository: BillingRepository, @unchecked Sendable {
    var summary: BillingSummary
    var invoices: [BillingInvoice] = []
    var emails = ["owner@smiledental.ca"]
    var failure: Error?
    var saveFailure: Error?
    private(set) var saves: [[String]] = []

    init(_ summary: BillingSummary = .demo(hasCard: true)) {
        self.summary = summary
    }

    func summary(clinicID: UUID) async throws -> BillingSummary {
        if let failure { throw failure }
        return summary
    }

    func invoices(clinicID: UUID) async throws -> [BillingInvoice] {
        if let failure { throw failure }
        return invoices
    }

    func billingEmails(clinicID: UUID) async throws -> [String] {
        if let failure { throw failure }
        return emails
    }

    func saveBillingEmails(clinicID: UUID, extra: [String]) async throws -> [String] {
        if let saveFailure { throw saveFailure }
        saves.append(extra)
        emails = [emails[0]] + extra
        return emails
    }
}
