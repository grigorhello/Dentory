import Foundation

/// The demo clinic's team for previews and UI tests: Sarah, Daniel and Michael (f29, f31); Priya is still invited.
/// An export starts at once and goes to Sarah.
struct DemoAccountRepository: AccountRepository {
    var teamSize = 3
    var exportEmail = "sarah@smiledental.ca"

    func teamSize(clinicID: UUID) async throws -> Int {
        teamSize
    }

    func startExport(clinicID: UUID) async throws -> String {
        exportEmail
    }
}
