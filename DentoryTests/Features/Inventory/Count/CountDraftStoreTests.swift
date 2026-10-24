import Foundation
import Testing
@testable import Dentory

struct CountDraftStoreTests {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "count-draft-tests-\(UUID().uuidString)")
            .appending(path: "count-draft.json")
    }

    @Test func theFileKeepsTheCountsUntilCleared() throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = FileCountDraftStore(fileURL: url)
        #expect(store.load() == nil)
        let draft = StockCount(
            clinicID: Session.demo.clinicID, userID: Session.demo.userID, startedAt: Session.demoNow,
            counted: [ProductSummary.demo[0].id: 52, ProductSummary.demo[2].id: 2]
        )
        store.save(draft)
        #expect(FileCountDraftStore(fileURL: url).load() == draft, "A new launch reads the same counts")
        let json = try String(contentsOf: url, encoding: .utf8)
        #expect(json.contains("\"lines\""), "The counts are stored as lines")
        store.clear()
        #expect(store.load() == nil)
        #expect(FileManager.default.fileExists(atPath: url.path) == false)
    }

    /// A draft written before the count kept its start (MS-147) still opens; its seconds read 0.
    @Test func aDraftWithoutAStartStillOpens() throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let product = ProductSummary.demo[0].id
        let json = """
            {"clinicID":"\(Session.demo.clinicID)","userID":"\(Session.demo.userID)",\
            "lines":[{"productID":"\(product)","counted":52}]}
            """
        try Data(json.utf8).write(to: url)
        let draft = try #require(FileCountDraftStore(fileURL: url).load())
        #expect(draft.startedAt == nil)
        #expect(draft.counted == [product: 52])
        #expect(draft.seconds(until: Session.demoNow) == 0)
    }

    @Test func anUnreadableFileIsNoDraft() throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        #expect(FileCountDraftStore(fileURL: url).load() == nil)
    }
}
