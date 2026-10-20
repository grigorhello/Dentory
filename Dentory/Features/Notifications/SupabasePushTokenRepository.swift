import Foundation
import Supabase

/// `push_token_register` and `push_token_remove`, the member's own row in `push_tokens`.
struct SupabasePushTokenRepository: PushTokenRepository {
    let client: SupabaseClient

    func register(token: String) async throws {
        do {
            try await client.rpc("push_token_register", params: ["p_token": token]).execute()
        } catch {
            throw AppError(error)
        }
    }

    func remove(token: String) async throws {
        do {
            try await client.rpc("push_token_remove", params: ["p_token": token]).execute()
        } catch {
            throw AppError(error)
        }
    }
}
