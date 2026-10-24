import Foundation
import Testing
@testable import Dentory

/// The clinic's row decodes into `ClinicSettings`, and `clinic_settings_save`'s arguments go out in snake_case.
struct ClinicSettingsWireTests {
    @Test func theRowDecodes() throws {
        let row = #"""
        {"name": "Smile Dental", "city": null, "country": "CA", "currency": "CAD", "time_zone": "America/Toronto",
         "expiry_thresholds": [60, 90], "email_digest": false, "logo_path": "abc/logo.jpg"}
        """#
        let settings = try JSONDecoder.supabase.decode(ClinicSettings.self, from: Data(row.utf8))
        #expect(settings.city == nil)
        #expect(settings.timeZone == "America/Toronto")
        #expect(settings.expiryThresholds == [60, 90])
        #expect(settings.emailDigest == false)
        #expect(settings.logoPath == "abc/logo.jpg")
    }

    @Test func theSaveSendsSnakeCaseArguments() throws {
        let settings = ClinicSettings(
            name: "Smile Dental", city: nil, country: "CA", currency: "CAD", timeZone: "America/Toronto",
            expiryThresholds: [90], emailDigest: true, logoPath: nil
        )
        let params = ClinicSettingsParams(clinicID: Session.demo.clinicID, settings: settings)
        let data = try JSONEncoder.supabase.encode(params)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == [
            "p_clinic_id", "p_name", "p_city", "p_country", "p_currency", "p_time_zone", "p_expiry_thresholds",
            "p_email_digest"
        ])
        #expect(object["p_city"] as? String == "")
        #expect(object["p_expiry_thresholds"] as? [Int] == [90])
    }
}
