import Foundation
import Observation

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

    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.detail == rhs.detail && lhs.hasUndo == rhs.hasUndo
    }
}

/// Shows one toast at a time for 3.2 s; a new one replaces the old. Lives in `AppDependencies`.
@MainActor
@Observable
final class ToastCenter {
    static let defaultDuration: TimeInterval = 3.2

    private(set) var current: Toast?
    /// Height of the pinned primary bar on screen, so the toast floats above it (0 when there is none).
    var bottomInset: CGFloat = 0
    private let duration: TimeInterval
    private var dismissal: Task<Void, Never>?

    init(duration: TimeInterval = ToastCenter.defaultDuration) {
        self.duration = duration
    }

    func show(_ title: String, detail: String? = nil, undo: (@MainActor () -> Void)? = nil) {
        show(Toast(title: title, detail: detail, undo: undo))
    }

    func show(_ toast: Toast) {
        dismissal?.cancel()
        current = toast
        dismissal = Task { [weak self, duration] in
            try? await Task.sleep(for: .seconds(duration))
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
}
