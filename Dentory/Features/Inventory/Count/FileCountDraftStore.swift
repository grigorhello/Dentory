import Foundation

/// The count in progress as one small JSON file in Application Support.
struct FileCountDraftStore: CountDraftStoring {
    let fileURL: URL

    init(fileURL: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.fileURL = fileURL ?? support.appending(path: "count-draft.json")
    }

    func load() -> StockCount? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(StockCount.self, from: data)
    }

    func save(_ count: StockCount) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try JSONEncoder().encode(count).write(to: fileURL, options: .atomic)
        } catch {
            // The counts stay on screen for this launch; the next change tries again.
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
