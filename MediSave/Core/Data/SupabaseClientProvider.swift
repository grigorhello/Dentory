import Foundation
import Supabase

/// Builds the one `SupabaseClient` from the values the xcconfig put into Info.plist
/// (`SUPABASE_URL`, `SUPABASE_ANON_KEY`; the local stack for Debug, the hosted project for Release).
nonisolated enum SupabaseClientProvider {
    static func makeClient(bundle: Bundle = .main) -> SupabaseClient {
        guard
            let urlString = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: urlString),
            let key = bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !key.isEmpty
        else {
            preconditionFailure("SUPABASE_URL and SUPABASE_ANON_KEY must be set in Config/*.xcconfig")
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }
}
