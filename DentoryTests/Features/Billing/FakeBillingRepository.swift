import Foundation
@testable import Dentory

/// Answers `summary`, or throws `failure`.
final class FakeBillingRepository: BillingRepository, @unchecked Sendable {
    var summary: BillingSummary
    var failure: Error?

    init(_ summary: BillingSummary) {
        self.summary = summary
    }

    func summary(clinicID: UUID) async throws -> BillingSummary {
        if let failure { throw failure }
        return summary
    }
}
