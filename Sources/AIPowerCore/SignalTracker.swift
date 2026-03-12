public struct SignalTracker: Sendable {
    public let enterThreshold: Double
    public let exitThreshold: Double
    public let requiredConsecutiveSamples: Int

    public private(set) var isActive = false
    private var consecutiveAboveThresholdCount = 0

    public init(
        enterThreshold: Double,
        exitThreshold: Double,
        requiredConsecutiveSamples: Int
    ) {
        self.enterThreshold = enterThreshold
        self.exitThreshold = exitThreshold
        self.requiredConsecutiveSamples = requiredConsecutiveSamples
    }

    @discardableResult
    public mutating func update(with value: Double) -> Bool {
        if isActive {
            if value < exitThreshold {
                isActive = false
                consecutiveAboveThresholdCount = 0
            }

            return isActive
        }

        if value > enterThreshold {
            consecutiveAboveThresholdCount += 1
        } else {
            consecutiveAboveThresholdCount = 0
        }

        if consecutiveAboveThresholdCount >= requiredConsecutiveSamples {
            isActive = true
        }

        return isActive
    }
}
