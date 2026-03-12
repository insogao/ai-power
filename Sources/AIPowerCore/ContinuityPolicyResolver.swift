public struct ContinuityPolicyResolver: Sendable {
    public init() {}

    public func resolve(
        workload: DecisionOutcome,
        continuityMode: ContinuityMode,
        wakeOptions: WakeControlOptions = .default,
        environment: ContinuityEnvironment
    ) -> ExecutionPolicy {
        guard wakeOptions.preventComputerSleep else {
            return ExecutionPolicy(
                assertionIntent: .allowIdleSleep,
                helperIntent: .disarm,
                effectiveCapability: .inactive,
                userVisibleStatus: "Computer sleep prevention is disabled"
            )
        }

        guard workload.shouldPreventSleep else {
            return ExecutionPolicy(
                assertionIntent: .allowIdleSleep,
                helperIntent: .disarm,
                effectiveCapability: .inactive,
                userVisibleStatus: "Idle"
            )
        }

        let primaryReason = workload.reasons.first?.displayText ?? "Workload detected"
        let assertionIntent = AssertionIntent.preventSleep(
            AssertionConfiguration(
                reason: primaryReason,
                preventDisplaySleep: wakeOptions.preventDisplaySleep,
                declareUserActivity: wakeOptions.preventLockScreen
            )
        )

        switch continuityMode {
        case .standard:
            return ExecutionPolicy(
                assertionIntent: assertionIntent,
                helperIntent: .inactive,
                effectiveCapability: .standard,
                userVisibleStatus: "Standard continuity active"
            )

        case .aiContinuity:
            switch environment.hardwareClass {
            case .desktop:
                return ExecutionPolicy(
                    assertionIntent: assertionIntent,
                    helperIntent: .inactive,
                    effectiveCapability: .desktopEnhanced,
                    userVisibleStatus: "AI Continuity active for locked-screen or display-off desktop use"
                )

            case .portable:
                switch environment.helperStatus {
                case .notInstalled:
                    return degradedPortablePolicy(
                        assertionIntent: assertionIntent,
                        helperIntent: .installOrApprove,
                        status: "AI Continuity requires the privileged helper"
                    )

                case .requiresApproval:
                    return degradedPortablePolicy(
                        assertionIntent: assertionIntent,
                        helperIntent: .installOrApprove,
                        status: "AI Continuity requires helper approval in System Settings"
                    )

                case let .degraded(reason):
                    return degradedPortablePolicy(
                        assertionIntent: assertionIntent,
                        helperIntent: .disarm,
                        status: "AI Continuity degraded: \(reason)"
                    )

                case .ready:
                    guard environment.powerSource == .ac else {
                        return degradedPortablePolicy(
                            assertionIntent: assertionIntent,
                            helperIntent: .disarm,
                            status: "AI Continuity on portable Macs is available only on AC power"
                        )
                    }

                    return ExecutionPolicy(
                        assertionIntent: assertionIntent,
                        helperIntent: .armPortableContinuity(reason: primaryReason),
                        effectiveCapability: .portableClamshellArmed,
                        userVisibleStatus: environment.isClamshellClosed
                            ? "AI Continuity armed for closed-lid portable operation"
                            : "AI Continuity armed and ready for closed-lid portable operation"
                    )
                }
            }
        }
    }

    private func degradedPortablePolicy(
        assertionIntent: AssertionIntent,
        helperIntent: HelperIntent,
        status: String
    ) -> ExecutionPolicy {
        ExecutionPolicy(
            assertionIntent: assertionIntent,
            helperIntent: helperIntent,
            effectiveCapability: .degraded,
            userVisibleStatus: status
        )
    }
}
