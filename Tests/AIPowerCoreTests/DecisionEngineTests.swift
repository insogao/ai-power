import Testing
@testable import AIPowerCore

struct DecisionEngineTests {
    @Test
    func autoModeDoesNotPreventSleepForCpuOnlyMonitoredActivity() {
        var engine = DecisionEngine()

        let outcome = engine.evaluate(
            mode: .auto,
            snapshot: MonitoringSnapshot(
                cpuUsagePercent: 35,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: ["kimi"],
                activeApplicationKeywords: [],
                listeningPorts: [],
                monitoredApplicationSamples: [
                    MonitoredApplicationSample(
                        keyword: "kimi",
                        isDetected: true,
                        networkDeltaBytes: 0,
                        cpuPercent: 12
                    )
                ]
            )
        )

        #expect(outcome.shouldPreventSleep == false)
        #expect(outcome.reasons == [])
    }

    @Test
    func autoModePreventsSleepWhenMonitoredNetworkCrossesRollingThreshold() {
        var engine = DecisionEngine(
            inactivityGraceSamples: 3,
            monitoredNetworkWindowSamples: 30,
            monitoredNetworkThresholdBytes: 30 * 1024
        )
        var outcome = DecisionOutcome.allowingSleep

        for _ in 0..<29 {
            outcome = engine.evaluate(
                mode: .auto,
                snapshot: MonitoringSnapshot(
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
                            networkDeltaBytes: 1_000,
                            cpuPercent: 0.4
                        )
                    ]
                )
            )
        }

        #expect(outcome.shouldPreventSleep == false)

        outcome = engine.evaluate(
            mode: .auto,
            snapshot: MonitoringSnapshot(
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
                        networkDeltaBytes: 2_000,
                        cpuPercent: 0.2
                    )
                ]
            )
        )

        #expect(outcome.shouldPreventSleep == true)
        #expect(outcome.reasons == [.developerProcess("codex")])
    }

    @Test
    func monitoredNetworkThresholdCanBeAdjustedAtRuntime() {
        var engine = DecisionEngine(
            inactivityGraceSamples: 3,
            monitoredNetworkWindowSamples: 3,
            monitoredNetworkThresholdBytes: 30 * 1024
        )

        let snapshot = MonitoringSnapshot(
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
                    networkDeltaBytes: 12 * 1024,
                    cpuPercent: 0.2
                )
            ]
        )

        _ = engine.evaluate(mode: .auto, snapshot: snapshot)
        _ = engine.evaluate(mode: .auto, snapshot: snapshot)
        let initialOutcome = engine.evaluate(mode: .auto, snapshot: snapshot)

        #expect(initialOutcome.shouldPreventSleep == true)

        engine.reset()
        engine.setMonitoredNetworkThresholdBytes(50 * 1024)

        _ = engine.evaluate(mode: .auto, snapshot: snapshot)
        _ = engine.evaluate(mode: .auto, snapshot: snapshot)
        let stricterOutcome = engine.evaluate(mode: .auto, snapshot: snapshot)

        #expect(stricterOutcome.shouldPreventSleep == false)
    }

    @Test
    func resetClearsRollingActivityState() {
        var engine = DecisionEngine(
            inactivityGraceSamples: 3,
            monitoredNetworkWindowSamples: 2,
            monitoredNetworkThresholdBytes: 1_000
        )

        _ = engine.evaluate(
            mode: .auto,
            snapshot: MonitoringSnapshot(
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
                        networkDeltaBytes: 600,
                        cpuPercent: 0
                    )
                ]
            )
        )
        let activeOutcome = engine.evaluate(
            mode: .auto,
            snapshot: MonitoringSnapshot(
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
                        networkDeltaBytes: 600,
                        cpuPercent: 0
                    )
                ]
            )
        )

        #expect(activeOutcome.shouldPreventSleep == true)

        engine.reset()

        let resetOutcome = engine.evaluate(
            mode: .auto,
            snapshot: MonitoringSnapshot(
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
                        cpuPercent: 18
                    )
                ]
            )
        )

        #expect(resetOutcome.shouldPreventSleep == false)
        #expect(resetOutcome.reasons == [])
    }

    @Test
    func offModeAlwaysAllowsSleep() {
        var engine = DecisionEngine()

        let outcome = engine.evaluate(
            mode: .off,
            snapshot: MonitoringSnapshot(
                cpuUsagePercent: 99,
                networkBytesPerSecond: 999_999,
                diskBytesPerSecond: 999_999,
                detectedApplicationKeywords: ["codex"],
                activeApplicationKeywords: ["codex"],
                listeningPorts: [18789]
            )
        )

        #expect(outcome.shouldPreventSleep == false)
        #expect(outcome.reasons == [])
    }

    @Test
    func manualModeAlwaysPreventsSleep() {
        var engine = DecisionEngine()

        let outcome = engine.evaluate(
            mode: .manual,
            snapshot: MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: [],
                activeApplicationKeywords: [],
                listeningPorts: []
            )
        )

        #expect(outcome.shouldPreventSleep == true)
        #expect(outcome.reasons == [.manualMode])
    }

    @Test
    func developerModeDependsOnDetectedProcess() {
        var engine = DecisionEngine()

        let inactive = engine.evaluate(
            mode: .developer,
            snapshot: MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: [],
                activeApplicationKeywords: [],
                listeningPorts: []
            )
        )

        let active = engine.evaluate(
            mode: .developer,
            snapshot: MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: ["codex"],
                activeApplicationKeywords: [],
                listeningPorts: []
            )
        )

        #expect(inactive.shouldPreventSleep == false)
        #expect(active.shouldPreventSleep == true)
        #expect(active.reasons == [.developerProcess("codex")])
    }

    @Test
    func autoModePreventsSleepWhenCpuBecomesActive() {
        var engine = DecisionEngine()
        var outcome = DecisionOutcome.allowingSleep

        for _ in 0..<10 {
            outcome = engine.evaluate(
                mode: .auto,
                snapshot: MonitoringSnapshot(
                    cpuUsagePercent: 31,
                    networkBytesPerSecond: 0,
                    diskBytesPerSecond: 0,
                    detectedApplicationKeywords: [],
                    activeApplicationKeywords: [],
                    listeningPorts: []
                )
            )
        }

        #expect(outcome.shouldPreventSleep == false)
        #expect(outcome.reasons.isEmpty)
    }

    @Test
    func autoModeAllowsSleepWhenAllSignalsAreInactive() {
        var engine = DecisionEngine()

        let outcome = engine.evaluate(
            mode: .auto,
            snapshot: MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: [],
                activeApplicationKeywords: [],
                listeningPorts: []
            )
        )

        #expect(outcome.shouldPreventSleep == false)
        #expect(outcome.reasons == [])
    }

    @Test
    func autoModeRequiresActiveApplicationSignalsInsteadOfKeywordOnlyPresence() {
        var engine = DecisionEngine()

        let outcome = engine.evaluate(
            mode: .auto,
            snapshot: MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: ["codex"],
                activeApplicationKeywords: [],
                listeningPorts: []
            )
        )

        #expect(outcome.shouldPreventSleep == false)
        #expect(outcome.reasons == [])
    }

    @Test
    func autoModeActivatesWhenApplicationHasActivity() {
        var engine = DecisionEngine()

        let outcome = engine.evaluate(
            mode: .auto,
            snapshot: MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: ["codex"],
                activeApplicationKeywords: ["codex"],
                listeningPorts: []
            )
        )

        #expect(outcome.shouldPreventSleep == true)
        #expect(outcome.reasons == [.developerProcess("codex")])
    }

    @Test
    func autoModeActivatesWhenMonitoredPortIsListening() {
        var engine = DecisionEngine()

        let outcome = engine.evaluate(
            mode: .auto,
            snapshot: MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: [],
                activeApplicationKeywords: [],
                listeningPorts: [18789]
            )
        )

        #expect(outcome.shouldPreventSleep == true)
        #expect(outcome.reasons == [.monitoredPort(18789)])
    }

    @Test
    func autoModeKeepsSleepPreventionDuringQuietGraceWindow() {
        var engine = DecisionEngine(inactivityGraceSamples: 3)

        _ = engine.evaluate(
            mode: .auto,
            snapshot: MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: ["claude"],
                activeApplicationKeywords: ["claude"],
                listeningPorts: []
            )
        )

        let stillActive = engine.evaluate(
            mode: .auto,
            snapshot: MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: [],
                activeApplicationKeywords: [],
                listeningPorts: []
            )
        )

        #expect(stillActive.shouldPreventSleep == true)
        #expect(stillActive.reasons == [.activityGrace])
    }

    @Test
    func updatingGraceSamplesChangesQuietWindowLength() {
        var engine = DecisionEngine(inactivityGraceSamples: 3)

        _ = engine.evaluate(
            mode: .auto,
            snapshot: MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: ["claude"],
                activeApplicationKeywords: ["claude"],
                listeningPorts: []
            )
        )

        engine.setInactivityGraceSamples(1)

        let inactive = engine.evaluate(
            mode: .auto,
            snapshot: MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: [],
                activeApplicationKeywords: [],
                listeningPorts: []
            )
        )

        #expect(inactive.shouldPreventSleep == false)
        #expect(inactive.reasons.isEmpty)
    }

    @Test
    func autoModeExitsAfterQuietGraceWindowExpires() {
        var engine = DecisionEngine(inactivityGraceSamples: 3)

        _ = engine.evaluate(
            mode: .auto,
            snapshot: MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: ["claude"],
                activeApplicationKeywords: ["claude"],
                listeningPorts: []
            )
        )

        _ = engine.evaluate(
            mode: .auto,
            snapshot: MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: [],
                activeApplicationKeywords: [],
                listeningPorts: []
            )
        )
        _ = engine.evaluate(
            mode: .auto,
            snapshot: MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: [],
                activeApplicationKeywords: [],
                listeningPorts: []
            )
        )
        let inactive = engine.evaluate(
            mode: .auto,
            snapshot: MonitoringSnapshot(
                cpuUsagePercent: 0,
                networkBytesPerSecond: 0,
                diskBytesPerSecond: 0,
                detectedApplicationKeywords: [],
                activeApplicationKeywords: [],
                listeningPorts: []
            )
        )

        #expect(inactive.shouldPreventSleep == false)
        #expect(inactive.reasons == [])
    }
}
