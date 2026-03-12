import AIPowerCore
import AIPowerIPC
import Foundation
import Testing
@testable import AIPowerHelperSupport

struct ContinuityDaemonServerTests {
    @Test
    func armRequestRunsCommandsAndPersistsRecoveryReason() throws {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecoveryJournalStore(fileURL: fileURL)
        let runner = RecordingDaemonCommandRunner()
        let handler = ContinuityDaemonCommandHandler(
            snapshotReader: StaticPMSetSnapshotReader(
                snapshot: PMSetSnapshot(
                    sleepDisabled: false,
                    sleepMinutes: 10,
                    displaySleepMinutes: 8,
                    diskSleepMinutes: 5
                )
            ),
            engine: ContinuityHelperEngine(
                commandBuilder: PMSetCommandBuilder(),
                runner: runner,
                journalStore: store,
                now: { Date(timeIntervalSince1970: 700) }
            ),
            journalStore: store
        )

        let reply = try handler.apply(
            ContinuityDaemonRequest(action: .armPortableContinuity, reason: "python active")
        )

        #expect(reply.helperStatus == HelperStatus.ready)
        #expect(reply.recoveryReason == "python active")
        #expect(runner.commands == [
            ["-a", "disablesleep", "1"],
        ])
        #expect(try store.load()?.lastReason == "python active")
    }

    @Test
    func restoreRequestClearsJournal() throws {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecoveryJournalStore(fileURL: fileURL)
        let runner = RecordingDaemonCommandRunner()
        try store.save(
            PortableContinuityRecoveryState(
                baseline: PMSetSnapshot(
                    sleepDisabled: true,
                    sleepMinutes: 0,
                    displaySleepMinutes: 5,
                    diskSleepMinutes: 2
                ),
                lastReason: "python active",
                updatedAt: Date(timeIntervalSince1970: 800)
            )
        )
        let handler = ContinuityDaemonCommandHandler(
            snapshotReader: StaticPMSetSnapshotReader(
                snapshot: PMSetSnapshot(
                    sleepDisabled: false,
                    sleepMinutes: 10,
                    displaySleepMinutes: 8,
                    diskSleepMinutes: 5
                )
            ),
            engine: ContinuityHelperEngine(
                commandBuilder: PMSetCommandBuilder(),
                runner: runner,
                journalStore: store,
                now: Date.init
            ),
            journalStore: store
        )

        let reply = try handler.restoreBaseline()

        #expect(reply.helperStatus == HelperStatus.ready)
        #expect(reply.recoveryReason == nil)
        #expect(try store.load() == nil)
        #expect(runner.commands == [
            ["-a", "sleep", "0"],
            ["-a", "displaysleep", "5"],
            ["-a", "disksleep", "2"],
            ["-a", "disablesleep", "1"],
        ])
    }

    @Test
    func fetchRecoveryStateReturnsStoredReason() throws {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecoveryJournalStore(fileURL: fileURL)
        try store.save(
            PortableContinuityRecoveryState(
                baseline: PMSetSnapshot(
                    sleepDisabled: false,
                    sleepMinutes: 9,
                    displaySleepMinutes: 7,
                    diskSleepMinutes: 3
                ),
                lastReason: "codex active",
                updatedAt: Date(timeIntervalSince1970: 900)
            )
        )
        let handler = ContinuityDaemonCommandHandler(
            snapshotReader: StaticPMSetSnapshotReader(
                snapshot: PMSetSnapshot(
                    sleepDisabled: false,
                    sleepMinutes: 10,
                    displaySleepMinutes: 8,
                    diskSleepMinutes: 5
                )
            ),
            engine: ContinuityHelperEngine(
                commandBuilder: PMSetCommandBuilder(),
                runner: RecordingDaemonCommandRunner(),
                journalStore: store,
                now: Date.init
            ),
            journalStore: store
        )

        let reply = try handler.fetchRecoveryState()

        #expect(reply.helperStatus == HelperStatus.ready)
        #expect(reply.recoveryReason == "codex active")
    }
}

private struct StaticPMSetSnapshotReader: PMSetSnapshotReading {
    let snapshot: PMSetSnapshot

    func readCurrentSnapshot() throws -> PMSetSnapshot {
        snapshot
    }
}

private final class RecordingDaemonCommandRunner: PMSetCommandRunning {
    private(set) var commands: [[String]] = []

    func run(arguments: [String]) throws {
        commands.append(arguments)
    }
}
