import Foundation
import Testing
import UIKit
@testable import Dentory

/// What Take a photo and Upload PDF or image hand over becomes JPEG pages or one PDF; a file over 20 MB is refused
/// before it is read, and one that is not a PDF or an image cannot be opened.
struct InvoiceCaptureTests {
    private static let jpegStart = Data([0xFF, 0xD8])

    private let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 30))

    private func image(_ color: UIColor) -> UIImage {
        renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 30))
        }
    }

    private var png: Data {
        renderer.pngData { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 30))
        }
    }

    /// A file in the temporary directory, removed when the test ends.
    private func file(named name: String, contents: Data? = nil, size: UInt64? = nil) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)-\(name)")
        try (contents ?? Data()).write(to: url)
        if let size {
            let handle = try FileHandle(forWritingTo: url)
            try handle.truncate(atOffset: size)
            try handle.close()
        }
        return url
    }

    @Test func scannedPagesBecomeJPEGPagesInOrder() async throws {
        let document = try await InvoiceCapture.document(scanned: [image(.white), image(.black)])
        #expect(document.source == .camera)
        #expect(document.pages.map(\.kind) == [.jpeg, .jpeg])
        #expect(document.pages.allSatisfy { $0.data.starts(with: Self.jpegStart) })
        #expect(document.pages[0].data != document.pages[1].data, "Each page keeps its own image")
    }

    @Test func aPDFStaysTheFileItIs() async throws {
        let bytes = Data("%PDF-1.4\n%%EOF\n".utf8)
        let url = try file(named: "invoice.pdf", contents: bytes)
        defer { try? FileManager.default.removeItem(at: url) }
        let document = try await InvoiceCapture.document(fileAt: url)
        #expect(document.source == .file)
        #expect(document.pages == [InvoiceDocument.Page(kind: .pdf, data: bytes)])
    }

    @Test func aPNGBecomesOneJPEGPage() async throws {
        let url = try file(named: "slip.png", contents: png)
        defer { try? FileManager.default.removeItem(at: url) }
        let document = try await InvoiceCapture.document(fileAt: url)
        #expect(document.pages.count == 1)
        #expect(document.pages[0].kind == .jpeg)
        #expect(document.pages[0].data.starts(with: Self.jpegStart))
    }

    @Test func aFileOverTwentyMegabytesIsRefusedBeforeItIsRead() async throws {
        let url = try file(named: "scan.pdf", size: UInt64(InvoiceDocument.maxByteCount) + 1)
        defer { try? FileManager.default.removeItem(at: url) }
        await #expect(throws: InvoiceCaptureError.tooLarge(.file)) {
            try await InvoiceCapture.document(fileAt: url)
        }
    }

    @Test func anImageThatIsNotOneCannotBeOpened() async throws {
        let url = try file(named: "broken.jpg", contents: Data("not an image".utf8))
        defer { try? FileManager.default.removeItem(at: url) }
        await #expect(throws: InvoiceCaptureError.unreadable(.file)) {
            try await InvoiceCapture.document(fileAt: url)
        }
        let missing = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).pdf")
        await #expect(throws: InvoiceCaptureError.unreadable(.file)) {
            try await InvoiceCapture.document(fileAt: missing)
        }
    }

    @Test func uploadOffersPDFJPGPNGAndHEIC() {
        let identifiers = InvoiceCapture.fileTypes.map(\.identifier)
        #expect(identifiers == ["com.adobe.pdf", "public.jpeg", "public.png", "public.heic"])
    }
}
