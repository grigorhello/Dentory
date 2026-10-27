import Foundation
import Supabase

/// The clinic's logo in Storage, `logos/{clinic_id}/logo.jpg`, as sign-up (MS-111) and Clinic settings (MS-139) keep
/// it: a square JPEG (`LogoImage`), the clinic's `logo_path` pointing at it. The bucket's policy lets members read it.
struct ClinicLogoStorage: Sendable {
    let client: SupabaseClient

    func upload(clinicID: UUID, imageData: Data) async throws {
        guard let jpeg = LogoImage.squareJPEG(from: imageData) else {
            throw AppError.validation(field: "logo", message: "Choose an image file.")
        }
        let path = "\(clinicID.uuidString.lowercased())/logo.jpg"
        do {
            try await client.storage.from("logos").upload(
                path, data: jpeg, options: FileOptions(contentType: LogoImage.contentType, upsert: true)
            )
            // Nothing is sent back: members read only the clinic's columns that are not billing (MS-151).
            try await client.from("clinics").update(["logo_path": path], returning: .minimal)
                .eq("id", value: clinicID.uuidString).execute()
        } catch {
            throw AppError(error)
        }
    }

    func download(path: String) async throws -> Data {
        do {
            return try await client.storage.from("logos").download(path: path)
        } catch {
            throw AppError(error)
        }
    }
}
