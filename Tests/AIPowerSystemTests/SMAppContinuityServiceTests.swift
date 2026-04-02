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

    @Test
    @MainActor
    func helperStatusLookupRunsOffMainThread() async {
        let service = ThreadRecordingContinuityService()
        let manager = LocalContinuityHelperManager(service: service)

        let status = await manager.status()

        #expect(status == .ready)
        #expect(service.wasCalledOnMainThread == false)
    }

    @Test
    func helperStatusDegradesWhenDaemonClientTimesOut() throws {
        let appBundleURL = try makeTestAppBundle(includePayload: true)
        defer { try? FileManager.default.removeItem(at: appBundleURL.deletingLastPathComponent()) }

        let service = SMAppContinuityService(
            statusProvider: { .enabled },
            daemonClient: TimeoutDaemonClient(),
            bundleURLProvider: { appBundleURL }
        )

        #expect(service.helperStatus() == .degraded(reason: "Unable to reach helper daemon"))
    }

    @Test
    @MainActor
    func helperStatusTimesOutInsteadOfBlockingMonitoring() async {
        let manager = LocalContinuityHelperManager(
            service: HangingContinuityService(),
            statusTimeout: .milliseconds(50)
        )

        let start = ContinuousClock.now
        let status = await manager.status()
        let elapsed = start.duration(to: .now)

        #expect(status == .degraded(reason: "Unable to reach helper daemon"))
        #expect(elapsed < .milliseconds(250))
    }

    @Test
    @MainActor
    func helperDisarmTimesOutInsteadOfBlockingMonitoring() async {
        let manager = LocalContinuityHelperManager(
            service: HangingRestoreContinuityService(),
            statusTimeout: .milliseconds(50)
        )

        let start = ContinuousClock.now
        await manager.apply(intent: .disarm)
        let elapsed = start.duration(to: .now)

        #expect(elapsed < .milliseconds(250))
    }

    @Test
    @MainActor
    func helperInstallTimesOutInsteadOfBlockingMonitoring() async {
        let manager = LocalContinuityHelperManager(
            service: HangingInstallContinuityService(),
            statusTimeout: .milliseconds(50)
        )

        let start = ContinuousClock.now
        let result = await manager.installOrRegister()
        let elapsed = start.duration(to: .now)

        #expect(result.status == .degraded(reason: "Unable to reach helper daemon"))
        #expect(result.message == "Unable to reach helper daemon")
        #expect(elapsed < .milliseconds(250))
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
        .appendingPathComponent(ContinuityXPC.embeddedHelperRelativePath)
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

private final class TimeoutDaemonClient: ContinuityDaemonClient {
    func send(_ request: ContinuityDaemonClientRequest) throws -> ContinuityDaemonReply {
        throw NSError(
            domain: NSCocoaErrorDomain,
            code: NSUserCancelledError,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for helper daemon"]
        )
    }
}

private final class ThreadRecordingContinuityService: ContinuityService {
    private(set) var wasCalledOnMainThread = false

    func registerHelper() throws {}

    func helperStatus() -> HelperStatus {
        wasCalledOnMainThread = Thread.isMainThread
        return .ready
    }

    func applyPortableContinuity(reason: String) throws {}

    func restoreBaselinePolicy() throws {}

    func fetchRecoveryState() throws -> String? { nil }
}

private final class HangingContinuityService: ContinuityService {
    func registerHelper() throws {}

    func helperStatus() -> HelperStatus {
        Thread.sleep(forTimeInterval: 5)
        return .ready
    }

    func applyPortableContinuity(reason: String) throws {}

    func restoreBaselinePolicy() throws {}

    func fetchRecoveryState() throws -> String? { nil }
}

private final class HangingRestoreContinuityService: ContinuityService {
    func registerHelper() throws {}

    func helperStatus() -> HelperStatus { .ready }

    func applyPortableContinuity(reason: String) throws {}

    func restoreBaselinePolicy() throws {
        Thread.sleep(forTimeInterval: 5)
    }

    func fetchRecoveryState() throws -> String? { nil }
}

private final class HangingInstallContinuityService: ContinuityService {
    func registerHelper() throws {
        Thread.sleep(forTimeInterval: 5)
    }

    func helperStatus() -> HelperStatus { .ready }

    func applyPortableContinuity(reason: String) throws {}

    func restoreBaselinePolicy() throws {}

    func fetchRecoveryState() throws -> String? { nil }
}
