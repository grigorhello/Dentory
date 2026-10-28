import Foundation
import Supabase

/// Builds the one `SupabaseClient` from the values the xcconfig put into Info.plist
/// (`SUPABASE_URL`, `SUPABASE_ANON_KEY`; the local stack for Debug, the hosted project for Release).
nonisolated enum SupabaseClientProvider {
    static func makeClient(bundle: Bundle = .main) -> SupabaseClient {
        let (url, key) = project(bundle: bundle)
        return SupabaseClient(supabaseURL: url, supabaseKey: key, options: options)
    }

    /// A client for one password reset link (MS-113): its session lives in memory and is never refreshed, so opening
    /// the link leaves the session stored on the device as it is (security review F4).
    static func makeLinkClient(bundle: Bundle = .main) -> SupabaseClient {
        let (url, key) = project(bundle: bundle)
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(auth: .init(storage: InMemoryAuthStorage(), autoRefreshToken: false))
        )
    }

    private static func project(bundle: Bundle) -> (url: URL, key: String) {
        guard
            let urlString = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: urlString),
            let key = bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !key.isEmpty
        else {
            preconditionFailure("SUPABASE_URL and SUPABASE_ANON_KEY must be set in Config/*.xcconfig")
        }
        return (url, key)
    }

    /// PostgREST rows are snake_case and carry ISO 8601 instants and `date` columns; the app's own
    /// encoder and decoder handle both, the package's defaults do not convert the keys.
    static var options: SupabaseClientOptions {
        SupabaseClientOptions(db: .init(encoder: JSONEncoder.supabase, decoder: JSONDecoder.supabase))
    }
}
