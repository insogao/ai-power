import AIPowerCore
import AIPowerIPC
import Foundation
import Testing
@testable import AIPowerSystem

struct SMAppContinuityServiceTests {
    @Test
    @MainActor
    func helperPreparationMapsInvalidSignatureError() async throws {
        let appBundleURL = try makeTestAppBundle(includePayload: true)
        defer { try? FileManager.default.removeItem(at: appBundleURL.deletingLastPathComponent()) }

        let manager = LocalContinuityHelperManager(
            service: SMAppContinuityService(
                registerHandler: {
                    throw NSError(
                        domain: "SMAppServiceErrorDomain",
                        code: 3,
                        userInfo: nil
                    )
                },
                statusProvider: { .notRegistered },
                daemonClient: RecordingDaemonClient(),
                bundleURLProvider: { appBundleURL }
            )
        )

        let result = await manager.installOrRegister()

        #expect(result.status == HelperStatus.degraded(reason: "App signature is invalid for helper registration. Build and run the signed AI Power.app bundle from Xcode."))
        #expect(result.message == "App signature is invalid for helper registration. Build and run the signed AI Power.app bundle from Xcode.")
    }

    @Test
    @MainActor
    func helperPreparationMapsApprovalFlow() async throws {
        let appBundleURL = try makeTestAppBundle(includePayload: true)
        defer { try? FileManager.default.removeItem(at: appBundleURL.deletingLastPathComponent()) }

        let manager = LocalContinuityHelperManager(
            service: SMAppContinuityService(
                registerHandler: {},
                statusProvider: { .requiresApproval },
                daemonClient: RecordingDaemonClient(),
                bundleURLProvider: { appBundleURL }
            )
        )

        let result = await manager.installOrRegister()

        #expect(result.status == .requiresApproval)
        #expect(result.message == "Approve AI Power in System Settings > Login Items & Extensions.")
    }

    @Test
    func helperStatusMapsRegistrationStates() throws {
        let appBundleURL = try makeTestAppBundle(includePayload: true)
        defer { try? FileManager.default.removeItem(at: appBundleURL.deletingLastPathComponent()) }

        let service = SMAppContinuityService(
            statusProvider: { .requiresApproval },
            daemonClient: RecordingDaemonClient(),
            bundleURLProvider: { appBundleURL }
        )

        #expect(service.helperStatus() == .requiresApproval)
    }

    @Test
    func armRoutesThroughDaemonClient() throws {
        let client = RecordingDaemonClient()
        let service = SMAppContinuityService(
            statusProvider: { .enabled },
            daemonClient: client
        )

        try service.applyPortableContinuity(reason: "python active")

        #expect(client.requests == [.armPortableContinuity(reason: "python active")])
    }

    @Test
    func restoreAndRecoveryUseDaemonClient() throws {
        let client = RecordingDaemonClient(recoveryReason: "python active")
        let service = SMAppContinuityService(
            statusProvider: { .enabled },
            daemonClient: client
        )

        try service.restoreBaselinePolicy()
        let recoveryReason = try service.fetchRecoveryState()

        #expect(client.requests == [.restoreBaseline, .fetchRecoveryState])
        #expect(recoveryReason == "python active")
    }

    @Test
    func helperStatusDegradesWhenNotRunningFromAppBundle() {
        let service = SMAppContinuityService(
            registerHandler: {},
            statusProvider: { .notRegistered },
            daemonClient: RecordingDaemonClient(),
            bundleURLProvider: { URL(fileURLWithPath: "/tmp/AIPowerExecutable") }
        )

        #expect(
            service.helperStatus() == .degraded(
                reason: "AI Continuity helper can only be installed from the signed AI Power.app bundle."
            )
        )
    }

    @Test
    @MainActor
    func helperPreparationRejectsMissingEmbeddedPayload() async throws {
        let appBundleURL = try makeTestAppBundle(includePayload: false)
        defer { try? FileManager.default.removeItem(at: appBundleURL.deletingLastPathComponent()) }

        let manager = LocalContinuityHelperManager(
            service: SMAppContinuityService(
                registerHandler: {},
                statusProvider: { .notRegistered },
                daemonClient: RecordingDaemonClient(),
                bundleURLProvider: { appBundleURL }
            )
        )

        let result = await manager.installOrRegister()

        #expect(result.status == .degraded(reason: "Embedded helper payload is missing from the running app bundle."))
        #expect(result.message == "Embedded helper payload is missing from the running app bundle.")
    }
}

private func makeTestAppBundle(includePayload: Bool) throws -> URL {
    let rootURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let appBundleURL = rootURL.appendingPathComponent("AI Power.app", isDirectory: true)
    try FileManager.default.createDirectory(at: appBundleURL, withIntermediateDirectories: true)

    guard includePayload else {
        return appBundleURL
    }

    let helperURL = appBundleURL
        .appendingPathComponent("Contents", isDirectory: true)
        .appendingPathComponent("Helpers", isDirectory: true)
        .appendingPathComponent("AIPowerContinuityHelper")
    let daemonPlistURL = appBundleURL
        .appendingPathComponent("Contents", isDirectory: true)
        .appendingPathComponent("Library", isDirectory: true)
        .appendingPathComponent("LaunchDaemons", isDirectory: true)
        .appendingPathComponent(ContinuityXPC.launchDaemonPlistName)

    try FileManager.default.createDirectory(
        at: helperURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: daemonPlistURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data().write(to: helperURL)
    try Data().write(to: daemonPlistURL)

    return appBundleURL
}

private final class RecordingDaemonClient: ContinuityDaemonClient {
    private(set) var requests: [ContinuityDaemonClientRequest] = []
    private let recoveryReason: String?

    init(recoveryReason: String? = nil) {
        self.recoveryReason = recoveryReason
    }

    func send(_ request: ContinuityDaemonClientRequest) throws -> ContinuityDaemonReply {
        requests.append(request)
        return ContinuityDaemonReply(
            helperStatus: .ready,
            recoveryReason: recoveryReason
        )
    }
}
