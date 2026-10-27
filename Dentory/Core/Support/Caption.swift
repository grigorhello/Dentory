import Foundation

/// Captions join their parts with " · " (PRD §7) and write a no-break space before the dot, so a caption that wraps
/// never starts a line with it (MS-136 audit V-16): "54 cartridges · Anesthetic". Buttons and segments, which never
/// wrap, keep the plain space ("Start procedure · 6 items").
nonisolated enum Caption {
    /// " · " with a no-break space before the dot.
    static let separator = "\u{00A0}· "

    /// The parts that are not nil or empty, joined by `separator`; each part keeps its own separators on their line
    /// too (`attached(_:)`), such as a location typed as "Operatory 1 · Drawer A".
    static func joined(_ parts: [String?]) -> String {
        parts.compactMap { part in part.flatMap { $0.isEmpty ? nil : attached($0) } }.joined(separator: separator)
    }

    /// `joined(_:)` for parts written out: `Caption.joined(product.name, quantity)`.
    static func joined(_ parts: String?...) -> String {
        joined(parts)
    }

    /// Text that a person typed or the server sent ("Operatory 1 · Drawer A", the engine's "Undo · Damaged") with the
    /// no-break space before each of its dots, so it wraps like the captions the app writes.
    static func attached(_ text: String) -> String {
        text.replacing(" · ", with: separator)
    }
}
