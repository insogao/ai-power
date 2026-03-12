import Foundation
import Testing
@testable import AIPowerHelperSupport

struct PMSetCommandBuilderTests {
    @Test
    func buildsPortableArmCommands() {
        let builder = PMSetCommandBuilder()
        let snapshot = PMSetSnapshot(
            sleepDisabled: false,
            sleepMinutes: 20,
            displaySleepMinutes: 15,
            diskSleepMinutes: 10
        )

        let commands = builder.armPortableContinuityCommands(
            baseline: snapshot,
            reason: "python active"
        )

        #expect(commands == [
            ["-a", "disablesleep", "1"],
        ])
    }

    @Test
    func restoresBaselineCommands() {
        let builder = PMSetCommandBuilder()
        let snapshot = PMSetSnapshot(
            sleepDisabled: true,
            sleepMinutes: 12,
            displaySleepMinutes: 5,
            diskSleepMinutes: 7
        )

        let commands = builder.restoreCommands(from: snapshot)

        #expect(commands == [
            ["-a", "sleep", "12"],
            ["-a", "displaysleep", "5"],
            ["-a", "disksleep", "7"],
            ["-a", "disablesleep", "1"],
        ])
    }
}
