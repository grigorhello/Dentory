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
    /// 404 and 410 mean the thing is gone, 400 and 409 carry a sentence for the user (in the app's words,
    /// `ServerRefusal`) and the field it names.
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
            self = .refusal(detail?.message ?? ServerRefusal.saveFailed, field: detail?.field)
        default:
            self = .unknown(detail?.message ?? "The server answered \(status)")
        }
    }
}
