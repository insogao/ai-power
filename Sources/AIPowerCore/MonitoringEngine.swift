import Foundation

@MainActor
public protocol SleepAssertionControlling: AnyObject {
    func apply(intent: AssertionIntent)
}

public protocol MonitoringSampling: Sendable {
    func sample() async throws -> MonitoringSnapshot
}

public protocol ContinuityEnvironmentProviding: Sendable {
    func currentEnvironment() async -> ContinuityEnvironment
}

@MainActor
public protocol ContinuityHelperControlling: AnyObject {
    func apply(intent: HelperIntent) async
}

@MainActor
public final class MonitoringEngine {
    public static let defaultSamplingIntervalSeconds = 2

    public var mode: AppMode
    public var continuityMode: ContinuityMode
    public var wakeControlOptions: WakeControlOptions {
        didSet {
            decisionEngine.setInactivityGraceSamples(Self.graceSamples(for: wakeControlOptions.aiIdleGraceMinutes))
        }
    }
    public private(set) var state: MonitoringState

    private let sampler: any MonitoringSampling
    private let assertionController: any SleepAssertionControlling
    private let continuityEnvironmentProvider: any ContinuityEnvironmentProviding
    private let continuityHelperController: any ContinuityHelperControlling
    private var decisionEngine: DecisionEngine
    private let continuityPolicyResolver: ContinuityPolicyResolver
    private let now: @Sendable () -> Date
    private let debugLogger: (@Sendable (MonitoringDebugRecord) async -> Void)?
    private var lastAppliedAssertionIntent: AssertionIntent?
    private var lastAppliedHelperIntent: HelperIntent?

    public init(
        mode: AppMode = .default,
        continuityMode: ContinuityMode = .default,
        sampler: any MonitoringSampling,
        assertionController: any SleepAssertionControlling,
        continuityEnvironmentProvider: any ContinuityEnvironmentProviding,
        continuityHelperController: any ContinuityHelperControlling,
        decisionEngine: DecisionEngine = DecisionEngine(),
        continuityPolicyResolver: ContinuityPolicyResolver = ContinuityPolicyResolver(),
        now: @escaping @Sendable () -> Date = Date.init,
        debugLogger: (@Sendable (MonitoringDebugRecord) async -> Void)? = nil
    ) {
        self.mode = mode
        self.continuityMode = continuityMode
        self.wakeControlOptions = .default
        self.sampler = sampler
        self.assertionController = assertionController
        self.continuityEnvironmentProvider = continuityEnvironmentProvider
        self.continuityHelperController = continuityHelperController
        self.decisionEngine = decisionEngine
        self.continuityPolicyResolver = continuityPolicyResolver
        self.now = now
        self.debugLogger = debugLogger
        self.decisionEngine.setInactivityGraceSamples(Self.graceSamples(for: self.wakeControlOptions.aiIdleGraceMinutes))
        self.state = MonitoringState(
            mode: mode,
            continuityMode: continuityMode,
            wakeControlOptions: .default,
            snapshot: nil,
            outcome: .allowingSleep
            ,
            continuityEnvironment: MonitoringState.initial.continuityEnvironment,
            executionPolicy: MonitoringState.initial.executionPolicy
        )
    }

    @discardableResult
    public func tick() async throws -> MonitoringState {
        let snapshot = try await sampler.sample()
        let outcome = decisionEngine.evaluate(mode: mode, snapshot: snapshot)
        let continuityEnvironment = await continuityEnvironmentProvider.currentEnvironment()
        let executionPolicy = continuityPolicyResolver.resolve(
            workload: outcome,
            continuityMode: continuityMode,
            wakeOptions: wakeControlOptions,
            environment: continuityEnvironment
        )

        if shouldApplyHelperIntent(executionPolicy.helperIntent) {
            await continuityHelperController.apply(intent: executionPolicy.helperIntent)
            lastAppliedHelperIntent = executionPolicy.helperIntent
        }

        if shouldApplyAssertion(for: executionPolicy.assertionIntent) {
            assertionController.apply(intent: executionPolicy.assertionIntent)
            lastAppliedAssertionIntent = executionPolicy.assertionIntent
        }

        let updatedState = MonitoringState(
            mode: mode,
            continuityMode: continuityMode,
            wakeControlOptions: wakeControlOptions,
            snapshot: snapshot,
            outcome: outcome,
            continuityEnvironment: continuityEnvironment,
            executionPolicy: executionPolicy
        )
        state = updatedState
        if let debugLogger {
            await debugLogger(
                MonitoringDebugRecord(
                    timestamp: now(),
                    mode: mode,
                    cpuUsagePercent: snapshot.cpuUsagePercent,
                    networkBytesPerSecond: snapshot.networkBytesPerSecond,
                    diskBytesPerSecond: snapshot.diskBytesPerSecond,
                    configuredApplicationKeywords: snapshot.configuredApplicationKeywords,
                    configuredPorts: snapshot.configuredPorts,
                    detectedApplicationKeywords: snapshot.detectedApplicationKeywords,
                    activeApplicationKeywords: snapshot.activeApplicationKeywords,
                    listeningPorts: snapshot.listeningPorts,
                    reasons: outcome.reasons,
                    shouldPreventSleep: outcome.shouldPreventSleep,
                    processCPUSamples: snapshot.processCPUSamples,
                    processNetworkSamples: snapshot.processNetworkSamples,
                    monitoredApplicationSamples: snapshot.monitoredApplicationSamples
                )
            )
        }
        return updatedState
    }

    public func shutdown() async {
        await resetRuntimeState(clearDecisionState: true)
    }

    public func resetRuntimeState(clearDecisionState: Bool) async {
        if clearDecisionState {
            decisionEngine.reset()
        }

        let continuityEnvironment = await continuityEnvironmentProvider.currentEnvironment()
        let executionPolicy = continuityPolicyResolver.resolve(
            workload: .allowingSleep,
            continuityMode: continuityMode,
            wakeOptions: wakeControlOptions,
            environment: continuityEnvironment
        )

        assertionController.apply(intent: .allowIdleSleep)
        lastAppliedAssertionIntent = .allowIdleSleep
        await continuityHelperController.apply(intent: .disarm)
        lastAppliedHelperIntent = .disarm

        state = MonitoringState(
            mode: mode,
            continuityMode: continuityMode,
            wakeControlOptions: wakeControlOptions,
            snapshot: state.snapshot,
            outcome: .allowingSleep,
            continuityEnvironment: continuityEnvironment,
            executionPolicy: executionPolicy
        )
    }

    public func reapplyCurrentPolicy() async {
        let continuityEnvironment = await continuityEnvironmentProvider.currentEnvironment()
        let executionPolicy = continuityPolicyResolver.resolve(
            workload: state.outcome,
            continuityMode: continuityMode,
            wakeOptions: wakeControlOptions,
            environment: continuityEnvironment
        )

        if shouldApplyHelperIntent(executionPolicy.helperIntent) {
            await continuityHelperController.apply(intent: executionPolicy.helperIntent)
            lastAppliedHelperIntent = executionPolicy.helperIntent
        }

        if shouldApplyAssertion(for: executionPolicy.assertionIntent) {
            assertionController.apply(intent: executionPolicy.assertionIntent)
            lastAppliedAssertionIntent = executionPolicy.assertionIntent
        }

        state = MonitoringState(
            mode: mode,
            continuityMode: continuityMode,
            wakeControlOptions: wakeControlOptions,
            snapshot: state.snapshot,
            outcome: state.outcome,
            continuityEnvironment: continuityEnvironment,
            executionPolicy: executionPolicy
        )
    }

    private func shouldApplyAssertion(for intent: AssertionIntent) -> Bool {
        lastAppliedAssertionIntent != intent
    }

    private func shouldApplyHelperIntent(_ intent: HelperIntent) -> Bool {
        lastAppliedHelperIntent != intent
    }

    private static func graceSamples(for minutes: Int) -> Int {
        let clampedMinutes = max(minutes, 0)
        let seconds = clampedMinutes * 60
        return max(seconds / defaultSamplingIntervalSeconds, 0)
    }
}

private extension AssertionIntent {
    var shouldPreventSleep: Bool {
        switch self {
        case .allowIdleSleep:
            return false
        case .preventSleep:
            return true
        }
    }
}
