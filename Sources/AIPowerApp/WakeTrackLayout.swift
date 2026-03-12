import CoreGraphics
import Foundation

struct WakeTrackLayout {
    enum SnapZone: Equatable {
        case ai
        case off
        case infinity
    }

    struct Tick: Sendable, Equatable {
        let title: String
        let position: Double
    }

    let aiRange: ClosedRange<Double>
    let offRange: ClosedRange<Double>
    let timedStart: Double
    let timedEnd: Double
    let infinitySnapStart: Double
    let infinityAnchor: Double
    let infinityLabelPosition: Double
    let minimumTimedDuration: TimeInterval
    let maximumTimedDuration: TimeInterval
    let trackThickness: CGFloat
    let trackCenterY: CGFloat
    let knobCenterY: CGFloat
    let tickY: CGFloat
    let knobOuterDiameter: CGFloat
    let knobInnerDiameter: CGFloat

    static let `default` = WakeTrackLayout(
        aiRange: 0.00...0.13,
        offRange: 0.13...0.25,
        timedStart: 0.25,
        timedEnd: 0.84,
        infinitySnapStart: 0.89,
        infinityAnchor: 0.95,
        infinityLabelPosition: 0.95,
        minimumTimedDuration: 30 * 60,
        maximumTimedDuration: 3 * 24 * 60 * 60,
        trackThickness: 16,
        trackCenterY: 21,
        knobCenterY: 21,
        tickY: 58,
        knobOuterDiameter: 18,
        knobInnerDiameter: 8
    )

    var aiCenter: Double {
        (aiRange.lowerBound + aiRange.upperBound) / 2
    }

    var offCenter: Double {
        (offRange.lowerBound + offRange.upperBound) / 2
    }

    var ticks: [Tick] {
        [
            Tick(title: "AI", position: aiCenter),
            Tick(title: "Off", position: offCenter),
            Tick(title: "30m", position: timedStart),
            Tick(title: "1h", position: position(for: .timed(duration: 60 * 60))),
            Tick(title: "3h", position: position(for: .timed(duration: 3 * 60 * 60))),
            Tick(title: "8h", position: position(for: .timed(duration: 8 * 60 * 60))),
            Tick(title: "1d", position: position(for: .timed(duration: 24 * 60 * 60))),
            Tick(title: "3d", position: position(for: .timed(duration: 3 * 24 * 60 * 60))),
        ]
    }

    func selection(forNormalizedPosition normalizedPosition: CGFloat) -> WakeTrackSelection {
        let normalized = Double(normalizedPosition)

        if normalized >= aiRange.lowerBound && normalized < aiRange.upperBound {
            return .aiMode
        }

        if normalized >= offRange.lowerBound && normalized < offRange.upperBound {
            return .off
        }

        if normalized >= infinitySnapStart {
            return .infinity
        }

        let clamped = max(timedStart, min(timedEnd, normalized))
        let t = (clamped - timedStart) / (timedEnd - timedStart)
        let ratio = maximumTimedDuration / minimumTimedDuration
        let duration = minimumTimedDuration * pow(ratio, t)
        return .timed(duration: duration)
    }

    func snapZone(forNormalizedPosition normalizedPosition: CGFloat) -> SnapZone? {
        let normalized = Double(normalizedPosition)
        if normalized >= aiRange.lowerBound && normalized < aiRange.upperBound {
            return .ai
        }

        if normalized >= offRange.lowerBound && normalized < offRange.upperBound {
            return .off
        }

        if normalized >= infinitySnapStart {
            return .infinity
        }

        return nil
    }

    func position(for selection: WakeTrackSelection) -> Double {
        switch selection {
        case .aiMode:
            return aiCenter
        case .off:
            return offCenter
        case .infinity:
            return infinityAnchor
        case let .timed(duration):
            let clamped = max(minimumTimedDuration, min(maximumTimedDuration, duration))
            let ratio = maximumTimedDuration / minimumTimedDuration
            let t = log(clamped / minimumTimedDuration) / log(ratio)
            return timedStart + (timedEnd - timedStart) * t
        }
    }
}
