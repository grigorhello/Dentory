import Accessibility
import Foundation
import Observation
import UIKit

/// What a toast shows: a title, one detail line and, for single reversible actions, Undo (PRD §7).
struct Toast: Identifiable, Equatable {
    let id: UUID
    let title: String
    var detail: String?
    var undo: (@MainActor () -> Void)?

    init(id: UUID = UUID(), title: String, detail: String? = nil, undo: (@MainActor () -> Void)? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.undo = undo
    }

    var hasUndo: Bool { undo != nil }

    /// What VoiceOver says as the toast appears: its title and detail, and that it offers Undo.
    var announcement: String {
        [title, detail, hasUndo ? "Undo available" : nil].compactMap { $0 }.joined(separator: ". ")
    }

    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.detail == rhs.detail && lhs.hasUndo == rhs.hasUndo
    }
}

/// Shows one toast at a time for 3.2 s, or 10 s while VoiceOver runs so that its Undo can be reached; a new one
/// replaces the old. VoiceOver announces each one as it appears (MS-149). Lives in `AppDependencies`.
@MainActor
@Observable
final class ToastCenter {
    static let defaultDuration: TimeInterval = 3.2
    static let voiceOverDuration: TimeInterval = 10

    private(set) var current: Toast?
    /// Height of the pinned primary bar on screen, so the toast floats above it (0 when there is none).
    var bottomInset: CGFloat = 0
    private let duration: TimeInterval
    private let voiceOverDuration: TimeInterval
    private let isVoiceOverRunning: @MainActor () -> Bool
    private let announce: @MainActor (String) -> Void
    private var dismissal: Task<Void, Never>?

    init(
        duration: TimeInterval = ToastCenter.defaultDuration,
        voiceOverDuration: TimeInterval = ToastCenter.voiceOverDuration,
        isVoiceOverRunning: @escaping @MainActor () -> Bool = { UIAccessibility.isVoiceOverRunning },
        announce: @escaping @MainActor (String) -> Void = ToastCenter.postAnnouncement
    ) {
        self.duration = duration
        self.voiceOverDuration = voiceOverDuration
        self.isVoiceOverRunning = isVoiceOverRunning
        self.announce = announce
    }

    func show(_ title: String, detail: String? = nil, undo: (@MainActor () -> Void)? = nil) {
        show(Toast(title: title, detail: detail, undo: undo))
    }

    func show(_ toast: Toast) {
        dismissal?.cancel()
        current = toast
        announce(toast.announcement)
        let shownFor = isVoiceOverRunning() ? voiceOverDuration : duration
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(shownFor))
            guard !Task.isCancelled else { return }
            self?.dismiss(toast.id)
        }
    }

    /// Runs the toast's Undo once and hides it.
    func undo() {
        guard let toast = current else { return }
        dismiss(toast.id)
        toast.undo?()
    }

    func dismiss() {
        dismissal?.cancel()
        current = nil
    }

    private func dismiss(_ id: UUID) {
        guard current?.id == id else { return }
        dismiss()
    }

    /// Speaks the toast at high priority, so the speech of a sheet closing under it does not cut it short.
    static func postAnnouncement(_ text: String) {
        var announcement = AttributedString(text)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }
}
