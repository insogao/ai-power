public struct DecisionEngine: Sendable {
    private var inactivityGraceSamples: Int
    private let monitoredNetworkWindowSamples: Int
    private var monitoredNetworkThresholdBytes: UInt64
    private var quietSamplesSinceActivity = 0
    private var hasSeenAutoActivity = false
    private var monitoredNetworkWindows: [String: [UInt64]] = [:]

    public init(
        inactivityGraceSamples: Int = 150,
        monitoredNetworkWindowSamples: Int = 30,
        monitoredNetworkThresholdBytes: UInt64 = 30 * 1024
    ) {
        self.inactivityGraceSamples = inactivityGraceSamples
        self.monitoredNetworkWindowSamples = monitoredNetworkWindowSamples
        self.monitoredNetworkThresholdBytes = monitoredNetworkThresholdBytes
    }

    public mutating func evaluate(
        mode: AppMode,
        snapshot: MonitoringSnapshot
    ) -> DecisionOutcome {
        switch mode {
        case .off:
            return .allowingSleep

        case .manual:
            return DecisionOutcome(shouldPreventSleep: true, reasons: [.manualMode])

        case .developer:
            if snapshot.detectedApplicationKeywords.isEmpty {
                return .allowingSleep
            }

            return DecisionOutcome(
                shouldPreventSleep: true,
                reasons: snapshot.detectedApplicationKeywords.map(ActivityReason.developerProcess)
            )

        case .auto:
            var reasons: [ActivityReason] = []
            reasons.append(contentsOf: activeMonitoredKeywords(from: snapshot).map(ActivityReason.developerProcess))
            reasons.append(contentsOf: snapshot.listeningPorts.map(ActivityReason.monitoredPort))

            if reasons.isEmpty == false {
                hasSeenAutoActivity = true
                quietSamplesSinceActivity = 0
                return DecisionOutcome(
                    shouldPreventSleep: true,
                    reasons: reasons
                )
            }

            guard hasSeenAutoActivity else {
                return .allowingSleep
            }

            quietSamplesSinceActivity += 1
            if quietSamplesSinceActivity >= inactivityGraceSamples {
                hasSeenAutoActivity = false
                quietSamplesSinceActivity = 0
                return .allowingSleep
            }

            return DecisionOutcome(
                shouldPreventSleep: true,
                reasons: [.activityGrace]
            )
        }
    }

    public mutating func reset() {
        quietSamplesSinceActivity = 0
        hasSeenAutoActivity = false
        monitoredNetworkWindows = [:]
    }

    public mutating func setInactivityGraceSamples(_ samples: Int) {
        inactivityGraceSamples = max(samples, 0)
        quietSamplesSinceActivity = min(quietSamplesSinceActivity, inactivityGraceSamples)
    }

    public mutating func setMonitoredNetworkThresholdBytes(_ bytes: UInt64) {
        monitoredNetworkThresholdBytes = max(bytes, 0)
    }

    private mutating func activeMonitoredKeywords(from snapshot: MonitoringSnapshot) -> [String] {
        guard snapshot.monitoredApplicationSamples.isEmpty == false else {
            return snapshot.activeApplicationKeywords
        }

        var activeKeywords: [String] = []
        for sample in snapshot.monitoredApplicationSamples {
            var window = monitoredNetworkWindows[sample.keyword] ?? []
            window.append(sample.networkDeltaBytes)
            if window.count > monitoredNetworkWindowSamples {
                window.removeFirst(window.count - monitoredNetworkWindowSamples)
            }
            monitoredNetworkWindows[sample.keyword] = window

            let totalBytes = window.reduce(0, +)
            if totalBytes >= monitoredNetworkThresholdBytes {
                activeKeywords.append(sample.keyword)
            }
        }

        return activeKeywords
    }
}
