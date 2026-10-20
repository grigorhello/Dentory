import Foundation
@testable import Dentory

/// Answers `summaries` in turn, the last one again once they run out, and the payment page `page`.
final class FakeBillingRepository: BillingRepository, @unchecked Sendable {
    var summaries: [BillingSummary]
    var failure: Error?
    var page: Result<URL?, Error> = .success(URL(string: "https://checkout.stripe.com/c/pay/cs_test_1"))
    private(set) var loads = 0
    private(set) var pageRequests: [Bool] = []

    init(_ summaries: [BillingSummary]) {
        self.summaries = summaries
    }

    func summary(clinicID: UUID) async throws -> BillingSummary {
        if let failure { throw failure }
        loads += 1
        return summaries.count > 1 ? summaries.removeFirst() : summaries[0]
    }

    func paymentPage(clinicID: UUID, hasSubscription: Bool) async throws -> URL? {
        pageRequests.append(hasSubscription)
        return try page.get()
    }
}
