import Foundation
import Testing
@testable import Dentory

/// Clinic settings (f33, MS-139): the clinic's fields, Save once something changed, the refusals, the logo, and
/// "Discard changes?" before leaving with changes.
@MainActor
struct ClinicSettingsViewModelTests {
    private func make(_ repository: FakeClinicSettingsRepository = FakeClinicSettingsRepository(),
                      analytics: Analytics = NoopAnalytics(),
                      onSaved: @escaping () async -> Void = {}) async -> ClinicSettingsViewModel {
        let viewModel = ClinicSettingsViewModel(
            clinicID: Session.demo.clinicID, repository: repository, analytics: analytics,
            locale: Locale(identifier: "en_US"), onSaved: onSaved
        )
        await viewModel.load()
        return viewModel
    }

    @Test func theFieldsShowTheClinicAndSaveWaitsForAChange() async {
        let viewModel = await make()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.name == "Smile Dental")
        #expect(viewModel.country?.name == "Canada")
        #expect(viewModel.currency == "CAD")
        #expect(viewModel.timeZone == "America/Toronto")
        #expect(viewModel.expiryWarning == .thirtySixtyNinety)
        #expect(viewModel.emailDigest)
        #expect(viewModel.canSave == false, "Nothing changed yet")
        viewModel.expiryWarning = .ninetyOnly
        #expect(viewModel.canSave)
        viewModel.expiryWarning = .thirtySixtyNinety
        #expect(viewModel.canSave == false, "Back as it was")
    }

    @Test func savingSendsTheFieldsSaysSoAndRefreshesTheSession() async {
        let repository = FakeClinicSettingsRepository()
        let analytics = SpyAnalytics()
        var refreshed = 0
        let viewModel = await make(repository, analytics: analytics, onSaved: { refreshed += 1 })
        viewModel.name = "  Smile Dental Group "
        viewModel.city = "  "
        viewModel.expiryWarning = .sixtyNinety
        viewModel.emailDigest = false
        await viewModel.save()
        let saved = repository.saves.last
        #expect(saved?.name == "Smile Dental Group")
        #expect(saved?.city == nil, "An empty city is cleared")
        #expect(saved?.expiryThresholds == [60, 90])
        #expect(saved?.emailDigest == false)
        #expect(viewModel.message == "Settings saved")
        #expect(refreshed == 1)
        #expect(viewModel.canSave == false, "Saved is the new starting point")
        #expect(analytics.events == [.settingsSaved(digest: false, expiryWarningDays: 60)])
    }

    @Test func aBlankNameAndTheServersRefusalsAreSaid() async {
        let repository = FakeClinicSettingsRepository()
        let analytics = SpyAnalytics()
        let viewModel = await make(repository, analytics: analytics)
        viewModel.name = "   "
        await viewModel.save()
        #expect(viewModel.nameError == "Enter the clinic name")
        #expect(repository.saves.isEmpty)
        viewModel.name = "Smile"
        #expect(viewModel.nameError == nil, "Typing clears it")

        repository.saveFailure = AppError.validation(field: "timeZone", message: "Choose a time zone")
        await viewModel.save()
        #expect(viewModel.generalError?.userMessage == "Choose a time zone")
        repository.saveFailure = AppError.network
        await viewModel.save()
        #expect(viewModel.generalError?.userMessage == "Couldn't save. Try again.", "Not queued, so nothing is retried")
        #expect(viewModel.message == nil)
        #expect(analytics.events.isEmpty, "Only a save that went through counts")
        viewModel.clearGeneralError()
        #expect(viewModel.generalError == nil, "Shown once as a toast")
    }

    /// A logo that fails in the same save as a new name keeps waiting for its retry: the session check, which would
    /// rebuild the screen and drop it, waits for the logo or for the admin to leave (MS-139 review).
    @Test func aFailedLogoHoldsTheSessionCheckUntilItIsInOrTheAdminLeaves() async {
        let repository = FakeClinicSettingsRepository()
        var checks = 0
        let viewModel = await make(repository, onSaved: { checks += 1 })
        viewModel.name = "Smile Dental Group"
        viewModel.logoData = Data("png".utf8)
        repository.logoFailure = AppError.network
        await viewModel.save()
        #expect(repository.saves.last?.name == "Smile Dental Group", "The settings are saved")
        #expect(checks == 0, "Not yet: the rebuild would lose the logo")
        #expect(viewModel.logoData != nil)
        #expect(viewModel.canSave, "Save offers the logo again")
        repository.logoFailure = nil
        await viewModel.save()
        #expect(checks == 1, "Once the logo is in")
        #expect(viewModel.checksSessionOnLeave == false)

        let leaving = await make(repository, onSaved: { checks += 1 })
        leaving.name = "Smile Dental Downtown"
        leaving.logoData = Data("png".utf8)
        repository.logoFailure = AppError.network
        await leaving.save()
        leaving.discard()
        await leaving.leave()
        #expect(checks == 2, "Or when the admin leaves without it")
        await leaving.leave()
        #expect(checks == 2, "Only once")
    }

    @Test func aLogoThatDidNotDownloadIsStillOneToReplace() async {
        let repository = FakeClinicSettingsRepository()
        #expect(await make(repository).logoHint == "Tap to upload.", "No logo yet")
        repository.stored.logoPath = "logos/smile.jpg"
        repository.downloadFailure = AppError.network
        let viewModel = await make(repository)
        #expect(viewModel.logoPreview == nil)
        #expect(viewModel.logoHint == "Tap to replace.")
    }

    @Test func aNameOfMoreThan120CharactersIsNotSent() async {
        let repository = FakeClinicSettingsRepository()
        let viewModel = await make(repository)
        viewModel.name = String(repeating: "a", count: 121)
        await viewModel.save()
        #expect(viewModel.nameError == "Keep the clinic name to 120 characters")
        #expect(repository.saves.isEmpty)
        viewModel.name = String(repeating: "a", count: 120)
        await viewModel.save()
        #expect(repository.saves.count == 1)
    }

    @Test func aPickedLogoIsUploadedOnSaveAndKeptToRetry() async {
        let repository = FakeClinicSettingsRepository()
        let viewModel = await make(repository)
        let logo = Data("png".utf8)
        viewModel.logoData = logo
        #expect(viewModel.canSave)
        #expect(viewModel.logoPreview == logo)
        repository.logoFailure = AppError.network
        await viewModel.save()
        #expect(repository.saves.count == 1, "The settings are saved")
        let logoRefusal = "The settings are saved, the logo is not. Tap Save to try again."
        #expect(viewModel.generalError?.userMessage == logoRefusal)
        #expect(viewModel.canSave, "The logo can be sent again")
        repository.logoFailure = nil
        await viewModel.save()
        #expect(repository.logos == [logo])
        #expect(viewModel.message == "Settings saved")
        #expect(viewModel.logoPreview == logo)
    }

    @Test func leavingWithChangesAsksAndDiscardPutsThemBack() async {
        let viewModel = await make()
        #expect(viewModel.shouldLeave(), "Nothing to lose")
        viewModel.name = "Another name"
        #expect(viewModel.shouldLeave() == false)
        #expect(viewModel.isConfirmingDiscard)
        viewModel.keepEditing()
        #expect(viewModel.isConfirmingDiscard == false)
        #expect(viewModel.name == "Another name", "Keep editing keeps it")
        _ = viewModel.shouldLeave()
        viewModel.discard()
        #expect(viewModel.name == "Smile Dental")
        #expect(viewModel.hasChanges == false)
    }

    @Test func theExpiryWarningReadsAsF33() {
        #expect(ExpiryWarning(thresholds: [90, 60, 30]) == .thirtySixtyNinety)
        #expect(ExpiryWarning(thresholds: [60, 90]).label == "60 and 90 days")
        #expect(ExpiryWarning(thresholds: [90]).label == "90 days only")
        #expect(ExpiryWarning.thirtySixtyNinety.label == "30, 60 and 90 days")
        #expect(ClinicSettingsViewModel.currencies.contains("CAD"))
    }
}
