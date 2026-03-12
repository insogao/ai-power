import Foundation

public enum AppMode: String, CaseIterable, Sendable {
    case off
    case auto
    case developer
    case manual

    public static let `default`: AppMode = .auto
}

public enum ContinuityMode: String, CaseIterable, Sendable {
    case standard
    case aiContinuity

    public static let `default`: ContinuityMode = .standard
}

public enum ActivityReason: Sendable, Equatable {
    case manualMode
    case developerProcess(String)
    case monitoredPort(Int)
    case cpuActivity
    case networkActivity
    case diskActivity
    case activityGrace

    public var displayText: String {
        switch self {
        case .manualMode:
            return "Manual mode enabled"
        case let .developerProcess(name):
            return "\(name) active"
        case let .monitoredPort(port):
            return "Port \(port) listening"
        case .cpuActivity:
            return "CPU activity detected"
        case .networkActivity:
            return "Network activity detected"
        case .diskActivity:
            return "Disk activity detected"
        case .activityGrace:
            return "Recent AI activity"
        }
    }
}

public struct MonitoringSnapshot: Sendable, Equatable {
    public let cpuUsagePercent: Double
    public let networkBytesPerSecond: Double
    public let diskBytesPerSecond: Double
    public let configuredApplicationKeywords: [String]
    public let configuredPorts: [Int]
    public let detectedApplicationKeywords: [String]
    public let activeApplicationKeywords: [String]
    public let listeningPorts: [Int]
    public let processCPUSamples: [DebugProcessCPUSample]
    public let processNetworkSamples: [DebugProcessNetworkSample]
    public let monitoredApplicationSamples: [MonitoredApplicationSample]

    public init(
        cpuUsagePercent: Double,
        networkBytesPerSecond: Double,
        diskBytesPerSecond: Double,
        configuredApplicationKeywords: [String] = [],
        configuredPorts: [Int] = [],
        detectedApplicationKeywords: [String],
        activeApplicationKeywords: [String],
        listeningPorts: [Int],
        processCPUSamples: [DebugProcessCPUSample] = [],
        processNetworkSamples: [DebugProcessNetworkSample] = [],
        monitoredApplicationSamples: [MonitoredApplicationSample] = []
    ) {
        self.cpuUsagePercent = cpuUsagePercent
        self.networkBytesPerSecond = networkBytesPerSecond
        self.diskBytesPerSecond = diskBytesPerSecond
        self.configuredApplicationKeywords = configuredApplicationKeywords
        self.configuredPorts = configuredPorts
        self.detectedApplicationKeywords = detectedApplicationKeywords
        self.activeApplicationKeywords = activeApplicationKeywords
        self.listeningPorts = listeningPorts
        self.processCPUSamples = processCPUSamples
        self.processNetworkSamples = processNetworkSamples
        self.monitoredApplicationSamples = monitoredApplicationSamples
    }
}

public struct DebugProcessCPUSample: Sendable, Equatable, Codable {
    public let processName: String
    public let cpuPercent: Double

    public init(processName: String, cpuPercent: Double) {
        self.processName = processName
        self.cpuPercent = cpuPercent
    }

    enum CodingKeys: String, CodingKey {
        case processName = "process"
        case cpuPercent = "cpu_percent"
    }
}

public struct DebugProcessNetworkSample: Sendable, Equatable, Codable {
    public let processName: String
    public let totalBytes: UInt64
    public let deltaBytes: UInt64

    public init(processName: String, totalBytes: UInt64, deltaBytes: UInt64) {
        self.processName = processName
        self.totalBytes = totalBytes
        self.deltaBytes = deltaBytes
    }

    enum CodingKeys: String, CodingKey {
        case processName = "process"
        case totalBytes = "total_bytes"
        case deltaBytes = "delta_bytes"
    }
}

public struct MonitoredApplicationSample: Sendable, Equatable, Codable {
    public let keyword: String
    public let isDetected: Bool
    public let networkDeltaBytes: UInt64
    public let cpuPercent: Double

    public init(
        keyword: String,
        isDetected: Bool,
        networkDeltaBytes: UInt64,
        cpuPercent: Double
    ) {
        self.keyword = keyword
        self.isDetected = isDetected
        self.networkDeltaBytes = networkDeltaBytes
        self.cpuPercent = cpuPercent
    }

    enum CodingKeys: String, CodingKey {
        case keyword
        case isDetected = "is_detected"
        case networkDeltaBytes = "network_delta_bytes"
        case cpuPercent = "cpu_percent"
    }
}

public struct DecisionOutcome: Sendable, Equatable {
    public let shouldPreventSleep: Bool
    public let reasons: [ActivityReason]

    public init(shouldPreventSleep: Bool, reasons: [ActivityReason]) {
        self.shouldPreventSleep = shouldPreventSleep
        self.reasons = reasons
    }

    public static let allowingSleep = DecisionOutcome(shouldPreventSleep: false, reasons: [])
}

public enum HardwareClass: Sendable, Equatable {
    case desktop
    case portable
}

public enum PowerSource: Sendable, Equatable {
    case ac
    case battery
    case unknown

    public var displayText: String {
        switch self {
        case .ac:
            return "AC power"
        case .battery:
            return "Battery power"
        case .unknown:
            return "Unknown power"
        }
    }
}

public enum HelperStatus: Sendable, Equatable {
    case notInstalled
    case requiresApproval
    case ready
    case degraded(reason: String)

    public var displayText: String {
        switch self {
        case .notInstalled:
            return "Not Installed"
        case .requiresApproval:
            return "Needs Approval"
        case .ready:
            return "Ready"
        case let .degraded(reason):
            return "Degraded: \(reason)"
        }
    }

    public var guidanceText: String? {
        switch self {
        case .notInstalled:
            return "Install the AI Continuity helper to enable closed-lid runs."
        case .requiresApproval:
            return "Approve AI Power in System Settings > Login Items & Extensions."
        case .ready:
            return nil
        case let .degraded(reason):
            return reason
        }
    }

    public var preparationButtonTitle: String {
        switch self {
        case .notInstalled:
            return "Install AI Continuity Helper"
        case .requiresApproval:
            return "Refresh Approval Status"
        case .ready:
            return "Refresh Helper Status"
        case .degraded:
            return "Retry Helper Setup"
        }
    }
}

public struct ContinuityEnvironment: Sendable, Equatable {
    public let hardwareClass: HardwareClass
    public let powerSource: PowerSource
    public let helperStatus: HelperStatus
    public let isClamshellClosed: Bool

    public init(
        hardwareClass: HardwareClass,
        powerSource: PowerSource,
        helperStatus: HelperStatus,
        isClamshellClosed: Bool
    ) {
        self.hardwareClass = hardwareClass
        self.powerSource = powerSource
        self.helperStatus = helperStatus
        self.isClamshellClosed = isClamshellClosed
    }
}

public struct WakeControlOptions: Sendable, Equatable {
    public var preventComputerSleep: Bool
    public var preventDisplaySleep: Bool
    public var preventLockScreen: Bool
    public var aiIdleGraceMinutes: Int

    public init(
        preventComputerSleep: Bool,
        preventDisplaySleep: Bool,
        preventLockScreen: Bool,
        aiIdleGraceMinutes: Int
    ) {
        self.preventComputerSleep = preventComputerSleep
        self.preventDisplaySleep = preventDisplaySleep
        self.preventLockScreen = preventLockScreen
        self.aiIdleGraceMinutes = aiIdleGraceMinutes
    }

    public static let `default` = WakeControlOptions(
        preventComputerSleep: true,
        preventDisplaySleep: false,
        preventLockScreen: false,
        aiIdleGraceMinutes: 5
    )
}

public struct AssertionConfiguration: Sendable, Equatable {
    public let reason: String
    public let preventDisplaySleep: Bool
    public let declareUserActivity: Bool

    public init(
        reason: String,
        preventDisplaySleep: Bool,
        declareUserActivity: Bool
    ) {
        self.reason = reason
        self.preventDisplaySleep = preventDisplaySleep
        self.declareUserActivity = declareUserActivity
    }
}

public enum AssertionIntent: Sendable, Equatable {
    case allowIdleSleep
    case preventSleep(AssertionConfiguration)
}

public enum HelperIntent: Sendable, Equatable {
    case inactive
    case installOrApprove
    case armPortableContinuity(reason: String)
    case disarm
}

public enum EffectiveCapability: Sendable, Equatable {
    case inactive
    case standard
    case desktopEnhanced
    case portableClamshellArmed
    case degraded

    public var displayText: String {
        switch self {
        case .inactive:
            return "Inactive"
        case .standard:
            return "Standard continuity"
        case .desktopEnhanced:
            return "Desktop AI Continuity"
        case .portableClamshellArmed:
            return "Portable closed-lid continuity armed"
        case .degraded:
            return "Degraded"
        }
    }
}

public struct ExecutionPolicy: Sendable, Equatable {
    public let assertionIntent: AssertionIntent
    public let helperIntent: HelperIntent
    public let effectiveCapability: EffectiveCapability
    public let userVisibleStatus: String

    public init(
        assertionIntent: AssertionIntent,
        helperIntent: HelperIntent,
        effectiveCapability: EffectiveCapability,
        userVisibleStatus: String
    ) {
        self.assertionIntent = assertionIntent
        self.helperIntent = helperIntent
        self.effectiveCapability = effectiveCapability
        self.userVisibleStatus = userVisibleStatus
    }
}

public struct MonitoringState: Sendable, Equatable {
    public let mode: AppMode
    public let continuityMode: ContinuityMode
    public let wakeControlOptions: WakeControlOptions
    public let snapshot: MonitoringSnapshot?
    public let outcome: DecisionOutcome
    public let continuityEnvironment: ContinuityEnvironment
    public let executionPolicy: ExecutionPolicy

    public init(
        mode: AppMode,
        continuityMode: ContinuityMode,
        wakeControlOptions: WakeControlOptions,
        snapshot: MonitoringSnapshot?,
        outcome: DecisionOutcome,
        continuityEnvironment: ContinuityEnvironment,
        executionPolicy: ExecutionPolicy
    ) {
        self.mode = mode
        self.continuityMode = continuityMode
        self.wakeControlOptions = wakeControlOptions
        self.snapshot = snapshot
        self.outcome = outcome
        self.continuityEnvironment = continuityEnvironment
        self.executionPolicy = executionPolicy
    }

    public static let initial = MonitoringState(
        mode: .default,
        continuityMode: .default,
        wakeControlOptions: .default,
        snapshot: nil,
        outcome: .allowingSleep,
        continuityEnvironment: ContinuityEnvironment(
            hardwareClass: .desktop,
            powerSource: .unknown,
            helperStatus: .notInstalled,
            isClamshellClosed: false
        ),
        executionPolicy: ExecutionPolicy(
            assertionIntent: .allowIdleSleep,
            helperIntent: .inactive,
            effectiveCapability: .inactive,
            userVisibleStatus: "Idle"
        )
    )
}

public struct MonitoringDebugRecord: Sendable, Equatable {
    public let timestamp: Date
    public let mode: AppMode
    public let cpuUsagePercent: Double
    public let networkBytesPerSecond: Double
    public let diskBytesPerSecond: Double
    public let configuredApplicationKeywords: [String]
    public let configuredPorts: [Int]
    public let detectedApplicationKeywords: [String]
    public let activeApplicationKeywords: [String]
    public let listeningPorts: [Int]
    public let reasons: [ActivityReason]
    public let shouldPreventSleep: Bool
    public let processCPUSamples: [DebugProcessCPUSample]
    public let processNetworkSamples: [DebugProcessNetworkSample]
    public let monitoredApplicationSamples: [MonitoredApplicationSample]

    public init(
        timestamp: Date,
        mode: AppMode,
        cpuUsagePercent: Double,
        networkBytesPerSecond: Double,
        diskBytesPerSecond: Double,
        configuredApplicationKeywords: [String] = [],
        configuredPorts: [Int] = [],
        detectedApplicationKeywords: [String],
        activeApplicationKeywords: [String],
        listeningPorts: [Int],
        reasons: [ActivityReason],
        shouldPreventSleep: Bool,
        processCPUSamples: [DebugProcessCPUSample] = [],
        processNetworkSamples: [DebugProcessNetworkSample] = [],
        monitoredApplicationSamples: [MonitoredApplicationSample] = []
    ) {
        self.timestamp = timestamp
        self.mode = mode
        self.cpuUsagePercent = cpuUsagePercent
        self.networkBytesPerSecond = networkBytesPerSecond
        self.diskBytesPerSecond = diskBytesPerSecond
        self.configuredApplicationKeywords = configuredApplicationKeywords
        self.configuredPorts = configuredPorts
        self.detectedApplicationKeywords = detectedApplicationKeywords
        self.activeApplicationKeywords = activeApplicationKeywords
        self.listeningPorts = listeningPorts
        self.reasons = reasons
        self.shouldPreventSleep = shouldPreventSleep
        self.processCPUSamples = processCPUSamples
        self.processNetworkSamples = processNetworkSamples
        self.monitoredApplicationSamples = monitoredApplicationSamples
    }
}
