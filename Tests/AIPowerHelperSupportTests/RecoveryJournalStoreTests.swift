import Foundation
import Testing
@testable import AIPowerHelperSupport

struct RecoveryJournalStoreTests {
    @Test
    func roundTripsRecoveryState() throws {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecoveryJournalStore(fileURL: fileURL)
        let state = PortableContinuityRecoveryState(
            baseline: PMSetSnapshot(
                sleepDisabled: false,
                sleepMinutes: 15,
                displaySleepMinutes: 10,
                diskSleepMinutes: 5
            ),
            lastReason: "Manual mode enabled",
            updatedAt: Date(timeIntervalSince1970: 1234)
        )

        try store.save(state)

        let loaded = try store.load()

        #expect(loaded == state)

        try store.clear()
        #expect(try store.load() == nil)
    }

    @Test
    func saveCreatesParentDirectories() throws {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let nestedDirectory = temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("nested")
        let fileURL = nestedDirectory.appendingPathComponent("state.json")
        let store = RecoveryJournalStore(fileURL: fileURL)

        try store.save(
            PortableContinuityRecoveryState(
                baseline: PMSetSnapshot(
                    sleepDisabled: false,
                    sleepMinutes: 1,
                    displaySleepMinutes: 2,
                    diskSleepMinutes: 3
                ),
                lastReason: "test",
                updatedAt: Date(timeIntervalSince1970: 1)
            )
        )

        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
