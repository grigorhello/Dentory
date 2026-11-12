import Foundation
@testable import Dentory

/// The page check with canned answers: `problems[n]` for the n-th page checked, and a pass past the list.
final class FakeInvoicePageChecker: InvoicePageChecker, @unchecked Sendable {
    var problems: [InvoicePageProblem?] = []
    /// Runs as each page is checked, to look at the screen meanwhile.
    var whileChecking: () -> Void = {}
    private(set) var checkedPages: [Data] = []

    init(problems: [InvoicePageProblem?] = []) {
        self.problems = problems
    }

    func problem(inJPEG page: Data) async -> InvoicePageProblem? {
        whileChecking()
        let index = checkedPages.count
        checkedPages.append(page)
        return index < problems.count ? problems[index] : nil
    }
}
