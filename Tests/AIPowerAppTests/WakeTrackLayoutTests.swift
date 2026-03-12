import Foundation
import Testing
@testable import AIPowerApp

struct WakeTrackLayoutTests {
    @Test
    func leftZonesAreContiguousAndKnobStaysOnTrackAxis() {
        let layout = WakeTrackLayout.default

        #expect(layout.aiRange.upperBound == layout.offRange.lowerBound)
        #expect(layout.offRange.upperBound == layout.timedStart)
        #expect(layout.knobCenterY == layout.trackCenterY)
    }

    @Test
    func aiAndOffRemainDedicatedSnapZones() {
        let layout = WakeTrackLayout.default

        #expect(layout.selection(forNormalizedPosition: 0.05) == .aiMode)
        #expect(layout.selection(forNormalizedPosition: 0.20) == .off)
    }

    @Test
    func timedAxisStartsImmediatelyAfterOffAndStaysContinuous() throws {
        let layout = WakeTrackLayout.default

        let timedSelection = layout.selection(forNormalizedPosition: layout.timedStart)
        guard case let .timed(duration) = timedSelection else {
            throw TestFailure("Expected a timed selection at the start of the time axis.")
        }

        #expect(abs(duration - layout.minimumTimedDuration) < 1)

        let laterSelection = layout.selection(forNormalizedPosition: 0.70)
        guard case let .timed(laterDuration) = laterSelection else {
            throw TestFailure("Expected the time axis to stay continuous across the right side.")
        }

        #expect(laterDuration > duration)
        #expect(layout.position(for: .timed(duration: layout.maximumTimedDuration)) == layout.timedEnd)
    }

    @Test
    func infinityZoneGetsDedicatedSpaceInsteadOfOverlappingThreeDayTick() {
        let layout = WakeTrackLayout.default

        #expect(layout.ticks.map(\.title).contains("∞") == false)
        #expect(layout.infinityLabelPosition == layout.infinityAnchor)
        #expect(layout.timedEnd < layout.infinitySnapStart)
        #expect(layout.infinitySnapStart < layout.infinityAnchor)
        let threeDayPosition = layout.position(for: .timed(duration: layout.maximumTimedDuration))
        #expect(threeDayPosition == layout.timedEnd)
        #expect(layout.infinityAnchor - threeDayPosition >= 0.10)
        #expect(layout.knobOuterDiameter == 18)
        #expect(layout.knobInnerDiameter == 8)
        #expect(layout.trackThickness == 16)
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
