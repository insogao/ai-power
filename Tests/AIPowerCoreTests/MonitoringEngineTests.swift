import Foundation
import Testing
@testable import AIPowerCore

@MainActor
struct MonitoringEngineTests {
    @Test
    func tickSamplesProviderAndPublishesOutcome() async throws {
        let sampler = SequenceSampler([
            MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: [],
                activeApplicationKeywords: [],
                listeningPorts: []
            )
        ])
        let controller = RecordingSleepAssertionController()
        let helper = RecordingContinuityHelperController()
        let engine = MonitoringEngine(
            sampler: sampler,
            assertionController: controller,
            continuityEnvironmentProvider: StaticContinuityEnvironmentProvider(
                environment: ContinuityEnvironment(
                    hardwareClass: .desktop,
                    powerSource: .ac,
                    helperStatus: .ready,
                    isClamshellClosed: false
                )
            ),
            continuityHelperController: helper
        )

        let state = try await engine.tick()

        #expect(state.outcome.shouldPreventSleep == false)
        #expect(engine.state.outcome.shouldPreventSleep == false)
        #expect(await sampler.currentSampleCount() == 1)
        #expect(controller.appliedIntents == [.allowIdleSleep])
        #expect(helper.appliedIntents == [.disarm])
    }

    @Test
    func tickAppliesAssertionOnlyWhenDesiredStateChanges() async throws {
        let sampler = SequenceSampler([
            MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: [],
                activeApplicationKeywords: [],
                listeningPorts: []
            ),
            MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: ["codex"],
                activeApplicationKeywords: ["codex"],
                listeningPorts: []
            ),
            MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: ["codex"],
                activeApplicationKeywords: ["codex"],
                listeningPorts: []
            )
        ])
        let controller = RecordingSleepAssertionController()
        let helper = RecordingContinuityHelperController()
        let engine = MonitoringEngine(
            sampler: sampler,
            assertionController: controller,
            continuityEnvironmentProvider: StaticContinuityEnvironmentProvider(
                environment: ContinuityEnvironment(
                    hardwareClass: .desktop,
                    powerSource: .ac,
                    helperStatus: .ready,
                    isClamshellClosed: false
                )
            ),
            continuityHelperController: helper
        )

        engine.mode = .developer

        _ = try await engine.tick()
        _ = try await engine.tick()
        _ = try await engine.tick()

        #expect(controller.appliedIntents == [
            .allowIdleSleep,
            .preventSleep(.init(
                reason: "codex active",
                preventDisplaySleep: false,
                declareUserActivity: false
            )),
        ])
        #expect(helper.appliedIntents == [.disarm, .inactive])
    }

    @Test
    func aiContinuityArmsHelperForPortableACWorkload() async throws {
        let sampler = SequenceSampler([
            MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: ["codex"],
                activeApplicationKeywords: ["codex"],
                listeningPorts: []
            )
        ])
        let controller = RecordingSleepAssertionController()
        let helper = RecordingContinuityHelperController()
        let engine = MonitoringEngine(
            mode: .developer,
            continuityMode: .aiContinuity,
            sampler: sampler,
            assertionController: controller,
            continuityEnvironmentProvider: StaticContinuityEnvironmentProvider(
                environment: ContinuityEnvironment(
                    hardwareClass: .portable,
                    powerSource: .ac,
                    helperStatus: .ready,
                    isClamshellClosed: true
                )
            ),
            continuityHelperController: helper
        )

        let state = try await engine.tick()

        #expect(state.executionPolicy.helperIntent == .armPortableContinuity(reason: "codex active"))
        #expect(state.executionPolicy.effectiveCapability == .portableClamshellArmed)
        #expect(helper.appliedIntents == [.armPortableContinuity(reason: "codex active")])
        #expect(controller.appliedIntents == [.preventSleep(.init(
            reason: "codex active",
            preventDisplaySleep: false,
            declareUserActivity: false
        ))])
    }

    @Test
    func tickEmitsVerboseDebugRecord() async throws {
        let sampler = SequenceSampler([
            MonitoringSnapshot(
                cpuUsagePercent: 12,
                networkBytesPerSecond: 3_500,
                diskBytesPerSecond: 20_000,
                detectedApplicationKeywords: ["codex"],
                activeApplicationKeywords: ["codex"],
                listeningPorts: [18789]
            )
        ])
        let controller = RecordingSleepAssertionController()
        let helper = RecordingContinuityHelperController()
        let logger = RecordingDebugLogger()
        let engine = MonitoringEngine(
            mode: .auto,
            sampler: sampler,
            assertionController: controller,
            continuityEnvironmentProvider: StaticContinuityEnvironmentProvider(
                environment: ContinuityEnvironment(
                    hardwareClass: .desktop,
                    powerSource: .ac,
                    helperStatus: .ready,
                    isClamshellClosed: false
                )
            ),
            continuityHelperController: helper,
            now: { Date(timeIntervalSince1970: 1234) },
            debugLogger: { record in
                await logger.record(record)
            }
        )

        _ = try await engine.tick()

        let records = await logger.records()
        #expect(records.count == 1)
        #expect(records[0] == MonitoringDebugRecord(
            timestamp: Date(timeIntervalSince1970: 1234),
            mode: .auto,
            cpuUsagePercent: 12,
            networkBytesPerSecond: 3_500,
            diskBytesPerSecond: 20_000,
            detectedApplicationKeywords: ["codex"],
            activeApplicationKeywords: ["codex"],
            listeningPorts: [18789],
            reasons: [.developerProcess("codex"), .monitoredPort(18789)],
            shouldPreventSleep: true
        ))
    }

    @Test
    func autoModeReleasesAssertionsWhenIdlePolicyResets() async throws {
        let sampler = SequenceSampler([
            MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: ["codex"],
                activeApplicationKeywords: [],
                listeningPorts: [],
                monitoredApplicationSamples: [
                    MonitoredApplicationSample(
                        keyword: "codex",
                        isDetected: true,
                        networkDeltaBytes: 2_048,
                        cpuPercent: 0
                    )
                ]
            ),
            MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: ["codex"],
                activeApplicationKeywords: [],
                listeningPorts: [],
                monitoredApplicationSamples: [
                    MonitoredApplicationSample(
                        keyword: "codex",
                        isDetected: true,
                        networkDeltaBytes: 0,
                        cpuPercent: 0
                    )
                ]
            )
        ])
        let controller = RecordingSleepAssertionController()
        let helper = RecordingContinuityHelperController()
        let engine = MonitoringEngine(
            mode: .auto,
            sampler: sampler,
            assertionController: controller,
            continuityEnvironmentProvider: StaticContinuityEnvironmentProvider(
                environment: ContinuityEnvironment(
                    hardwareClass: .desktop,
                    powerSource: .ac,
                    helperStatus: .ready,
                    isClamshellClosed: false
                )
            ),
            continuityHelperController: helper,
            decisionEngine: DecisionEngine(
                inactivityGraceSamples: 1,
                monitoredNetworkWindowSamples: 1,
                monitoredNetworkThresholdBytes: 1_024
            )
        )

        _ = try await engine.tick()
        _ = try await engine.tick()

        #expect(controller.appliedIntents == [
            .preventSleep(.init(
                reason: "codex active",
                preventDisplaySleep: false,
                declareUserActivity: false
            )),
            .allowIdleSleep,
        ])
        #expect(helper.appliedIntents == [.inactive, .disarm])
    }
}

private actor SequenceSampler: MonitoringSampling {
    private var snapshots: [MonitoringSnapshot]
    private var sampleCount = 0

    init(_ snapshots: [MonitoringSnapshot]) {
        self.snapshots = snapshots
    }

    func sample() async throws -> MonitoringSnapshot {
        sampleCount += 1
        if snapshots.isEmpty {
            return MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: [],
                activeApplicationKeywords: [],
                listeningPorts: []
            )
        }

        return snapshots.removeFirst()
    }

    func currentSampleCount() -> Int {
        sampleCount
    }
}

@MainActor
private final class RecordingSleepAssertionController: SleepAssertionControlling {
    private(set) var appliedIntents: [AssertionIntent] = []

    func apply(intent: AssertionIntent) {
        appliedIntents.append(intent)
    }
}

private struct StaticContinuityEnvironmentProvider: ContinuityEnvironmentProviding {
    let environment: ContinuityEnvironment

    func currentEnvironment() async -> ContinuityEnvironment {
        environment
    }
}

@MainActor
private final class RecordingContinuityHelperController: ContinuityHelperControlling {
    private(set) var appliedIntents: [HelperIntent] = []

    func apply(intent: HelperIntent) async {
        appliedIntents.append(intent)
    }
}

private actor RecordingDebugLogger {
    private var values: [MonitoringDebugRecord] = []

    func record(_ record: MonitoringDebugRecord) {
        values.append(record)
    }

    func records() -> [MonitoringDebugRecord] {
        values
    }
}
