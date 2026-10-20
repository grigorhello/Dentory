import Foundation

/// The demo clinic's team for previews and UI tests: Sarah, Daniel and Michael (f29, f31); Priya is still invited.
struct DemoAccountRepository: AccountRepository {
    var teamSize = 3

    func teamSize(clinicID: UUID) async throws -> Int {
        teamSize
    }
}
