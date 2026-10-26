import Foundation

/// A delivery's paperwork as Receive delivery captures it (f22): the scanned or picked pages as JPEG images, or one
/// PDF. Every image, HEIC and PNG included, becomes a JPEG page on capture, so the upload (MS-129) names its files
/// `page-n.jpg` or `page-1.pdf` and sends the reader only kinds it takes. It travels in `ReceiveRoute.newInvoice` to
/// Review invoice, which uploads it.
nonisolated struct InvoiceDocument: Hashable, Sendable {
    /// How it was captured, as `invoices.source` records it: Take a photo (the scanner, or Photos where the device has
    /// no scanner) or Upload PDF or image.
    nonisolated enum Source: String, Hashable, Sendable {
        case camera
        case file
    }

    /// The file kind, named as the page's file extension.
    nonisolated enum PageKind: String, Hashable, Sendable {
        case jpeg = "jpg"
        case pdf
    }

    nonisolated struct Page: Hashable, Sendable {
        let kind: PageKind
        let data: Data
    }

    /// The invoice it becomes. The app names it, so the upload's folder and the invoice row agree, and an upload tried
    /// again lands on the same invoice instead of a second one.
    let id: UUID
    let source: Source
    let pages: [Page]

    init(id: UUID = UUID(), source: Source, pages: [Page]) {
        self.id = id
        self.source = source
        self.pages = pages
    }

    /// 20 MB, counted as the Files app shows sizes (1 MB = 1,000,000 bytes), so a file it lists at 19.8 MB passes.
    static let maxByteCount = 20_000_000

    /// Up to 20 pages: the most one reading takes at full size.
    static let maxPageCount = 20

    var byteCount: Int {
        pages.reduce(0) { $0 + $1.data.count }
    }

    var isTooLarge: Bool {
        byteCount > Self.maxByteCount
    }

    var hasTooManyPages: Bool {
        pages.count > Self.maxPageCount
    }

    /// JPEG pages, or one PDF.
    var kind: PageKind {
        pages.first?.kind ?? .jpeg
    }

    /// The id alone tells documents apart: hashing megabytes of pages would buy nothing.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
