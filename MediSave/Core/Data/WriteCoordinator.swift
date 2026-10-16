import Foundation
import Observation
import Supabase

/// What a write came to: applied on the server now, or queued until the device is back online.
nonisolated enum WriteOutcome: Equatable, Sendable {
    /// The server applied it; stock RPCs return the action id, used for Undo (MS-100 D10).
    case applied(actionID: UUID?)
    /// Stored in `PendingWriteQueue`; replayed with the same idempotency key when online.
    case queued
}

/// The one door for stock writes from view models: sends through `RPCCalling` when online, queues when
/// offline, replays the queue in order when the connection returns, and reports failures as toasts.
@MainActor
@Observable
final class WriteCoordinator {
    private(set) var isReplaying = false
    /// Set when a replay failed; the view model or the shell shows "Couldn't save. Try again.".
    private(set) var lastReplayError: AppError?

    private let rpc: RPCCalling
    let queue: PendingWriteQueue
    private let networkMonitor: NetworkMonitoring
    private let clock: Clock
    private let reporter: ErrorReporting
    private let toasts: ToastCenter?
    private var isWatching = false

    init(
        rpc: RPCCalling,
        queue: PendingWriteQueue,
        networkMonitor: NetworkMonitoring,
        clock: Clock,
        reporter: ErrorReporting,
        toasts: ToastCenter? = nil
    ) {
        self.rpc = rpc
        self.queue = queue
        self.networkMonitor = networkMonitor
        self.clock = clock
        self.reporter = reporter
        self.toasts = toasts
    }

    var isOnline: Bool { networkMonitor.isConnected }

    /// Sends a stock RPC, or queues it while offline. Errors other than the network are thrown as `AppError`.
    func write<Params: Encodable & Sendable>(
        _ function: String,
        params: Params,
        idempotencyKey: UUID = UUID()
    ) async throws -> WriteOutcome {
        let object = try Self.jsonObject(from: params)
        guard isOnline else {
            _ = queue.enqueue(function: function, params: object, key: idempotencyKey, at: clock.now)
            return .queued
        }
        do {
            let result: AnyJSON = try await rpc.call(function, params: object, idempotencyKey: idempotencyKey)
            return .applied(actionID: Self.actionID(from: result))
        } catch {
            let appError = AppError(error)
            guard appError != .network else {
                _ = queue.enqueue(function: function, params: object, key: idempotencyKey, at: clock.now)
                return .queued
            }
            reporter.record(appError, function: function)
            throw appError
        }
    }

    /// Replays the queue oldest first with the keys it was given. Stops at the first failure: a network
    /// error keeps the write for the next attempt; any other refusal drops it and shows the save toast.
    func replay() async {
        guard !isReplaying, !queue.isEmpty, isOnline else { return }
        isReplaying = true
        defer { isReplaying = false }
        lastReplayError = nil
        for write in queue.writes {
            do {
                let _: AnyJSON = try await rpc.call(write.function, params: write.params, idempotencyKey: write.id)
                queue.remove(write.id)
            } catch {
                let appError = AppError(error)
                reporter.record(appError, function: write.function)
                if appError != .network {
                    queue.remove(write.id)
                    lastReplayError = appError
                    toasts?.show(AppError.unknown("").userMessage)
                }
                return
            }
        }
    }

    /// Replays whenever the monitor reports a connection; call once from the app.
    func startWatchingNetwork() {
        isWatching = true
        observeNetwork()
        if isOnline { Task { await replay() } }
    }

    func stopWatchingNetwork() {
        isWatching = false
    }

    /// Registers for the next change of `isConnected`; the change hops to the main actor, re-registers
    /// and replays when the device is back online.
    private func observeNetwork() {
        withObservationTracking {
            _ = networkMonitor.isConnected
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isWatching else { return }
                self.observeNetwork()
                if self.isOnline { await self.replay() }
            }
        }
    }

    private static func jsonObject(from params: some Encodable) throws -> [String: AnyJSON] {
        let data = try JSONEncoder.supabase.encode(params)
        guard case .object(let object) = try JSONDecoder.supabase.decode(AnyJSON.self, from: data) else {
            throw AppError.unknown("Function parameters must be an object")
        }
        return object
    }

    private static func actionID(from result: AnyJSON) -> UUID? {
        if case .string(let text) = result { return UUID(uuidString: text) }
        return nil
    }
}
