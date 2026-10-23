import Foundation
import Testing
@testable import Dentory

/// MS-142: the app's copy of `clinic_can_write`, which decides read-only mode on the device.
struct SubscriptionStatusTests {
    private let now = Session.demoNow
    private let day: TimeInterval = 86_400

    @Test func aTrialAllowsChangesUntilItEnds() {
        #expect(SubscriptionStatus.trialing.allowsChanges(trialEndsAt: now.addingTimeInterval(day), now: now))
        #expect(!SubscriptionStatus.trialing.allowsChanges(trialEndsAt: now.addingTimeInterval(-day), now: now))
        #expect(!SubscriptionStatus.trialing.allowsChanges(trialEndsAt: now, now: now), "Ended at this moment")
        #expect(SubscriptionStatus.trialing.allowsChanges(trialEndsAt: nil, now: now), "Unknown: the server decides")
    }

    @Test func aPaidOrRetryingSubscriptionAllowsChangesAndAnEndedOneDoesNot() {
        let ended = now.addingTimeInterval(-30 * day)
        #expect(SubscriptionStatus.active.allowsChanges(trialEndsAt: ended, now: now))
        #expect(SubscriptionStatus.pastDue.allowsChanges(trialEndsAt: ended, now: now), "Stripe is retrying")
        #expect(!SubscriptionStatus.canceled.allowsChanges(trialEndsAt: ended, now: now))
        #expect(!SubscriptionStatus.readOnly.allowsChanges(trialEndsAt: ended, now: now))
    }

    @Test func theSessionReadsItsClinicsStatus() {
        var session = Session.demo
        #expect(session.canWrite(at: now), "The demo clinic's trial has no end set")
        session.trialEndsAt = now.addingTimeInterval(-day)
        #expect(!session.canWrite(at: now))
        session.subscriptionStatus = .active
        #expect(session.canWrite(at: now), "A card added after the trial ended")
    }
}
