import Foundation
import Testing
@testable import AIPowerIPC

struct ContinuityXPCContractTests {
    @Test
    func requestPreservesReasonAndAction() {
        let request = ContinuityDaemonRequest(
            action: .armPortableContinuity,
            reason: "python active"
        )

        #expect(request.action == .armPortableContinuity)
        #expect(request.reason == "python active")
    }

    @Test
    func replyPreservesStatusReasonAndRecoveryText() {
        let reply = ContinuityDaemonReply(
            helperStatus: .degraded(reason: "approval pending"),
            recoveryReason: "python active"
        )

        #expect(reply.helperStatus == .degraded(reason: "approval pending"))
        #expect(reply.recoveryReason == "python active")
    }

    @Test
    func machServiceNameIsStable() {
        #expect(ContinuityXPC.machServiceName == "com.aipower.continuity-helper")
    }
}
