import Foundation
import Testing
@testable import AIPowerApp

struct MonitoredTrafficChartPresentationTests {
    @Test
    func buildsSingleThresholdGuideAndTimeAxis() {
        let presentation = MonitoredTrafficChartPresentation(
            valuesInKilobytes: [4, 18, 36, 92, 140],
            selectedThresholdKilobytes: 50
        )

        #expect(presentation.thresholdGuideLine?.label == "50 KB")
        #expect(presentation.thresholdGuideLine?.kilobytes == 50)
        #expect(presentation.timeAxisLabels == ["-60m", "-30m", "now"])
    }

    @Test
    func roundsLargePeaksToStableScaleBuckets() {
        let presentation = MonitoredTrafficChartPresentation(
            valuesInKilobytes: [8, 24, 42, 90, 8_192],
            selectedThresholdKilobytes: 80
        )
        let lastValue = presentation.normalizedValues.last ?? 0

        #expect(presentation.scaleLabel == "10 MB")
        #expect(presentation.chartCeilingKilobytes == 10_000)
        #expect(lastValue > 0.95)
        #expect((presentation.normalizedValues[1] - presentation.normalizedValues[0]) > 0.05)
        #expect((presentation.normalizedValues[3] - presentation.normalizedValues[2]) > 0.05)
    }
}
