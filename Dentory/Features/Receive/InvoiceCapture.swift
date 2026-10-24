import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Turns what the scanner, Photos or Files hand over into an `InvoiceDocument`, off the main actor since encoding
/// full-size pages takes a moment: every image becomes a JPEG page, a PDF stays the one file it is. A file over 20 MB
/// is refused before it is read.
nonisolated enum InvoiceCapture {
    /// What Upload PDF or image offers in Files (PRD §6.5: PDF, JPG, PNG, HEIC).
    static let fileTypes: [UTType] = [.pdf, .jpeg, .png, .heic]

    /// Sharp enough for an invoice's small print, small enough to upload quickly.
    private static let jpegQuality: CGFloat = 0.8

    /// The scanner's pages, in the order they were scanned.
    @concurrent
    static func document(scanned images: [UIImage]) async throws(InvoiceCaptureError) -> InvoiceDocument {
        var pages: [InvoiceDocument.Page] = []
        for image in images {
            pages.append(try jpegPage(image, source: .camera))
        }
        return InvoiceDocument(source: .camera, pages: pages)
    }

    /// Photos picked in place of the scanner, in the order they were picked.
    @concurrent
    static func document(photos items: [PhotosPickerItem]) async throws(InvoiceCaptureError) -> InvoiceDocument {
        var pages: [InvoiceDocument.Page] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                throw .unreadable(.camera)
            }
            pages.append(try jpegPage(image, source: .camera))
        }
        return InvoiceDocument(source: .camera, pages: pages)
    }

    /// A PDF or an image picked in Files.
    @concurrent
    static func document(fileAt url: URL) async throws(InvoiceCaptureError) -> InvoiceDocument {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { url.stopAccessingSecurityScopedResource() }
        }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        if let size = values?.fileSize, size > InvoiceDocument.maxByteCount {
            throw .tooLarge(.file)
        }
        guard let data = try? Data(contentsOf: url) else { throw .unreadable(.file) }
        let type = values?.contentType ?? UTType(filenameExtension: url.pathExtension)
        if type?.conforms(to: .pdf) == true {
            return InvoiceDocument(source: .file, pages: [InvoiceDocument.Page(kind: .pdf, data: data)])
        }
        guard let image = UIImage(data: data) else { throw .unreadable(.file) }
        return InvoiceDocument(source: .file, pages: [try jpegPage(image, source: .file)])
    }

    private static func jpegPage(
        _ image: UIImage, source: InvoiceDocument.Source
    ) throws(InvoiceCaptureError) -> InvoiceDocument.Page {
        guard let data = image.jpegData(compressionQuality: jpegQuality) else { throw .unreadable(source) }
        return InvoiceDocument.Page(kind: .jpeg, data: data)
    }
}
