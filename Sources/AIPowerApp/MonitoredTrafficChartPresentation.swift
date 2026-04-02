import Foundation

struct MonitoredTrafficChartPresentation: Sendable, Equatable {
    struct GuideLine: Sendable, Equatable, Identifiable {
        let kilobytes: Double
        let normalizedY: Double
        let label: String

        var id: String { label }
    }

    let chartCeilingKilobytes: Double
    let normalizedValues: [Double]
    let thresholdGuideLine: GuideLine?
    let scaleLabel: String
    let timeAxisLabels: [String]

    init(valuesInKilobytes: [Double], selectedThresholdKilobytes: Int) {
        let sanitizedValues = valuesInKilobytes.map { max($0, 0) }
        let sanitizedThreshold = max(selectedThresholdKilobytes, 0)

        let peakKilobytes = max(
            sanitizedValues.max() ?? 0,
            Double(sanitizedThreshold)
        )
        let ceiling = Self.ceilingBucket(for: peakKilobytes)

        chartCeilingKilobytes = ceiling
        normalizedValues = sanitizedValues.map { Self.normalizedValue(for: $0, ceilingKilobytes: ceiling) }
        thresholdGuideLine = sanitizedThreshold > 0 ? GuideLine(
            kilobytes: Double(sanitizedThreshold),
            normalizedY: Self.normalizedValue(for: Double(sanitizedThreshold), ceilingKilobytes: ceiling),
            label: "\(sanitizedThreshold) KB"
        ) : nil
        scaleLabel = Self.scaleLabel(for: ceiling)
        timeAxisLabels = ["-60m", "-30m", "now"]
    }

    private static func normalizedValue(for kilobytes: Double, ceilingKilobytes: Double) -> Double {
        guard kilobytes > 0, ceilingKilobytes > 0 else {
            return 0
        }

        return log10(kilobytes + 1) / log10(ceilingKilobytes + 1)
    }

    private static func ceilingBucket(for peakKilobytes: Double) -> Double {
        let buckets: [Double] = [10, 30, 50, 80, 100, 300, 1_000, 3_000, 10_000, 30_000, 100_000]
        return buckets.first(where: { peakKilobytes <= $0 }) ?? 100_000
    }

    private static func scaleLabel(for ceilingKilobytes: Double) -> String {
        if ceilingKilobytes >= 1_000 {
            let megabytes = ceilingKilobytes / 1_000
            if megabytes.rounded(.towardZero) == megabytes {
                return "\(Int(megabytes)) MB"
            }
            return String(format: "%.1f MB", megabytes)
        }

        return "\(Int(ceilingKilobytes.rounded())) KB"
    }
}
