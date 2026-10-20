/// Whether this device already offered notifications (MS-144): the explainer shows once, whatever the answer.
protocol PushExplainerStoring: AnyObject, Sendable {
    var hasOffered: Bool { get set }
}
