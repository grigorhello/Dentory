import Foundation
import Testing

/// The app's privacy manifest (MS-152, `Dentory/Resources/PrivacyInfo.xcprivacy`). Apple reads it at the root of the
/// app after an upload and refuses a build whose manifest it cannot read (ITMS-91056); these catch a missing file, a
/// misspelt key or an unknown reason before that. What it declares and why is in the decisions log (2026-11-05 02:52).
struct PrivacyManifestTests {
    /// The required-reason API categories and the reasons Apple lists for each.
    private static let reasons: [String: Set<String>] = [
        "NSPrivacyAccessedAPICategoryFileTimestamp": ["DDA9.1", "C617.1", "3B52.1", "0A2A.1"],
        "NSPrivacyAccessedAPICategorySystemBootTime": ["35F9.1", "8FFB.1", "3D61.1"],
        "NSPrivacyAccessedAPICategoryDiskSpace": ["85F4.1", "E174.1", "7D9E.1", "B728.1"],
        "NSPrivacyAccessedAPICategoryActiveKeyboards": ["3EC4.1", "54BD.1"],
        "NSPrivacyAccessedAPICategoryUserDefaults": ["CA92.1", "1C8F.1", "C56D.1", "AC6B.1"]
    ]

    /// Apple's collected data types, "PhotosorVideos" spelt as Apple spells it.
    private static let dataTypes = Set([
        "Name", "EmailAddress", "PhoneNumber", "PhysicalAddress", "OtherUserContactInfo", "Health", "Fitness",
        "PaymentInfo", "CreditInfo", "OtherFinancialInfo", "PreciseLocation", "CoarseLocation", "SensitiveInfo",
        "Contacts", "EmailsOrTextMessages", "PhotosorVideos", "AudioData", "GameplayContent", "CustomerSupport",
        "OtherUserContent", "BrowsingHistory", "SearchHistory", "UserID", "DeviceID", "PurchaseHistory",
        "ProductInteraction", "AdvertisingData", "OtherUsageData", "CrashData", "PerformanceData",
        "OtherDiagnosticData", "EnvironmentScanning", "Hands", "Head", "OtherDataTypes"
    ].map { "NSPrivacyCollectedDataType" + $0 })

    private static let purposes = Set([
        "ThirdPartyAdvertising", "DeveloperAdvertising", "Analytics", "ProductPersonalization", "AppFunctionality",
        "Other"
    ].map { "NSPrivacyCollectedDataTypePurpose" + $0 })

    @Test func shipsAtTheRootOfTheApp() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        #expect(url.deletingLastPathComponent().standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL)
    }

    @Test func tracksNoOne() throws {
        let manifest = try Self.manifest()
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [String])?.isEmpty == true)
    }

    @Test func everyCollectedDataTypeIsOneOfApplesWithItsPurposes() throws {
        let manifest = try Self.manifest()
        let entries = try #require(manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        #expect(!entries.isEmpty)
        for entry in entries {
            let type = try #require(entry["NSPrivacyCollectedDataType"] as? String)
            #expect(Self.dataTypes.contains(type), "\(type) is not one of Apple's data types")
            #expect(entry["NSPrivacyCollectedDataTypeLinked"] is Bool, "\(type) does not say if it is linked")
            #expect(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool == false, "\(type) is used for tracking")
            let purposes = try #require(entry["NSPrivacyCollectedDataTypePurposes"] as? [String])
            #expect(!purposes.isEmpty && Set(purposes).isSubset(of: Self.purposes), "\(type): \(purposes)")
        }
    }

    @Test func everyRequiredReasonAPIGivesAReasonAppleListsForIt() throws {
        let manifest = try Self.manifest()
        let entries = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        #expect(!entries.isEmpty)
        for entry in entries {
            let category = try #require(entry["NSPrivacyAccessedAPIType"] as? String)
            let allowed = try #require(Self.reasons[category], "\(category) is not one of Apple's categories")
            let reasons = try #require(entry["NSPrivacyAccessedAPITypeReasons"] as? [String])
            #expect(!reasons.isEmpty && Set(reasons).isSubset(of: allowed), "\(category): \(reasons)")
        }
    }

    private static func manifest() throws -> [String: Any] {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        return try #require(plist as? [String: Any])
    }
}
