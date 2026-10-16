import Foundation
import Supabase
import Testing
@testable import MediSave

@MainActor
struct WriteCoordinatorTests {
    private nonisolated struct AdjustParams: Encodable, Sendable {
        let pProductId: UUID
        let pActualQty: Decimal
        let pReason: String
    }

    private static let actionJSON = Data("\"00000000-0000-4000-8000-000000000009\"".utf8)
    private let productID = UUID()

    private func makeCoordinator(
        rpc: RPCCalling,
        network: FixedNetworkMonitor,
        store: PendingWriteStoring = InMemoryPendingWriteStore(),
        toasts: ToastCenter? = nil
    ) -> WriteCoordinator {
        WriteCoordinator(
            rpc: rpc,
            queue: PendingWriteQueue(store: store),
            networkMonitor: network,
            clock: FixedClock(Session.demoNow),
            reporter: NoopErrorReporter(),
            toasts: toasts
        )
    }

    @Test func onlineWritesGoStraightToTheServer() async throws {
        let rpc = FakeRPCClient(results: [.success(Self.actionJSON)])
        let coordinator = makeCoordinator(rpc: rpc, network: FixedNetworkMonitor(isConnected: true))
        let outcome = try await coordinator.write(
            "stock_adjust", params: AdjustParams(pProductId: productID, pActualQty: 28, pReason: "Damaged")
        )
        #expect(outcome == .applied(actionID: UUID(uuidString: "00000000-0000-4000-8000-000000000009")))
        #expect(rpc.calls.count == 1)
        #expect(coordinator.queue.isEmpty)
    }

    @Test func offlineWritesAreQueuedOnceAndReplayedOnceWithTheSameKey() async throws {
        let rpc = FakeRPCClient(results: [.success(Self.actionJSON)])
        let network = FixedNetworkMonitor(isConnected: false)
        let coordinator = makeCoordinator(rpc: rpc, network: network)
        let key = UUID()

        let outcome = try await coordinator.write(
            "stock_adjust", params: AdjustParams(pProductId: productID, pActualQty: 28, pReason: "Damaged"),
            idempotencyKey: key
        )
        #expect(outcome == .queued)
        #expect(rpc.calls.isEmpty)
        #expect(coordinator.queue.count == 1)
        #expect(coordinator.queue.writes.first?.idempotencyKey == key)

        await coordinator.replay()
        #expect(rpc.calls.isEmpty, "No replay while offline")

        network.isConnected = true
        await coordinator.replay()
        await coordinator.replay()
        #expect(rpc.calls.count == 1)
        #expect(rpc.calls.first?.function == "stock_adjust")
        #expect(rpc.calls.first?.idempotencyKey == key)
        #expect(rpc.calls.first?.params["p_reason"] == "Damaged")
        #expect(coordinator.queue.isEmpty)
    }

    @Test func aNetworkErrorWhileOnlineQueuesTheWrite() async throws {
        let rpc = FakeRPCClient(results: [.failure(URLError(.notConnectedToInternet))])
        let coordinator = makeCoordinator(rpc: rpc, network: FixedNetworkMonitor(isConnected: true))
        let outcome = try await coordinator.write("bottle_open", params: ["p_product_id": productID.uuidString])
        #expect(outcome == .queued)
        #expect(coordinator.queue.count == 1)
    }

    @Test func aRefusedWriteThrowsTheAppError() async {
        let refusal = PostgrestError(code: "42501", message: "only an admin can do this")
        let rpc = FakeRPCClient(results: [.failure(refusal)])
        let coordinator = makeCoordinator(rpc: rpc, network: FixedNetworkMonitor(isConnected: true))
        await #expect(throws: AppError.forbidden) {
            _ = try await coordinator.write("stock_adjust", params: ["p": "x"])
        }
        #expect(coordinator.queue.isEmpty)
    }

    @Test func aReplayRefusedByTheServerDropsTheWriteAndToasts() async throws {
        let rpc = FakeRPCClient(results: [.failure(PostgrestError(code: "22023", message: "a note is required"))])
        let network = FixedNetworkMonitor(isConnected: false)
        let toasts = ToastCenter(duration: 60)
        let coordinator = makeCoordinator(rpc: rpc, network: network, toasts: toasts)
        _ = try await coordinator.write("stock_procedure_cancel", params: ["p_event_id": UUID().uuidString])
        network.isConnected = true
        await coordinator.replay()
        #expect(coordinator.queue.isEmpty)
        #expect(coordinator.lastReplayError == .validation(field: nil, message: "a note is required"))
        #expect(toasts.current?.title == WriteCoordinator.saveFailedMessage)
    }

    @Test func aRefusedReplayDropsThatWriteAndCarriesOn() async throws {
        let rpc = FakeRPCClient(results: [
            .failure(PostgrestError(code: "22023", message: "a note is required")), .success(Self.actionJSON)
        ])
        let network = FixedNetworkMonitor(isConnected: false)
        let toasts = ToastCenter(duration: 60)
        let coordinator = makeCoordinator(rpc: rpc, network: network, toasts: toasts)
        _ = try await coordinator.write("stock_procedure_cancel", params: ["n": "1"])
        _ = try await coordinator.write("bottle_open", params: ["n": "2"])
        network.isConnected = true
        await coordinator.replay()
        #expect(rpc.calls.map(\.function) == ["stock_procedure_cancel", "bottle_open"])
        #expect(coordinator.queue.isEmpty)
        #expect(coordinator.lastReplayError == .validation(field: nil, message: "a note is required"))
        #expect(toasts.current?.title == WriteCoordinator.saveFailedMessage)
    }

    @Test func aWriteMadeWhileOlderOnesWaitJoinsTheQueueInOrder() async throws {
        let rpc = FakeRPCClient(results: [.success(Self.actionJSON), .success(Self.actionJSON)])
        let network = FixedNetworkMonitor(isConnected: false)
        let coordinator = makeCoordinator(rpc: rpc, network: network)
        _ = try await coordinator.write("stock_adjust", params: ["p_actual_qty": "28"])
        network.isConnected = true
        let outcome = try await coordinator.write("stock_adjust", params: ["p_actual_qty": "30"])
        #expect(outcome == .queued, "The newer write waits behind the queued one")
        for _ in 0..<50 where !coordinator.queue.isEmpty {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(rpc.calls.map { $0.params["p_actual_qty"] ?? "" } == ["28", "30"])
        #expect(coordinator.queue.isEmpty)
    }

    @Test func aReplayThatLosesTheNetworkKeepsTheRestInOrder() async throws {
        let rpc = FakeRPCClient(results: [.success(Self.actionJSON), .failure(URLError(.timedOut))])
        let network = FixedNetworkMonitor(isConnected: false)
        let coordinator = makeCoordinator(rpc: rpc, network: network)
        _ = try await coordinator.write("first", params: ["n": "1"])
        _ = try await coordinator.write("second", params: ["n": "2"])
        _ = try await coordinator.write("third", params: ["n": "3"])
        network.isConnected = true
        await coordinator.replay()
        #expect(rpc.calls.map(\.function) == ["first", "second"])
        #expect(coordinator.queue.writes.map(\.function) == ["second", "third"])
    }

    @Test func theQueueSurvivesARelaunch() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ms108-\(UUID().uuidString)")
        let fileURL = directory.appending(path: "pending-writes.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let key = UUID()

        let first = makeCoordinator(
            rpc: FakeRPCClient(), network: FixedNetworkMonitor(isConnected: false),
            store: FilePendingWriteStore(fileURL: fileURL)
        )
        _ = try await first.write(
            "stock_adjust", params: AdjustParams(pProductId: productID, pActualQty: 28, pReason: "Damaged"),
            idempotencyKey: key
        )

        let rpc = FakeRPCClient(results: [.success(Self.actionJSON)])
        let relaunched = makeCoordinator(
            rpc: rpc, network: FixedNetworkMonitor(isConnected: true), store: FilePendingWriteStore(fileURL: fileURL)
        )
        #expect(relaunched.queue.writes.map(\.idempotencyKey) == [key])
        #expect(relaunched.queue.writes.first?.params["p_product_id"] == .string(productID.uuidString))
        await relaunched.replay()
        #expect(rpc.calls.first?.idempotencyKey == key)
        #expect(relaunched.queue.isEmpty)
        #expect(FilePendingWriteStore(fileURL: fileURL).load().isEmpty)
    }

    @Test func watchingTheNetworkReplaysWhenItReturns() async throws {
        let rpc = FakeRPCClient(results: [.success(Self.actionJSON)])
        let network = FixedNetworkMonitor(isConnected: false)
        let coordinator = makeCoordinator(rpc: rpc, network: network)
        _ = try await coordinator.write("stock_adjust", params: ["p": "x"])
        coordinator.startWatchingNetwork()
        defer { coordinator.stopWatchingNetwork() }
        network.isConnected = true
        for _ in 0..<50 where !coordinator.queue.isEmpty {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(rpc.calls.count == 1)
        #expect(coordinator.queue.isEmpty)
    }
}
