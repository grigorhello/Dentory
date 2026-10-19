import Foundation
import Testing
@testable import Dentory

struct InvitationLinkTests {
    private func token(_ string: String) -> String? {
        URL(string: string).flatMap(InvitationLink.token(from:))
    }

    @Test func theUniversalLinkCarriesTheToken() {
        #expect(token("https://app.dentory.ca/invite?token=AbC-123_xyz") == "AbC-123_xyz")
        #expect(token("HTTPS://App.Dentory.ca/invite?utm=x&token=t1") == "t1")
    }

    @Test func theAppSchemeCarriesTheToken() {
        #expect(token("dentory://invite?token=t2") == "t2")
        #expect(token("dentory:///invite?token=t3") == "t3")
    }

    @Test func otherLinksAreIgnored() {
        #expect(token("https://dentory.ca/invite?token=t") == nil)
        #expect(token("https://app.dentory.ca/reset?token=t") == nil)
        #expect(token("http://app.dentory.ca/invite?token=t") == nil)
        #expect(token("dentory://reset?token=t") == nil)
        #expect(token("https://evil.example/invite?token=t") == nil)
    }

    @Test func aMissingOrBlankTokenIsNoLink() {
        #expect(token("https://app.dentory.ca/invite") == nil)
        #expect(token("https://app.dentory.ca/invite?token=") == nil)
        #expect(token("dentory://invite?token=%20") == nil)
    }
}
