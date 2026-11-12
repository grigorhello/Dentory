import Foundation

/// The sheet a captured page that looks unreadable opens (MS-163, `receive.check`): which page, why, and what the
/// sheet says. Retake opens the picker the pages came from again; Use anyway sends them on as they are.
struct ReceiveCheck: Identifiable, Equatable {
    /// The pages waiting for the answer; dropped when the sheet closes without one.
    let document: InvoiceDocument
    /// The first page found unreadable, counted from 1.
    let page: Int
    let problem: InvoicePageProblem

    var id: UUID { document.id }

    static let useAnywayTitle = "Use anyway"

    /// "This photo is hard to read", "Page 2 is too dark"; a file is one image, so it never names a page.
    var title: String {
        let reads = problem == .blurry ? "is hard to read" : "is too dark"
        return switch document.source {
        case .camera where document.pages.count > 1: "Page \(page) \(reads)"
        case .camera: "This photo \(reads)"
        case .file: "This image \(reads)"
        }
    }

    var message: String {
        switch (document.source, problem) {
        case (.camera, .blurry):
            "The text looks blurry, so lines could be missed. Hold the phone steady over the page, in good light."
        case (.camera, .dark):
            "Lines could be missed. Retake it in better light or with the flash on."
        case (.file, .blurry):
            "The text looks blurry, so lines could be missed."
        case (.file, .dark):
            "It is too dark, so lines could be missed."
        }
    }

    /// Retake opens the scanner or Photos again; Choose another opens Files again.
    var retakeTitle: String {
        document.source == .camera ? "Retake" : "Choose another"
    }
}
