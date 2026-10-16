import Foundation
import Testing
@testable import MediSave

@MainActor
struct SubmitGuardTests {
    @Test func aDoubleTapRunsTheSubmissionOnce() async throws {
        let rpc = DelayedRPCClient(delay: .milliseconds(150))
        let guardian = SubmitGuard()
        let start: @MainActor () async -> Void = {
            let _: UUID = (try? await rpc.call("stock_procedure_start", params: ["p": "x"])) ?? UUID()
        }

        async let first = guardian.run(start)
        try await Task.sleep(for: .milliseconds(20))
        #expect(guardian.isBusy)
        let second = await guardian.run(start)
        #expect(second == false, "The second tap is ignored while the first is in flight")
        #expect(await first)
        #expect(rpc.callCount == 1)
        #expect(!guardian.isBusy)
    }

    @Test func aTapAfterTheFirstFinishesRunsAgain() async {
        let guardian = SubmitGuard()
        var runs = 0
        await guardian.run { runs += 1 }
        await guardian.run { runs += 1 }
        #expect(runs == 2)
    }
}
