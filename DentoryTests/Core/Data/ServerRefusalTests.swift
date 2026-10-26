import Foundation
import Supabase
import Testing
@testable import Dentory

/// The server's refusal sentences in the app's copy (PRD §7, MS-136 audit C-01).
struct ServerRefusalTests {
    @Test(arguments: [
        ("the product is archived", "This product was deleted."),
        ("unknown product", "This product no longer exists."),
        ("unknown batch", "This batch no longer exists."),
        ("the procedure was already cancelled", "This procedure was already cancelled."),
        ("a note is required to cancel", "A note is required to cancel."),
        ("the disposed quantity must be between 0 and what the batch holds", "Dispose no more than the batch holds."),
        ("already undone", "This change was already undone."),
        ("the undo window has passed", "The 10 seconds to undo have passed."),
        ("Enter a valid email", "Enter a valid email address."),
        ("Keep the clinic name to 120 characters", "Use 120 characters or fewer for the clinic name."),
        ("This delivery was already received", "This delivery was already received."),
        ("an idempotency key is required", "Couldn't save. Try again.")
    ])
    func aListedSentenceReadsAsHouseCopy(_ server: String, _ shown: String) {
        #expect(ServerRefusal.sentence(for: server) == shown)
    }

    @Test func aSentenceNotListedKeepsItsWordsAndGetsAFullStop() {
        #expect(
            ServerRefusal.sentence(for: "priya@x.ca is already on the team") == "priya@x.ca is already on the team."
        )
        #expect(ServerRefusal.sentence(for: "Another procedure is already called Filling.")
            == "Another procedure is already called Filling.")
        #expect(ServerRefusal.sentence(for: "Resolve every line to continue.") == "Resolve every line to continue.")
    }

    @Test func aConstraintsOwnMessageIsTheSaveFailure() {
        let duplicate = #"duplicate key value violates unique constraint "categories_clinic_id_name_key""#
        let check = #"new row for relation "batches" violates check constraint "batches_quantity_check""#
        for message in [duplicate, check, "", "  "] {
            #expect(ServerRefusal.sentence(for: message) == "Couldn't save. Try again.", "\(message)")
        }
    }

    @Test func everyHouseSentenceStartsWithACapitalAndEndsWithAFullStop() {
        for (server, shown) in ServerRefusal.houseCopy {
            #expect(shown.first?.isUppercase == true, "\(server)")
            #expect(shown.hasSuffix("."), "\(server)")
        }
    }

    @Test func theDatabaseAndTheFunctionsRefusalsMapToHouseCopy() async throws {
        let rpc = SupabaseRPCClient(transport: FakeRPCTransport(response: .failure(
            PostgrestError(code: "22023", message: "the product is archived")
        )))
        await #expect(throws: AppError.validation(field: nil, message: "This product was deleted.")) {
            let _: Bool = try await rpc.call("stock_adjust", params: ["p": "x"])
        }
        #expect(AppError.refusal("Enter a valid email", field: "email")
            == .validation(field: "email", message: "Enter a valid email address."))
    }

    /// Each sentence the migrations refuse with as a validation (22023, 23505), which the app shows, starts with a
    /// capital (or the name or address put in its place) once mapped; the full stop the mapping adds. A key that no
    /// migration or Edge Function sends any more is reported too.
    @Test func everyRefusalTheMigrationsSendReadsAsHouseCopy() throws {
        let supabase = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appending(path: "supabase")
        let sql = try sources(in: supabase.appending(path: "migrations"), withExtension: "sql")
        let functions = try sources(in: supabase.appending(path: "functions"), withExtension: "ts")
        let fails = try Regex(#"engine\.fail\('(?:22023|23505)',\s*'((?:[^']|'')*)'\)"#)
        let raises = try Regex(#"raise exception '((?:[^']|'')*)'[^;]*?errcode = '(?:22023|23505)'"#)
        var sentences: Set<String> = []
        for match in sql.matches(of: fails) + sql.matches(of: raises) {
            guard let sentence = match.output[1].substring else { continue }
            sentences.insert(String(sentence).replacing("''", with: "'"))
        }
        #expect(sentences.count > 40, "The migrations were not read")
        for sentence in sentences {
            let shown = ServerRefusal.sentence(for: sentence)
            #expect(shown.first?.isUppercase == true || shown.hasPrefix("%"), "\(sentence) reads \(shown)")
            #expect(shown.hasSuffix("."), "\(sentence) reads \(shown)")
        }
        for key in ServerRefusal.houseCopy.keys {
            #expect(sql.contains(key) || functions.contains(key), "No migration or function sends \(key)")
        }
    }

    private func sources(in folder: URL, withExtension pathExtension: String) throws -> String {
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == pathExtension } ?? []
        return try files.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
    }
}
