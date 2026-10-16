import Foundation
import SwiftUI

/// The composition root: one instance of each shared service, built once in `MediSaveApp` (live) or in
/// previews and tests (fakes). Views read it from the environment and hand their view model what it needs.
/// Feature repositories are added here by their own tickets.
struct AppDependencies: Sendable {
    let rpc: RPCCalling
    let auth: AuthServicing
    let clock: Clock
    let networkMonitor: NetworkMonitoring

    /// Formatters for the signed-in clinic.
    func formatters(for session: Session) -> ClinicFormatters {
        ClinicFormatters(
            currency: session.currency,
            timeZone: TimeZone(identifier: session.timeZone) ?? .current,
            clock: clock
        )
    }

    @MainActor
    static func live() -> AppDependencies {
        let client = SupabaseClientProvider.makeClient()
        return AppDependencies(
            rpc: SupabaseRPCClient(transport: SupabaseRPCTransport(client: client)),
            auth: SupabaseAuthService(client: client),
            clock: SystemClock(),
            networkMonitor: NetworkMonitor()
        )
    }

    /// No network: a demo clinic, a signed-in admin and a fixed moment, for previews and UI tests.
    @MainActor
    static func preview(signedIn: Bool = true) -> AppDependencies {
        AppDependencies(
            rpc: PreviewRPCClient(),
            auth: PreviewAuthService(session: signedIn ? .demo : nil),
            clock: FixedClock(Session.demoNow),
            networkMonitor: FixedNetworkMonitor()
        )
    }
}

private struct AppDependenciesKey: EnvironmentKey {
    static let defaultValue = AppDependencies.preview()
}

extension EnvironmentValues {
    var appDependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}

// MARK: - Preview doubles

extension Session {
    /// Thursday, October 2, 9:41, the moment every frame shows.
    nonisolated static let demoNow = Date(timeIntervalSince1970: 1_790_933_260)

    nonisolated static let demo = Session(
        userID: UUID(uuidString: "00000000-0000-4000-8000-0000000000a1") ?? UUID(),
        email: "michael@smiledental.test",
        fullName: "Michael",
        clinicID: UUID(uuidString: "00000000-0000-4000-8000-0000000000c1") ?? UUID(),
        clinicName: "Smile Dental",
        role: .admin,
        currency: "USD",
        timeZone: "America/New_York"
    )
}

/// Answers every function with an empty object; feature previews swap in their own fakes.
struct PreviewRPCClient: RPCCalling {
    func call<Params: Encodable & Sendable, Result: Decodable & Sendable>(
        _ function: String,
        params: Params,
        idempotencyKey: UUID?
    ) async throws -> Result {
        if let empty = try? JSONDecoder.supabase.decode(Result.self, from: Data("{}".utf8)) {
            return empty
        }
        throw AppError.unknown("No preview data for \(function)")
    }
}

struct PreviewAuthService: AuthServicing {
    var session: Session?

    func restore() async throws -> Session? { session }
    func signIn(email: String, password: String) async throws -> Session { session ?? .demo }
    func signOut() async throws {}
}
