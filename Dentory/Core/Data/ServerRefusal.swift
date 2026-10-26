import Foundation

/// The sentences the database and the Edge Functions refuse with, as people read them (PRD §7: sentence case, a full
/// stop, what to do next; MS-136 audit C-01). The server's own sentence is the key, so its functions, logs and pgTAP
/// tests keep their words. A sentence not listed keeps its words and gets the full stop it lacks ("priya@x.ca is
/// already on the team."); a constraint's own message, which names tables, becomes the save failure.
nonisolated enum ServerRefusal {
    /// What the app shows for `message`.
    static func sentence(for message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if let house = houseCopy[trimmed] { return house }
        if trimmed.isEmpty || trimmed.contains("violates") { return saveFailed }
        guard let last = trimmed.last, !".?!".contains(last) else { return trimmed }
        return trimmed + "."
    }

    static let saveFailed = "Couldn't save. Try again."

    /// The server's sentences that need other words or a capital, then those that only lack the full stop. A sentence
    /// no one can reach from the app (a key the app always sends, a list it always builds) reads as the save failure.
    static let houseCopy: [String: String] = [
        // The stock engine (MS-106) and its later versions.
        "unknown product": "This product no longer exists.",
        "the product is archived": "This product was deleted.",
        "unknown batch": "This batch no longer exists.",
        "unknown open item": "This bottle no longer exists.",
        "the bottle is already finished": "This bottle is already finished.",
        "only multi-use products are opened": "Only multi-use products can be opened.",
        "only a multi-use product of this clinic can be opened": "Only multi-use products can be opened.",
        "Out of stock": "Out of stock.",
        "unknown procedure": "This procedure no longer exists.",
        "the procedure was cancelled": "This procedure was cancelled.",
        "the procedure was already cancelled": "This procedure was already cancelled.",
        "a note is required to cancel": "A note is required to cancel.",
        "a procedure needs a name": "A procedure needs a name.",
        "a quantity cannot be negative": "A quantity cannot be negative.",
        "a count cannot be negative": "A count cannot be negative.",
        "a received quantity must be above 0": "Enter a quantity above 0.",
        "nothing to receive": "Nothing to receive.",
        "the disposed quantity must be between 0 and what the batch holds": "Dispose no more than the batch holds.",
        "the expiry is a month": "Choose an expiry month.",
        "unknown reason": "Choose a reason.",
        "this action cannot be undone": "This change cannot be undone.",
        "already undone": "This change was already undone.",
        "the undo window has passed": "The 10 seconds to undo have passed.",
        "unknown action": "This change no longer exists.",
        "an idempotency key is required": saveFailed,
        // Sign-up, invitations, the team and Clinic settings (MS-111, MS-112, MS-138, MS-139).
        "Enter a valid email": "Enter a valid email address.",
        "Role must be Staff or Admin": "Choose Staff or Admin.",
        "The name is too long": "Use 120 characters or fewer for the name.",
        "Keep the clinic name to 120 characters": "Use 120 characters or fewer for the clinic name.",
        "Unknown time zone": "Choose a time zone.",
        "Enter the clinic name": "Enter the clinic name.",
        "Choose a country": "Choose a country.",
        "Choose a currency": "Choose a currency.",
        "Choose a time zone": "Choose a time zone.",
        "Choose an expiry warning": "Choose an expiry warning.",
        "This account is already on the team": "This account is already on the team.",
        "Invitations must be a list": saveFailed,
        // Billing emails, push and procedures (MS-141, MS-144, MS-125).
        "Up to 10 billing emails": "Add up to 10 billing emails.",
        "The clinic has no admin address": "The clinic has no admin address.",
        "Not a device token": saveFailed,
        "No clinic with this id": saveFailed,
        "Supplies must be a list": saveFailed,
        // Invoices (MS-129, MS-131, MS-146).
        "An invoice has 1 to 20 JPEG pages, or one PDF": "An invoice has 1 to 20 photos, or one PDF.",
        "An invoice is a photo or a file": "An invoice is a photo or a file.",
        "The pages are over 20 MB": "The pages are over 20 MB.",
        "This delivery was already received": "This delivery was already received.",
        "Only a received invoice's file can be deleted": "Only a received invoice's file can be deleted.",
        "A reading needs at least one line": saveFailed
    ]
}

extension AppError {
    /// A refusal the server sent, in the app's words (`ServerRefusal`), under the field it names.
    static func refusal(_ message: String, field: String? = nil) -> AppError {
        .validation(field: field, message: ServerRefusal.sentence(for: message))
    }
}
