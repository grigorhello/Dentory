import Foundation
import Testing
@testable import Dentory

/// MS-147: every event is named by a PRD Appendix B element id and carries numbers, yes or no, and words from closed
/// lists only: no product or person name, email, note or invoice text can leave the app.
struct AnalyticsEventTests {
    /// One of each event the app sends.
    static let samples: [AnalyticsEvent] = [
        .signedIn, .clinicCreated, .onboardingFinished(invitations: 2), .onboardingFinished(invitations: 0),
        .invitationAccepted, .procedureStarted(items: 11, bottlesOpened: 1, shortages: 1, seconds: 42),
        .procedureUsageEdited(items: 3), .procedureCancelled, .templateSaved(items: 12, isNew: true), .templateDeleted,
        .stockAdjusted(reason: .other, increase: true), .addedToBuy, .bottleOpened, .bottleFinished,
        .markedOrdered(items: 2), .toBuyAdded, .batchDisposed, .teammateInvited(role: .admin), .exportStarted,
        .settingsSaved(digest: true, expiryWarningDays: 30), .productCreated,
        .countApplied(corrections: 3, seconds: 95)
    ]

    @Test func everyEventIsAnAppendixBElementId() {
        let names = AnalyticsEventName.allCases.map(\.rawValue)
        let elementID = #"^[a-z][a-zA-Z]*(\.[a-z][a-zA-Z]*)+$"#
        for name in names {
            #expect(name.range(of: elementID, options: .regularExpression) != nil, "\(name)")
        }
        #expect(Set(names).count == names.count, "Each name once")
        #expect(Set(Self.samples.map(\.name)) == Set(AnalyticsEventName.allCases), "Every event has a sample here")
    }

    /// The acceptance criterion: no payload carries free text.
    @Test func noPayloadCarriesFreeText() {
        let words = Set(AnalyticsWord.allCases.map(\.rawValue))
        let keys = Set(AnalyticsProperty.allCases.map(\.rawValue))
        for event in Self.samples {
            for (key, value) in event.payload {
                #expect(keys.contains(key), "\(event.name.rawValue) sends an unknown key \(key)")
                switch value {
                case .number, .bool:
                    break
                case .text(let text):
                    #expect(words.contains(text), "\(event.name.rawValue) sends free text in \(key)")
                }
            }
        }
    }

    @Test func aProcedureStartCarriesItsFigures() {
        let event = AnalyticsEvent.procedureStarted(items: 11, bottlesOpened: 1, shortages: 1, seconds: 42)
        #expect(event.name.rawValue == "procDetail.start")
        #expect(event.payload == [
            "item_count": .number(11), "bottles_opened": .number(1), "shortage_count": .number(1),
            "duration_s": .number(42)
        ])
        #expect(AnalyticsEvent.stockAdjusted(reason: .dataCorrection, increase: false).payload
            == ["reason": .text("data_correction"), "direction": .text("decrease")])
    }

    /// The pilot dashboard's "Counts applied" reads it (MS-121).
    @Test func anAppliedCountCarriesItsCorrectionsAndSeconds() {
        let event = AnalyticsEvent.countApplied(corrections: 3, seconds: 95)
        #expect(event.name.rawValue == "inv.count.review")
        #expect(event.payload == ["item_count": .number(3), "duration_s": .number(95)])
    }

    /// A build without a project token sends nothing (the test bundle has none, whatever the developer's Debug
    /// secrets say).
    @Test func withoutATokenPostHogStaysOffOnTheEUCloud() {
        let analytics = PostHogAnalytics(bundle: Bundle(for: SpyAnalytics.self))
        #expect(analytics.token == nil)
        #expect(analytics.host == PostHogAnalytics.euHost)
    }
}
