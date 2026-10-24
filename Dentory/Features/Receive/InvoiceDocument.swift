import Foundation

/// A delivery's paperwork as Receive delivery captures it (f22): the scanned or picked pages as JPEG images, or one
/// PDF. Every image, HEIC and PNG included, becomes a JPEG page on capture, so the upload that reads it (MS-129) names
/// its files `page-n.jpg` or `page-n.pdf` and sends the reader only kinds it takes.
nonisolated struct InvoiceDocument: Equatable, Sendable {
    /// How it was captured, as `invoices.source` records it: Take a photo (the scanner, or Photos where the device has
    /// no scanner) or Upload PDF or image.
    nonisolated enum Source: String, Hashable, Sendable {
        case camera
        case file
    }

    nonisolated enum PageKind: String, Sendable {
        case jpeg = "jpg"
        case pdf
    }

    nonisolated struct Page: Equatable, Sendable {
        let kind: PageKind
        let data: Data
    }

    let source: Source
    let pages: [Page]

    /// 20 MB, counted as the Files app shows sizes (1 MB = 1,000,000 bytes), so a file it lists at 19.8 MB passes.
    static let maxByteCount = 20_000_000

    var byteCount: Int {
        pages.reduce(0) { $0 + $1.data.count }
    }

    var isTooLarge: Bool {
        byteCount > Self.maxByteCount
    }
}
