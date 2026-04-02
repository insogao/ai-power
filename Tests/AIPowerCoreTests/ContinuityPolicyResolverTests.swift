import Testing
@testable import AIPowerCore

struct ContinuityPolicyResolverTests {
    @Test
    func helperStatusesExposeGuidanceText() {
        #expect(HelperStatus.notInstalled.guidanceText == "Install the AI Continuity helper to enable closed-lid runs.")
        #expect(HelperStatus.requiresApproval.guidanceText == "Approve AI Power in System Settings > Login Items & Extensions.")
        #expect(HelperStatus.ready.guidanceText == nil)
        #expect(HelperStatus.degraded(reason: "Helper bundle is missing").guidanceText == "Helper bundle is missing")
    }

    @Test
    func standardModeUsesAssertionOnly() {
        let resolver = ContinuityPolicyResolver()

        let policy = resolver.resolve(
            workload: DecisionOutcome(shouldPreventSleep: true, reasons: [.cpuActivity]),
            continuityMode: .standard,
            wakeOptions: .default,
            environment: ContinuityEnvironment(
                hardwareClass: .desktop,
                powerSource: .ac,
                helperStatus: .notInstalled,
                isClamshellClosed: false
            )
        )

        #expect(policy.assertionIntent == .preventSleep(.init(
            reason: "CPU activity detected",
            preventDisplaySleep: false,
            declareUserActivity: false
        )))
        #expect(policy.helperIntent == .inactive)
        #expect(policy.effectiveCapability == .standard)
    }

    @Test
    func aiContinuityOnDesktopStaysOnPublicAssertionPath() {
        let resolver = ContinuityPolicyResolver()

        let policy = resolver.resolve(
            workload: DecisionOutcome(shouldPreventSleep: true, reasons: [.networkActivity]),
            continuityMode: .aiContinuity,
            wakeOptions: .default,
            environment: ContinuityEnvironment(
                hardwareClass: .desktop,
                powerSource: .unknown,
                helperStatus: .ready,
                isClamshellClosed: false
            )
        )

        #expect(policy.assertionIntent == .preventSleep(.init(
            reason: "Network activity detected",
            preventDisplaySleep: false,
            declareUserActivity: false
        )))
        #expect(policy.helperIntent == .inactive)
        #expect(policy.effectiveCapability == .desktopEnhanced)
        #expect(policy.userVisibleStatus == "AI Continuity active for locked-screen or display-off desktop use")
    }

    @Test
    func wakeOptionsCanRequestDisplaySleepPreventionAndUserActivity() {
        let resolver = ContinuityPolicyResolver()

        let policy = resolver.resolve(
            workload: DecisionOutcome(shouldPreventSleep: true, reasons: [.developerProcess("codex")]),
            continuityMode: .standard,
            wakeOptions: WakeControlOptions(
                preventComputerSleep: true,
                preventDisplaySleep: true,
                preventLockScreen: true,
                aiIdleGraceMinutes: 5,
                aiNetworkThresholdKilobytes: 30
            ),
            environment: ContinuityEnvironment(
                hardwareClass: .desktop,
                powerSource: .ac,
                helperStatus: .ready,
                isClamshellClosed: false
            )
        )

        #expect(policy.assertionIntent == .preventSleep(.init(
            reason: "codex active",
            preventDisplaySleep: true,
            declareUserActivity: true
        )))
    }

    @Test
    func aiContinuityOnPortableRequiresReadyHelperAndACPower() {
        let resolver = ContinuityPolicyResolver()

        let missingHelper = resolver.resolve(
            workload: DecisionOutcome(shouldPreventSleep: true, reasons: [.manualMode]),
            continuityMode: .aiContinuity,
            wakeOptions: .default,
            environment: ContinuityEnvironment(
                hardwareClass: .portable,
                powerSource: .ac,
                helperStatus: .notInstalled,
                isClamshellClosed: false
            )
        )
        let battery = resolver.resolve(
            workload: DecisionOutcome(shouldPreventSleep: true, reasons: [.manualMode]),
            continuityMode: .aiContinuity,
            wakeOptions: .default,
            environment: ContinuityEnvironment(
                hardwareClass: .portable,
                powerSource: .battery,
                helperStatus: .ready,
                isClamshellClosed: false
            )
        )
        let active = resolver.resolve(
            workload: DecisionOutcome(shouldPreventSleep: true, reasons: [.manualMode]),
            continuityMode: .aiContinuity,
            wakeOptions: .default,
            environment: ContinuityEnvironment(
                hardwareClass: .portable,
                powerSource: .ac,
                helperStatus: .ready,
                isClamshellClosed: true
            )
        )

        #expect(missingHelper.helperIntent == .installOrApprove)
        #expect(missingHelper.effectiveCapability == .degraded)
        #expect(missingHelper.userVisibleStatus == "AI Continuity requires the privileged helper")

        #expect(battery.helperIntent == .disarm)
        #expect(battery.effectiveCapability == .degraded)
        #expect(battery.userVisibleStatus == "AI Continuity on portable Macs is available only on AC power")

        #expect(active.helperIntent == .armPortableContinuity(reason: "Manual mode enabled"))
        #expect(active.effectiveCapability == .portableClamshellArmed)
        #expect(active.userVisibleStatus == "AI Continuity armed for closed-lid portable operation")
    }

    @Test
    func noWorkloadKeepsContinuityDisarmed() {
        let resolver = ContinuityPolicyResolver()

        let policy = resolver.resolve(
            workload: .allowingSleep,
            continuityMode: .aiContinuity,
            wakeOptions: .default,
            environment: ContinuityEnvironment(
                hardwareClass: .portable,
                powerSource: .ac,
                helperStatus: .ready,
                isClamshellClosed: false
            )
        )

        #expect(policy.assertionIntent == .allowIdleSleep)
        #expect(policy.helperIntent == .disarm)
        #expect(policy.effectiveCapability == .inactive)
    }
}
