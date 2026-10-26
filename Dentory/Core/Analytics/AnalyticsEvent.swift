import Foundation

/// One analytics event (MS-147): an Appendix B element id and its properties. Built only through the factories
/// below, whose values are counts, seconds, yes or no, and words from `AnalyticsWord`, so no event can carry text
/// someone typed, a product's or a person's name, an email or an invoice's contents.
nonisolated struct AnalyticsEvent: Equatable, Sendable {
    let name: AnalyticsEventName
    let properties: [AnalyticsProperty: AnalyticsValue]

    /// What PostHog receives: the property keys and plain numbers, booleans and words.
    var payload: [String: AnalyticsPayloadValue] {
        Dictionary(uniqueKeysWithValues: properties.map { ($0.key.rawValue, $0.value.payloadValue) })
    }

    static let signedIn = Self(name: .signIn, properties: [:])
    static let clinicCreated = Self(name: .clinicCreated, properties: [:])
    static let invitationAccepted = Self(name: .invitationAccepted, properties: [:])
    static let procedureCancelled = Self(name: .procedureCancel, properties: [:])
    static let templateDeleted = Self(name: .templateDelete, properties: [:])
    static let addedToBuy = Self(name: .productAddToBuy, properties: [:])
    static let bottleOpened = Self(name: .bottleOpen, properties: [:])
    static let bottleFinished = Self(name: .bottleFinish, properties: [:])
    static let batchDisposed = Self(name: .batchDispose, properties: [:])
    static let exportStarted = Self(name: .export, properties: [:])
    /// A product created on Inventory's New product sheet (MS-117); never its name.
    static let productCreated = Self(name: .productCreate, properties: [:])

    /// Sign-up's last step: the invitations sent, 0 when skipped.
    static func onboardingFinished(invitations: Int) -> Self {
        Self(name: invitations > 0 ? .sendInvites : .skipInvites, properties: [.itemCount: .count(invitations)])
    }

    /// A procedure recorded: its supplies, the bottles it opened, the lines short of stock, and the seconds from the
    /// screen's load to Start.
    static func procedureStarted(items: Int, bottlesOpened: Int, shortages: Int, seconds: Int) -> Self {
        Self(name: .procedureStart, properties: [
            .itemCount: .count(items), .bottlesOpened: .count(bottlesOpened), .shortageCount: .count(shortages),
            .durationSeconds: .count(seconds)
        ])
    }

    /// A past procedure's usage corrected: the supplies whose quantity changed.
    static func procedureUsageEdited(items: Int) -> Self {
        Self(name: .procedureSave, properties: [.itemCount: .count(items)])
    }

    /// A procedure's defaults saved, new or edited.
    static func templateSaved(items: Int, isNew: Bool) -> Self {
        Self(name: .templateSave, properties: [.itemCount: .count(items), .isNew: .flag(isNew)])
    }

    /// Stock corrected from Product detail: why, from the reasons' list, and whether it went up or down.
    static func stockAdjusted(reason: AdjustmentReason, increase: Bool) -> Self {
        Self(name: .productAdjust, properties: [
            .reason: .word(AnalyticsWord(reason)), .direction: .word(increase ? .increase : .decrease)
        ])
    }

    /// A reviewed count applied on Inventory (MS-121): the corrections it wrote, and the seconds from Count stock to
    /// Apply count.
    static func countApplied(corrections: Int, seconds: Int) -> Self {
        Self(name: .countReview, properties: [.itemCount: .count(corrections), .durationSeconds: .count(seconds)])
    }

    static func markedOrdered(items: Int) -> Self {
        Self(name: .markOrdered, properties: [.itemCount: .count(items)])
    }

    /// A product added to To buy from its sheet.
    static let toBuyAdded = Self(name: .toBuyAdd, properties: [:])

    /// A delivery received by hand on Receive manually (MS-127): one product a time, so `item_count` is 1.
    static let manualReceived = Self(name: .manualReceive, properties: [.itemCount: .count(1)])

    /// An invoice received (MS-131): its lines, those matched automatically when it was read, the products created for
    /// it and the seconds from its upload to Confirm & receive, which the pilot dashboard reads.
    static func invoiceConfirmed(lines: Int, matched: Int, created: Int, seconds: Int) -> Self {
        Self(name: .invoiceConfirm, properties: [
            .itemCount: .count(lines), .matchedCount: .count(matched), .createdCount: .count(created),
            .durationSeconds: .count(seconds)
        ])
    }

    static func teammateInvited(role: MembershipRole) -> Self {
        Self(name: .teamInvite, properties: [.role: .word(AnalyticsWord(role))])
    }

    /// Clinic settings saved: whether the weekly digest stays on, and the first expiry warning (30, 60 or 90 days).
    static func settingsSaved(digest: Bool, expiryWarningDays: Int) -> Self {
        Self(name: .settingsSave, properties: [.digest: .flag(digest), .expiryWarningDays: .count(expiryWarningDays)])
    }
}

/// The events, by their Appendix B element id; a parameter in brackets (`[batchId]`) is left out.
nonisolated enum AnalyticsEventName: String, CaseIterable, Sendable {
    case signIn = "signin.submit"
    case clinicCreated = "onboard.continue"
    case sendInvites = "onboard.sendInvites"
    case skipInvites = "onboard.skip"
    case invitationAccepted = "invite.submit"
    case procedureStart = "procDetail.start"
    case procedureSave = "procDetail.save"
    case procedureCancel = "procDetail.cancel"
    case templateSave = "procEdit.save"
    case templateDelete = "procEdit.delete"
    case productAdjust = "product.adjust"
    case productAddToBuy = "product.addToBuy"
    case bottleOpen = "product.openNewBottle"
    case bottleFinish = "product.bottle.finished"
    case markOrdered = "order.markOrdered"
    case toBuyAdd = "order.add"
    case batchDispose = "expiring.card.dispose"
    case teamInvite = "team.invite"
    case export = "more.export"
    case settingsSave = "settings.save"
    case productCreate = "inv.newProduct"
    case countReview = "inv.count.review"
    case manualReceive = "manual.receive"
    case invoiceConfirm = "invoice.confirm"
}

/// Every property key an event may carry.
nonisolated enum AnalyticsProperty: String, CaseIterable, Sendable {
    case itemCount = "item_count"
    case bottlesOpened = "bottles_opened"
    case shortageCount = "shortage_count"
    case durationSeconds = "duration_s"
    case matchedCount = "matched_count"
    case createdCount = "created_count"
    case isNew = "is_new"
    case digest
    case expiryWarningDays = "expiry_warning_days"
    case direction
    case reason
    case role
}

/// The words an event may carry: roles, directions and the adjustment reasons, nothing else.
nonisolated enum AnalyticsWord: String, CaseIterable, Sendable {
    case admin, staff, increase, decrease
    case physicalCount = "physical_count", expired, damaged, waste, missing, returned
    case dataCorrection = "data_correction", other

    init(_ role: MembershipRole) {
        self = role == .admin ? .admin : .staff
    }

    init(_ reason: AdjustmentReason) {
        self = switch reason {
        case .physicalCount: .physicalCount
        case .expired: .expired
        case .damaged: .damaged
        case .waste: .waste
        case .missing: .missing
        case .returned: .returned
        case .dataCorrection: .dataCorrection
        case .other: .other
        }
    }
}

nonisolated enum AnalyticsValue: Equatable, Sendable {
    case count(Int)
    case flag(Bool)
    case word(AnalyticsWord)

    var payloadValue: AnalyticsPayloadValue {
        switch self {
        case .count(let value): .number(value)
        case .flag(let value): .bool(value)
        case .word(let word): .text(word.rawValue)
        }
    }
}

/// A property as it leaves the app.
nonisolated enum AnalyticsPayloadValue: Equatable, Sendable {
    case number(Int)
    case bool(Bool)
    case text(String)

    var any: Any {
        switch self {
        case .number(let value): value
        case .bool(let value): value
        case .text(let value): value
        }
    }
}
