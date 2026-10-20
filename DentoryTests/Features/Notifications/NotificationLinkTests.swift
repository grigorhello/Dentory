import Foundation
import Testing
@testable import Dentory

/// The links a push carries (`push_claim`), and what is not one.
struct NotificationLinkTests {
    private let id = "00000000-0000-4000-8000-0000000000d1"

    private func link(_ text: String) -> NotificationLink? {
        URL(string: text).flatMap(NotificationLink.init(url:))
    }

    @Test func productAndDeliveryLinksOpen() {
        let product = NotificationLink.product(UUID(uuidString: id) ?? UUID())
        #expect(link("dentory://product/\(id)") == product)
        #expect(link("DENTORY://Product/\(id.uppercased())") == product)
        #expect(link("dentory://delivery") == .delivery)
    }

    @Test func otherLinksAreNotNotifications() {
        #expect(link("dentory://invite?token=abc") == nil)
        #expect(link("dentory://product/not-a-uuid") == nil)
        #expect(link("dentory://product") == nil)
        #expect(link("https://example.com/product/\(id)") == nil)
        #expect(link("https://app.dentory.ca/reset-password?token_hash=x") == nil)
        #expect(link("https://app.dentory.ca/product/\(id)") == nil, "The universal link domain claims no push paths")
    }
}
