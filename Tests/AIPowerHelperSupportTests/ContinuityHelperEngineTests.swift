import Foundation
import Testing
@testable import AIPowerHelperSupport

struct ContinuityHelperEngineTests {
    @Test
    func armStoresRecoveryStateAndRunsCommands() throws {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecoveryJournalStore(fileURL: fileURL)
        let runner = RecordingCommandRunner()
        let engine = ContinuityHelperEngine(
            commandBuilder: PMSetCommandBuilder(),
            runner: runner,
            journalStore: store,
            now: { Date(timeIntervalSince1970: 500) }
        )
        let baseline = PMSetSnapshot(
            sleepDisabled: false,
            sleepMinutes: 10,
            displaySleepMinutes: 8,
            diskSleepMinutes: 5
        )

        try engine.armPortableContinuity(baseline: baseline, reason: "python active")

        #expect(runner.commands == [
            ["-a", "disablesleep", "1"],
        ])
        #expect(try store.load() == PortableContinuityRecoveryState(
            baseline: baseline,
            lastReason: "python active",
            updatedAt: Date(timeIntervalSince1970: 500)
        ))
    }

    @Test
    func restoreReplaysBaselineAndClearsJournal() throws {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecoveryJournalStore(fileURL: fileURL)
        let runner = RecordingCommandRunner()
        let engine = ContinuityHelperEngine(
            commandBuilder: PMSetCommandBuilder(),
            runner: runner,
            journalStore: store,
            now: { Date() }
        )
        let state = PortableContinuityRecoveryState(
            baseline: PMSetSnapshot(
                sleepDisabled: true,
                sleepMinutes: 0,
                displaySleepMinutes: 5,
                diskSleepMinutes: 7
            ),
            lastReason: "Manual mode enabled",
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        try store.save(state)
        try engine.restoreBaseline()

        #expect(runner.commands == [
            ["-a", "sleep", "0"],
            ["-a", "displaysleep", "5"],
            ["-a", "disksleep", "7"],
            ["-a", "disablesleep", "1"],
        ])
        #expect(try store.load() == nil)
    }
}

private final class RecordingCommandRunner: PMSetCommandRunning {
    private(set) var commands: [[String]] = []

    func run(arguments: [String]) throws {
        commands.append(arguments)
    }
}
