import Testing
@testable import AIPowerCore

struct SignalTrackerTests {
    @Test
    func activatesOnlyAfterDwellTime() {
        var tracker = SignalTracker(
            enterThreshold: 30,
            exitThreshold: 15,
            requiredConsecutiveSamples: 10
        )

        for _ in 0..<9 {
            #expect(tracker.update(with: 31) == false)
        }

        #expect(tracker.update(with: 31) == true)
        #expect(tracker.isActive == true)
    }

    @Test
    func staysActiveUntilValueDropsBelowExitThreshold() {
        var tracker = SignalTracker(
            enterThreshold: 30,
            exitThreshold: 15,
            requiredConsecutiveSamples: 10
        )

        for _ in 0..<10 {
            _ = tracker.update(with: 31)
        }

        #expect(tracker.isActive == true)
        #expect(tracker.update(with: 20) == true)
        #expect(tracker.isActive == true)
        #expect(tracker.update(with: 14) == false)
        #expect(tracker.isActive == false)
    }
}
