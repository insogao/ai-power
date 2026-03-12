import Testing
@testable import AIPowerHelperSupport

struct PMSetSnapshotParserTests {
    @Test
    func parsesCurrentPmsetOutput() throws {
        let parser = PMSetSnapshotParser()
        let output = """
        System-wide power settings:
         SleepDisabled        1
        Currently in use:
         standby              0
         disksleep            7
         sleep                0
         displaysleep         5
        """

        let snapshot = try parser.parse(output: output)

        #expect(snapshot == PMSetSnapshot(
            sleepDisabled: true,
            sleepMinutes: 0,
            displaySleepMinutes: 5,
            diskSleepMinutes: 7
        ))
    }
}
