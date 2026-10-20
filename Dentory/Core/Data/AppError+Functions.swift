import Foundation
import Supabase

/// The error body every Dentory Edge Function answers with (`supabase/functions/_shared/http.ts`).
nonisolated struct EdgeFunctionErrorBody: Decodable, Sendable {
    struct Detail: Decodable, Sendable {
        let code: String
        let message: String
        let field: String?
    }

    let error: Detail
}

extension AppError {
    /// Maps a failed `functions.invoke`: 401 and 403 are refusals (read-only when the function says so),
    /// 404 and 410 mean the thing is gone, 400 and 409 carry a sentence for the user and the field it names, and so do
    /// 502 and 503 when a service behind the function is down or not set up ("Billing isn't set up yet.").
    init(functionError error: Error) {
        guard case FunctionsError.httpError(let status, let data) = error else {
            self = AppError(error)
            return
        }
        let detail = try? JSONDecoder().decode(EdgeFunctionErrorBody.self, from: data).error
        switch status {
        case 401, 403:
            self = detail?.code == "read_only" ? .readOnly : .forbidden
        case 404, 410:
            self = .notFound
        case 400, 409, 422:
            self = .validation(field: detail?.field, message: detail?.message ?? "Couldn't save. Try again.")
        case 502, 503:
            if let detail {
                self = .validation(field: nil, message: detail.message)
            } else {
                self = .unknown("The server answered \(status)")
            }
        default:
            self = .unknown(detail?.message ?? "The server answered \(status)")
        }
    }
}
