import Foundation

/// When this device last offered notifications (MS-144). "Not now", or a sheet swiped away, brings the explainer back
/// 30 days later while iOS has not asked yet; an answer to iOS's own prompt ends it.
protocol PushExplainerStoring: AnyObject, Sendable {
    var lastOffered: Date? { get set }
}
