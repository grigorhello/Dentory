import Foundation
import Testing
@testable import Dentory

struct PasswordResetLinkTests {
    private func tokenHash(_ string: String) -> String? {
        URL(string: string).flatMap(PasswordResetLink.tokenHash(from:))
    }

    @Test func theUniversalLinkCarriesTheTokenHash() {
        let link = "https://app.dentory.ca/reset-password?token_hash=pkce_ab12&type=recovery"
        #expect(tokenHash(link) == "pkce_ab12")
        #expect(tokenHash("HTTPS://App.Dentory.ca/reset-password?type=recovery&token_hash=h1") == "h1")
    }

    @Test func theAppSchemeCarriesTheTokenHash() {
        #expect(tokenHash("dentory://reset-password?token_hash=h2&type=recovery") == "h2")
        #expect(tokenHash("dentory:///reset-password?token_hash=h3") == "h3")
    }

    @Test func otherLinksAreIgnored() {
        #expect(tokenHash("https://app.dentory.ca/invite?token_hash=h") == nil)
        #expect(tokenHash("http://app.dentory.ca/reset-password?token_hash=h") == nil)
        #expect(tokenHash("https://dentory.ca/reset-password?token_hash=h") == nil)
        #expect(tokenHash("dentory://invite?token=t") == nil)
        #expect(tokenHash("https://evil.example/reset-password?token_hash=h") == nil)
    }

    @Test func aMissingOrBlankTokenHashIsNoLink() {
        #expect(tokenHash("https://app.dentory.ca/reset-password") == nil)
        #expect(tokenHash("dentory://reset-password?token_hash=") == nil)
        #expect(tokenHash("dentory://reset-password?token=t") == nil, "An invitation-style token is not a reset link")
    }

    @Test func anInvitationLinkIsNotAResetLinkAndBackwards() {
        let invitation = URL(string: "dentory://invite?token=t")
        let reset = URL(string: "dentory://reset-password?token_hash=h")
        #expect(invitation.flatMap(PasswordResetLink.tokenHash(from:)) == nil)
        #expect(reset.flatMap(InvitationLink.token(from:)) == nil)
    }

    @Test func theRedirectFallsBackToTheUniversalLink() {
        #expect(PasswordResetLink.universalRedirect?.absoluteString == "https://app.dentory.ca/reset-password")
        // The test bundle has no PASSWORD_RESET_URL key.
        let testBundle = Bundle(for: BundleToken.self)
        #expect(PasswordResetLink.redirectURL(bundle: testBundle) == PasswordResetLink.universalRedirect)
    }
}

private final class BundleToken {}
