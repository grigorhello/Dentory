import Foundation
import Testing
@testable import Dentory

/// The pages' names in Storage (flow step 1), as the invoices bucket's policy and `invoice_create` expect them.
struct InvoiceFilesTests {
    private let clinicID = UUID(uuidString: "D0000000-0000-4000-8000-000000000001") ?? UUID()
    private let invoiceID = UUID(uuidString: "6F1C2A3B-0000-4000-8000-0000000000AB") ?? UUID()

    @Test func jpegPagesAreNumberedFromOneUnderTheClinicAndTheInvoiceInLowerCase() {
        #expect(InvoiceFiles.path(clinicID: clinicID, invoiceID: invoiceID, page: 1, kind: .jpeg)
            == "d0000000-0000-4000-8000-000000000001/6f1c2a3b-0000-4000-8000-0000000000ab/page-1.jpg")
        let twelfth = InvoiceFiles.path(clinicID: clinicID, invoiceID: invoiceID, page: 12, kind: .jpeg)
        #expect(twelfth.hasSuffix("/page-12.jpg"))
    }

    @Test func aPDFIsPageOneOfItsKind() {
        let pdf = InvoiceFiles.path(clinicID: clinicID, invoiceID: invoiceID, page: 1, kind: .pdf)
        #expect(pdf.hasSuffix("/page-1.pdf"))
        #expect(InvoiceFiles.bucket == "invoices")
    }

    @Test func discardingAnInvoiceDeletesEveryNameItsPagesCanHave() {
        let paths = InvoiceFiles.allPaths(clinicID: clinicID, invoiceID: invoiceID)
        let folder = "d0000000-0000-4000-8000-000000000001/6f1c2a3b-0000-4000-8000-0000000000ab/"
        #expect(paths.count == 21)
        #expect(paths.first == folder + "page-1.jpg")
        #expect(paths.contains(folder + "page-20.jpg"))
        #expect(paths.last == folder + "page-1.pdf")
        #expect(!paths.contains(folder + "page-21.jpg"), "The bucket takes no 21st page")
    }

    @Test func eachKindUploadsWithTheTypeTheBucketTakes() {
        #expect(InvoiceFiles.contentType(of: .jpeg) == "image/jpeg")
        #expect(InvoiceFiles.contentType(of: .pdf) == "application/pdf")
    }

    @Test func aDocumentIsItsPagesKindAndKnowsItsLimits() {
        let pdf = InvoiceDocument(source: .file, pages: [.init(kind: .pdf, data: Data(count: 3))])
        #expect(pdf.kind == .pdf)
        let pages = (1...21).map { _ in InvoiceDocument.Page(kind: .jpeg, data: Data(count: 1)) }
        #expect(InvoiceDocument(source: .camera, pages: Array(pages.prefix(20))).hasTooManyPages == false)
        #expect(InvoiceDocument(source: .camera, pages: pages).hasTooManyPages)
    }

    @Test func documentsAreToldApartByTheInvoiceTheyBecome() {
        let page = InvoiceDocument.Page(kind: .jpeg, data: Data(count: 4))
        let first = InvoiceDocument(source: .camera, pages: [page])
        let second = InvoiceDocument(source: .camera, pages: [page])
        #expect(first != second)
        #expect(first == InvoiceDocument(id: first.id, source: .camera, pages: [page]))
        #expect(Set([first, second, first]).count == 2)
    }
}
