import Foundation
import Observation

/// Clinic settings (f33, PRD §6.9, MS-100 D8 and D14, Admin only): the logo, name, city and country, the currency and
/// time zone, the expiry warning and the weekly email digest. Save in the header is on once something changed and
/// says "Settings saved"; leaving with changes asks first. A new expiry warning or time zone moves the clinic's
/// expiry alerts at once (`clinic_settings_save`).
@MainActor
@Observable
final class ClinicSettingsViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    var name = "" {
        didSet { if name != oldValue { nameError = nil } }
    }
    var city = ""
    var country: Country?
    var currency: String?
    var timeZone: String?
    var expiryWarning: ExpiryWarning? = .thirtySixtyNinety
    var emailDigest = true
    /// A logo picked here, uploaded on Save.
    var logoData: Data?
    /// The logo the clinic has.
    private(set) var savedLogo: Data?

    private(set) var state: LoadState = .loading
    private(set) var nameError: String?
    /// A refusal that belongs to no field: a toast, the fields keeping what was typed (PRD §7).
    private(set) var generalError: AppError?
    private(set) var isSaving = false
    var isConfirmingDiscard = false
    /// "Settings saved": a toast the screen shows once.
    private(set) var message: String?

    let countries: [Country]
    let timeZones: [String]
    private var saved: ClinicSettings?
    private let clinicID: UUID
    private let repository: ClinicSettingsRepository
    private let onSaved: () async -> Void

    init(
        clinicID: UUID, repository: ClinicSettingsRepository, locale: Locale = .current,
        onSaved: @escaping () async -> Void = {}
    ) {
        self.clinicID = clinicID
        self.repository = repository
        self.onSaved = onSaved
        countries = Country.all(locale: locale)
        timeZones = TimeZone.knownTimeZoneIdentifiers.sorted()
    }

    /// The codes `currency_for_country` gives at sign-up (MS-111), any of which the admin may choose.
    static let currencies = [
        "AED", "AMD", "AUD", "BRL", "CAD", "CHF", "CNY", "CZK", "DKK", "EUR", "GBP", "GEL", "HKD", "HUF", "ILS", "INR",
        "JPY", "KRW", "MXN", "NOK", "NZD", "PLN", "RON", "SEK", "SGD", "TRY", "USD", "ZAR"
    ]

    /// Once, on appear: a reload would throw away what is being typed.
    func load() async {
        guard saved == nil else { return }
        do {
            let settings = try await repository.settings(clinicID: clinicID)
            show(settings)
            state = .loaded
            if let path = settings.logoPath {
                savedLogo = try? await repository.logo(path: path)
            }
        } catch {
            state = .failed(AppError(error))
        }
    }

    /// What the fields hold, as the server saves it.
    private var edited: ClinicSettings? {
        guard let saved, let country, let currency, let timeZone, let expiryWarning else { return nil }
        return ClinicSettings(
            name: name.trimmingCharacters(in: .whitespaces),
            city: city.trimmingCharacters(in: .whitespaces).isEmpty ? nil : city.trimmingCharacters(in: .whitespaces),
            country: country.code, currency: currency, timeZone: timeZone,
            expiryThresholds: expiryWarning.thresholds, emailDigest: emailDigest, logoPath: saved.logoPath
        )
    }

    var hasChanges: Bool {
        guard let saved else { return false }
        return edited != saved || logoData != nil
    }

    var canSave: Bool {
        hasChanges && !isSaving
    }

    /// The logo the picker shows: the one picked here, else the clinic's.
    var logoPreview: Data? {
        logoData ?? savedLogo
    }

    /// "Tap to replace." under a logo (PRD Appendix B `settings.logo`), even one that did not download; "Tap to
    /// upload." without one.
    var logoHint: String {
        logoPreview == nil && saved?.logoPath == nil ? "Tap to upload." : "Tap to replace."
    }

    /// The longest name the server keeps (`clinic_settings_save`).
    static let nameLimit = 120

    func save() async {
        guard canSave, let edited else { return }
        guard !edited.name.isEmpty else {
            nameError = "Enter the clinic name"
            return
        }
        guard edited.name.count <= Self.nameLimit else {
            nameError = "Keep the clinic name to 120 characters"
            return
        }
        isSaving = true
        generalError = nil
        defer { isSaving = false }
        do {
            try await repository.save(clinicID: clinicID, settings: edited)
        } catch {
            handle(AppError(error))
            return
        }
        saved = edited
        if let logoData {
            do {
                try await repository.uploadLogo(clinicID: clinicID, imageData: logoData)
                savedLogo = logoData
                self.logoData = nil
            } catch {
                // The settings are saved; the logo stays picked so Save can try it again.
                generalError = .validation(
                    field: "logo", message: "The settings are saved, the logo is not. Tap Save to try again."
                )
                await onSaved()
                return
            }
        }
        message = "Settings saved"
        await onSaved()
    }

    /// Back: leaves at once without changes; with them, asks "Discard changes?" first.
    func shouldLeave() -> Bool {
        guard hasChanges else { return true }
        isConfirmingDiscard = true
        return false
    }

    func discard() {
        if let saved { show(saved) }
        logoData = nil
        isConfirmingDiscard = false
    }

    func keepEditing() {
        isConfirmingDiscard = false
    }

    func clearMessage() {
        message = nil
    }

    func clearGeneralError() {
        generalError = nil
    }

    private func show(_ settings: ClinicSettings) {
        saved = settings
        name = settings.name
        city = settings.city ?? ""
        country = countries.first { $0.code == settings.country }
            ?? Country(code: settings.country, name: settings.country)
        currency = settings.currency
        timeZone = settings.timeZone
        expiryWarning = ExpiryWarning(thresholds: settings.expiryThresholds)
        emailDigest = settings.emailDigest
    }

    /// The server names the field it refuses. Saving is not queued, so no connection reads as a failed save (PRD §7).
    private func handle(_ error: AppError) {
        switch error {
        case .validation(field: "name", let message):
            nameError = message
        case .network:
            generalError = .unknown("No connection")
        default:
            generalError = error
        }
    }
}
