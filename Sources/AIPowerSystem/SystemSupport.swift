import AIPowerCore
import AIPowerHelperSupport
import AIPowerIPC
import AppKit
import Foundation
import IOKit
import IOKit.pwr_mgt
import IOKit.ps
import IOKit.storage
import ServiceManagement
import Darwin
import MachO

public enum SystemSamplingError: Error {
    case cpuCountersUnavailable
    case diskCountersUnavailable
}

public actor LiveMonitoringSampler: MonitoringSampling {
    private var previousCPUTicks: CPUTickSnapshot?
    private var previousNetworkBytes: UInt64?
    private var previousDiskBytes: UInt64?
    private var previousSampleDate: Date?
    private var previousProcessNetworkTotals: [String: UInt64] = [:]

    public init() {}

    public func sample() async throws -> MonitoringSnapshot {
        let now = Date()
        let elapsedSeconds = max(now.timeIntervalSince(previousSampleDate ?? now), 1)

        let currentCPUTicks = try Self.readCPUTicks()
        let currentNetworkBytes = Self.readNetworkBytes()
        let currentDiskBytes = try Self.readDiskBytes()
        let cpuSamples = Self.normalizePerProcessCPUSamples(Self.readPerProcessCPUSamples())
        let networkSamples = Self.normalizePerProcessNetworkSamples(Self.readPerProcessNetworkTotals())
        let processNetworkSamples = Self.buildProcessNetworkSamples(
            currentTotals: networkSamples,
            previousTotals: previousProcessNetworkTotals
        )
        let configuredKeywords = ProcessKeywordConfiguration.allKeywords()
        let configuredPorts = AIModePortConfiguration.allPorts()
        let cliProcessCandidates = DeveloperProcessScanner.cliProcessCandidates()
        let appBundleCandidates = await MainActor.run {
            DeveloperProcessScanner.appBundleCandidates()
        }
        let detectedApplications = DeveloperProcessScanner.detectActiveProcesses(
            appBundleCandidates: appBundleCandidates,
            cliProcessCandidates: cliProcessCandidates,
            keywords: configuredKeywords
        )
        let monitoredApplicationSamples = Self.buildMonitoredApplicationSamples(
            configuredKeywords: configuredKeywords,
            detectedKeywords: detectedApplications,
            cpuSamples: cpuSamples,
            networkSamples: processNetworkSamples
        )
        let activeApplications = Self.readActiveApplicationKeywords(
            monitoredApplicationSamples: monitoredApplicationSamples
        )
        let listeningPorts = Self.readListeningPorts(
            monitoredPorts: configuredPorts
        )

        let cpuUsagePercent = Self.cpuUsagePercent(
            current: currentCPUTicks,
            previous: previousCPUTicks
        )
        let networkBytesPerSecond = Self.bytesPerSecond(
            current: currentNetworkBytes,
            previous: previousNetworkBytes,
            elapsedSeconds: elapsedSeconds
        )
        let diskBytesPerSecond = Self.bytesPerSecond(
            current: currentDiskBytes,
            previous: previousDiskBytes,
            elapsedSeconds: elapsedSeconds
        )

        previousCPUTicks = currentCPUTicks
        previousNetworkBytes = currentNetworkBytes
        previousDiskBytes = currentDiskBytes
        previousSampleDate = now
        previousProcessNetworkTotals = Dictionary(
            uniqueKeysWithValues: networkSamples.map { ($0.processName, $0.totalBytes) }
        )

        return MonitoringSnapshot(
            cpuUsagePercent: cpuUsagePercent,
            networkBytesPerSecond: networkBytesPerSecond,
            diskBytesPerSecond: diskBytesPerSecond,
            configuredApplicationKeywords: configuredKeywords,
            configuredPorts: configuredPorts,
            detectedApplicationKeywords: detectedApplications,
            activeApplicationKeywords: activeApplications,
            listeningPorts: listeningPorts,
            processCPUSamples: cpuSamples.map {
                DebugProcessCPUSample(processName: $0.processName, cpuPercent: $0.cpuPercent)
            },
            processNetworkSamples: processNetworkSamples,
            monitoredApplicationSamples: monitoredApplicationSamples
        )
    }

    static func normalizePerProcessCPUSamples(_ samples: [PerProcessCPUSample]) -> [PerProcessCPUSample] {
        let aggregated = samples.reduce(into: [String: Double]()) { partialResult, sample in
            partialResult[sample.processName, default: 0] += sample.cpuPercent
        }

        return aggregated.map { processName, cpuPercent in
            PerProcessCPUSample(processName: processName, cpuPercent: cpuPercent)
        }
        .sorted { lhs, rhs in
            if lhs.cpuPercent == rhs.cpuPercent {
                return lhs.processName < rhs.processName
            }
            return lhs.cpuPercent > rhs.cpuPercent
        }
    }

    static func normalizePerProcessNetworkSamples(_ samples: [PerProcessNetworkSample]) -> [PerProcessNetworkSample] {
        let aggregated = samples.reduce(into: [String: UInt64]()) { partialResult, sample in
            partialResult[sample.processName, default: 0] += sample.totalBytes
        }

        return aggregated.map { processName, totalBytes in
            PerProcessNetworkSample(processName: processName, totalBytes: totalBytes)
        }
        .sorted { lhs, rhs in
            if lhs.totalBytes == rhs.totalBytes {
                return lhs.processName < rhs.processName
            }
            return lhs.totalBytes > rhs.totalBytes
        }
    }

    private static func cpuUsagePercent(
        current: CPUTickSnapshot,
        previous: CPUTickSnapshot?
    ) -> Double {
        guard let previous else {
            return 0
        }

        let user = current.user - previous.user
        let system = current.system - previous.system
        let idle = current.idle - previous.idle
        let nice = current.nice - previous.nice
        let total = user + system + idle + nice
        guard total > 0 else {
            return 0
        }

        let busy = user + system + nice
        return Double(busy) / Double(total) * 100
    }

    private static func bytesPerSecond(
        current: UInt64,
        previous: UInt64?,
        elapsedSeconds: TimeInterval
    ) -> Double {
        guard let previous else {
            return 0
        }

        let delta = current >= previous ? current - previous : 0
        return Double(delta) / elapsedSeconds
    }

    private static func readCPUTicks() throws -> CPUTickSnapshot {
        var loadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &loadInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics(
                    mach_host_self(),
                    HOST_CPU_LOAD_INFO,
                    reboundPointer,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            throw SystemSamplingError.cpuCountersUnavailable
        }

        return CPUTickSnapshot(
            user: UInt64(loadInfo.cpu_ticks.0),
            system: UInt64(loadInfo.cpu_ticks.1),
            idle: UInt64(loadInfo.cpu_ticks.2),
            nice: UInt64(loadInfo.cpu_ticks.3)
        )
    }

    private static func readNetworkBytes() -> UInt64 {
        var addressPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressPointer) == 0, let firstAddress = addressPointer else {
            return 0
        }

        defer { freeifaddrs(addressPointer) }

        var totalBytes: UInt64 = 0
        for cursor in sequence(first: firstAddress, next: { $0.pointee.ifa_next }) {
            let flags = Int32(cursor.pointee.ifa_flags)
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            let isUp = (flags & IFF_UP) != 0
            guard isLoopback == false, isUp else {
                continue
            }

            guard
                cursor.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
                let dataPointer = cursor.pointee.ifa_data
            else {
                continue
            }

            let networkData = dataPointer.assumingMemoryBound(to: if_data.self).pointee
            totalBytes += UInt64(networkData.ifi_ibytes)
            totalBytes += UInt64(networkData.ifi_obytes)
        }

        return totalBytes
    }

    private static func readDiskBytes() throws -> UInt64 {
        let matching = IOServiceMatching("IOBlockStorageDriver")
        var iterator: io_iterator_t = 0

        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else {
            throw SystemSamplingError.diskCountersUnavailable
        }

        defer { IOObjectRelease(iterator) }

        var totalBytes: UInt64 = 0
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else {
                break
            }

            defer { IOObjectRelease(service) }

            var properties: Unmanaged<CFMutableDictionary>?
            let propertyResult = IORegistryEntryCreateCFProperties(
                service,
                &properties,
                kCFAllocatorDefault,
                0
            )
            guard propertyResult == KERN_SUCCESS,
                  let dictionary = properties?.takeRetainedValue() as? [String: Any],
                  let statistics = dictionary[kIOBlockStorageDriverStatisticsKey] as? [String: Any]
            else {
                continue
            }

            totalBytes += uint64(from: statistics[kIOBlockStorageDriverStatisticsBytesReadKey])
            totalBytes += uint64(from: statistics[kIOBlockStorageDriverStatisticsBytesWrittenKey])
        }

        return totalBytes
    }

    private static func uint64(from value: Any?) -> UInt64 {
        switch value {
        case let value as NSNumber:
            return value.uint64Value
        case let value as UInt64:
            return value
        case let value as Int:
            return UInt64(max(value, 0))
        default:
            return 0
        }
    }

    static func readActiveApplicationKeywords(
        monitoredApplicationSamples: [MonitoredApplicationSample]
    ) -> [String] {
        monitoredApplicationSamples
            .filter { $0.networkDeltaBytes > 0 }
            .map(\.keyword)
    }

    static func buildMonitoredApplicationSamples(
        configuredKeywords: [String],
        detectedKeywords: [String],
        cpuSamples: [PerProcessCPUSample],
        networkSamples: [DebugProcessNetworkSample]
    ) -> [MonitoredApplicationSample] {
        configuredKeywords.map { keyword in
            let aliases = activityAliases(for: keyword)
            let detected = detectedKeywords.contains(keyword)
            let supportingAliases = detected ? supportingProcessAliases(for: keyword) : []

            let cpuPercent = cpuSamples.reduce(into: Double(0)) { total, sample in
                if matches(sample.processName, aliases: aliases, supportingAliases: supportingAliases, keyword: keyword) {
                    total += sample.cpuPercent
                }
            }

            let networkDeltaBytes = networkSamples.reduce(into: UInt64(0)) { total, sample in
                if matches(sample.processName, aliases: aliases, supportingAliases: supportingAliases, keyword: keyword) {
                    total += sample.deltaBytes
                }
            }

            return MonitoredApplicationSample(
                keyword: keyword,
                isDetected: detected,
                networkDeltaBytes: networkDeltaBytes,
                cpuPercent: cpuPercent
            )
        }
    }

    private static func matches(
        _ processName: String,
        aliases: [String],
        supportingAliases: [String],
        keyword: String
    ) -> Bool {
        let normalizedProcessName = processName.lowercased()
        let matchedAlias = aliases.contains(where: { normalizedProcessName.contains($0) })
        let matchedSupportingAlias = supportingAliases.contains(where: { normalizedProcessName.contains($0) })
        guard matchedAlias || matchedSupportingAlias else {
            return false
        }

        return ActivityProcessFilter.shouldIgnore(processName: normalizedProcessName, for: keyword) == false
    }

    private static func buildProcessNetworkSamples(
        currentTotals: [PerProcessNetworkSample],
        previousTotals: [String: UInt64]
    ) -> [DebugProcessNetworkSample] {
        currentTotals.map { sample in
            let previousTotal = previousTotals[sample.processName] ?? 0
            let delta = sample.totalBytes >= previousTotal ? sample.totalBytes - previousTotal : 0
            return DebugProcessNetworkSample(
                processName: sample.processName,
                totalBytes: sample.totalBytes,
                deltaBytes: delta
            )
        }
    }

    private static func readListeningPorts(monitoredPorts: [Int]) -> [Int] {
        guard monitoredPorts.isEmpty == false else {
            return []
        }

        let output = (try? runCommand(
            executableURL: URL(fileURLWithPath: "/usr/sbin/lsof"),
            arguments: ["-nP", "-iTCP", "-sTCP:LISTEN"]
        )) ?? ""
        let listeningPorts = parseListeningPorts(from: output)
        return monitoredPorts.filter { listeningPorts.contains($0) }
    }

    private static func readPerProcessCPUSamples() -> [PerProcessCPUSample] {
        let output = (try? runCommand(
            executableURL: URL(fileURLWithPath: "/bin/ps"),
            arguments: ["-axo", "%cpu=,comm="]
        )) ?? ""
        return parsePerProcessCPUSamples(from: output)
    }

    private static func readPerProcessNetworkTotals() -> [PerProcessNetworkSample] {
        let output = (try? runCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/nettop"),
            arguments: ["-P", "-L", "1", "-n", "-x"]
        )) ?? ""
        return parsePerProcessNetworkSamples(from: output)
    }

    static func runCommand(
        executableURL: URL,
        arguments: [String]
    ) throws -> String {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return ""
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }

    private static func parsePerProcessCPUSamples(from output: String) -> [PerProcessCPUSample] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.isEmpty == false else {
                    return nil
                }

                let parts = trimmed.split(maxSplits: 1, whereSeparator: \.isWhitespace)
                guard parts.count == 2, let cpu = Double(parts[0]) else {
                    return nil
                }

                return PerProcessCPUSample(
                    processName: parts[1].lowercased(),
                    cpuPercent: cpu
                )
            }
    }

    private static func parsePerProcessNetworkSamples(from output: String) -> [PerProcessNetworkSample] {
        output
            .split(whereSeparator: \.isNewline)
            .dropFirst()
            .compactMap { line in
                let columns = line.split(separator: ",", omittingEmptySubsequences: false)
                guard columns.count > 5 else {
                    return nil
                }

                let rawName = String(columns[1]).lowercased()
                let normalizedName = rawName.replacingOccurrences(
                    of: #"\.\d+$"#,
                    with: "",
                    options: .regularExpression
                )
                let bytesIn = UInt64(columns[4]) ?? 0
                let bytesOut = UInt64(columns[5]) ?? 0

                return PerProcessNetworkSample(
                    processName: normalizedName,
                    totalBytes: bytesIn + bytesOut
                )
            }
    }

    private static func parseListeningPorts(from output: String) -> Set<Int> {
        Set(
            output
                .split(whereSeparator: \.isNewline)
                .compactMap { line in
                    let text = String(line)
                    guard text.contains("(LISTEN)") else {
                        return nil
                    }
                    guard let match = text.range(of: #":(\d+)\s+\(LISTEN\)"#, options: .regularExpression) else {
                        return nil
                    }

                    let value = String(text[match]).replacingOccurrences(
                        of: #"[^0-9]"#,
                        with: "",
                        options: .regularExpression
                    )
                    return Int(value)
                }
        )
    }

    private static func activityAliases(for keyword: String) -> [String] {
        switch keyword {
        case "codex":
            return ["codex", "codex helper"]
        case "vscode":
            return ["vscode", "visual studio code", "code helper"]
        case "cursor":
            return ["cursor", "cursor helper"]
        case "zed":
            return ["zed"]
        case "kiro":
            return ["kiro"]
        case "claude":
            return ["claude", "claude code"]
        case "gemini":
            return ["gemini", "gemini-cli"]
        case "qwen":
            return ["qwen", "qwen code", "qwen-code"]
        case "opencode":
            return ["opencode", "open code"]
        case "aider":
            return ["aider"]
        case "goose":
            return ["goose"]
        case "continue":
            return ["continue"]
        case "junie":
            return ["junie"]
        case "augment":
            return ["augment", "augment code"]
        case "copilot":
            return ["copilot", "github copilot"]
        case "cline":
            return ["cline"]
        case "roo":
            return ["roo", "roo code", "roo-cline"]
        case "qodo":
            return ["qodo", "qodo gen"]
        case "cody":
            return ["cody", "sourcegraph cody"]
        case "lingma":
            return ["lingma", "tongyi lingma", "tongyi-lingma"]
        case "tabnine":
            return ["tabnine"]
        case "windsurf":
            return ["windsurf"]
        case "antigravity":
            return ["antigravity"]
        case "kimi":
            return ["kimi", "kimi code"]
        default:
            return [keyword]
        }
    }

    private static func supportingProcessAliases(for keyword: String) -> [String] {
        switch keyword {
        case "kimi":
            return ["python"]
        case "copilot":
            return ["code helper"]
        default:
            return []
        }
    }
}

struct PerProcessCPUSample: Equatable {
    let processName: String
    let cpuPercent: Double
}

struct PerProcessNetworkSample: Equatable {
    let processName: String
    let totalBytes: UInt64
}

enum ActivityProcessFilter {
    static func shouldIgnore(processName: String, for keyword: String) -> Bool {
        switch keyword {
        case "cursor":
            return processName == "cursoruiviewservice"
        default:
            return false
        }
    }

    static func shouldIgnore(candidate: ProcessScanCandidate, for keyword: String) -> Bool {
        switch keyword {
        case "cursor":
            let fields = [
                candidate.localizedName?.lowercased(),
                candidate.bundleIdentifier?.lowercased(),
                candidate.executableName?.lowercased(),
                candidate.bundlePath?.lowercased(),
            ]
            .compactMap { $0 }

            return fields.contains(where: {
                $0.contains("cursoruiviewservice") ||
                    $0.contains("com.apple.cursoruiviewservice") ||
                    $0.contains("com.apple.textinputui.xpc.cursoruiviewservice")
            })
        default:
            return false
        }
    }
}

@MainActor
public final class PowerAssertionController: SleepAssertionControlling {
    private var systemSleepAssertionID: IOPMAssertionID = 0
    private var displaySleepAssertionID: IOPMAssertionID = 0
    private var userActivityAssertionID: IOPMAssertionID = 0
    private var currentConfiguration: AssertionConfiguration?

    public init() {}

    public func apply(intent: AssertionIntent) {
        switch intent {
        case .allowIdleSleep:
            currentConfiguration = nil
            releaseAssertions()

        case let .preventSleep(configuration):
            currentConfiguration = configuration
            ensureSystemSleepAssertion(reason: configuration.reason)
            ensureDisplaySleepAssertion(
                enabled: configuration.preventDisplaySleep,
                reason: configuration.reason
            )
            declareUserActivityIfNeeded(
                enabled: configuration.declareUserActivity,
                reason: configuration.reason
            )
        }
    }

    private func ensureSystemSleepAssertion(reason: String) {
        releaseAssertion(&systemSleepAssertionID)

        var newAssertionID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &newAssertionID
        )

        guard result == kIOReturnSuccess else {
            return
        }

        systemSleepAssertionID = newAssertionID
    }

    private func ensureDisplaySleepAssertion(enabled: Bool, reason: String) {
        guard enabled else {
            releaseAssertion(&displaySleepAssertionID)
            return
        }

        releaseAssertion(&displaySleepAssertionID)

        var newAssertionID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &newAssertionID
        )

        guard result == kIOReturnSuccess else {
            return
        }

        displaySleepAssertionID = newAssertionID
    }

    private func declareUserActivityIfNeeded(enabled: Bool, reason: String) {
        guard enabled else {
            releaseAssertion(&userActivityAssertionID)
            return
        }

        var existingAssertionID = userActivityAssertionID
        let result = IOPMAssertionDeclareUserActivity(
            reason as CFString,
            kIOPMUserActiveLocal,
            &existingAssertionID
        )

        guard result == kIOReturnSuccess else {
            return
        }

        userActivityAssertionID = existingAssertionID
    }

    private func releaseAssertions() {
        releaseAssertion(&systemSleepAssertionID)
        releaseAssertion(&displaySleepAssertionID)
        releaseAssertion(&userActivityAssertionID)
    }

    private func releaseAssertion(_ assertionID: inout IOPMAssertionID) {
        guard assertionID != 0 else {
            return
        }

        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }
}

@MainActor
public final class LiveContinuityEnvironmentProvider: ContinuityEnvironmentProviding {
    private let helperManager: any ContinuityHelperManaging

    public init(helperManager: any ContinuityHelperManaging) {
        self.helperManager = helperManager
    }

    public func currentEnvironment() async -> ContinuityEnvironment {
        ContinuityEnvironment(
            hardwareClass: Self.detectHardwareClass(),
            powerSource: Self.detectPowerSource(),
            helperStatus: await helperManager.status(),
            isClamshellClosed: Self.detectClamshellState()
        )
    }

    private static func detectHardwareClass() -> HardwareClass {
        hasInternalBattery() ? .portable : .desktop
    }

    private static func detectPowerSource() -> PowerSource {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return .unknown
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
                    as? [String: Any],
                  let state = description[kIOPSPowerSourceStateKey] as? String
            else {
                continue
            }

            if state == kIOPSACPowerValue {
                return .ac
            }
            if state == kIOPSBatteryPowerValue {
                return .battery
            }
        }

        return hasInternalBattery() ? .battery : .unknown
    }

    private static func detectClamshellState() -> Bool {
        let root = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/IOPMrootDomain")
        guard root != 0 else {
            return false
        }

        defer { IOObjectRelease(root) }

        guard let property = IORegistryEntryCreateCFProperty(
            root,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue()
        else {
            return false
        }

        switch property {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        default:
            return false
        }
    }

    private static func hasInternalBattery() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return false
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
                    as? [String: Any],
                  let type = description[kIOPSTypeKey] as? String
            else {
                continue
            }

            if type == kIOPSInternalBatteryType {
                return true
            }
        }

        return false
    }
}

@MainActor
public protocol ContinuityHelperManaging: AnyObject {
    func installOrRegister() async -> HelperPreparationResult
    func status() async -> HelperStatus
    func apply(intent: HelperIntent) async
    func restoreBaselinePolicy() async
    func fetchRecoveryState() async -> String?
}

public protocol ContinuityService {
    func registerHelper() throws
    func helperStatus() -> HelperStatus
    func applyPortableContinuity(reason: String) throws
    func restoreBaselinePolicy() throws
    func fetchRecoveryState() throws -> String?
}

public struct HelperPreparationResult: Sendable, Equatable {
    public let status: HelperStatus
    public let message: String?

    public init(status: HelperStatus, message: String?) {
        self.status = status
        self.message = message
    }
}

public enum SMAppServiceRegistrationStatus: Sendable, Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
}

private enum HelperRuntimeValidationError: LocalizedError {
    case notRunningFromAppBundle
    case missingEmbeddedPayload

    var errorDescription: String? {
        switch self {
        case .notRunningFromAppBundle:
            return "AI Continuity helper can only be installed from the signed AI Power.app bundle."
        case .missingEmbeddedPayload:
            return "Embedded helper payload is missing from the running app bundle."
        }
    }
}

public enum ContinuityDaemonClientRequest: Sendable, Equatable {
    case queryStatus
    case armPortableContinuity(reason: String)
    case restoreBaseline
    case fetchRecoveryState
}

public protocol ContinuityDaemonClient {
    func send(_ request: ContinuityDaemonClientRequest) throws -> ContinuityDaemonReply
}

public final class XPCContinuityDaemonClient: ContinuityDaemonClient {
    private let machServiceName: String

    public init(machServiceName: String = ContinuityXPC.machServiceName) {
        self.machServiceName = machServiceName
    }

    public func send(_ request: ContinuityDaemonClientRequest) throws -> ContinuityDaemonReply {
        let connection = NSXPCConnection(machServiceName: machServiceName, options: .privileged)
        connection.remoteObjectInterface = Self.makeInterface()
        connection.resume()
        defer { connection.invalidate() }

        var returnedError: Error?
        var reply: ContinuityDaemonReply?
        let proxy = connection.synchronousRemoteObjectProxyWithErrorHandler { error in
            returnedError = error
        }

        guard let daemon = proxy as? ContinuityDaemonXPCProtocol else {
            throw NSError(
                domain: "AIPowerSystem.XPCContinuityDaemonClient",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to connect to continuity daemon"]
            )
        }

        switch request {
        case .queryStatus:
            daemon.queryStatus { daemonReply in
                reply = daemonReply
            }
        case let .armPortableContinuity(reason):
            daemon.apply(
                ContinuityDaemonRequest(action: .armPortableContinuity, reason: reason)
            ) { daemonReply in
                reply = daemonReply
            }
        case .restoreBaseline:
            daemon.restoreBaseline { daemonReply in
                reply = daemonReply
            }
        case .fetchRecoveryState:
            daemon.fetchRecoveryState { daemonReply in
                reply = daemonReply
            }
        }

        if let returnedError {
            throw returnedError
        }

        guard let reply else {
            throw NSError(
                domain: "AIPowerSystem.XPCContinuityDaemonClient",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Continuity daemon did not return a reply"]
            )
        }

        return reply
    }

    private static func makeInterface() -> NSXPCInterface {
        NSXPCInterface(with: ContinuityDaemonXPCProtocol.self)
    }
}

public struct SMAppContinuityService: ContinuityService {
    private let registerHandler: () throws -> Void
    private let statusProvider: () -> SMAppServiceRegistrationStatus
    private let daemonClient: any ContinuityDaemonClient
    private let bundleURLProvider: () -> URL
    private let fileManager: FileManager

    public init(
        registerHandler: (() throws -> Void)? = nil,
        statusProvider: (() -> SMAppServiceRegistrationStatus)? = nil,
        daemonClient: any ContinuityDaemonClient = XPCContinuityDaemonClient(),
        bundleURLProvider: @escaping () -> URL = { Bundle.main.bundleURL },
        fileManager: FileManager = .default
    ) {
        self.registerHandler = registerHandler ?? {
            guard #available(macOS 13.0, *) else {
                return
            }

            let service = SMAppService.daemon(plistName: ContinuityXPC.launchDaemonPlistName)
            switch service.status {
            case .enabled, .requiresApproval:
                try? service.unregister()
            case .notRegistered, .notFound:
                break
            @unknown default:
                break
            }

            try service.register()
        }
        self.statusProvider = statusProvider ?? {
            guard #available(macOS 13.0, *) else {
                return .notFound
            }

            switch SMAppService.daemon(plistName: ContinuityXPC.launchDaemonPlistName).status {
            case .notRegistered:
                return .notRegistered
            case .enabled:
                return .enabled
            case .requiresApproval:
                return .requiresApproval
            case .notFound:
                return .notFound
            @unknown default:
                return .notFound
            }
        }
        self.daemonClient = daemonClient
        self.bundleURLProvider = bundleURLProvider
        self.fileManager = fileManager
    }

    public func registerHelper() throws {
        try validateRuntimePrerequisites()
        try registerHandler()
    }

    public func helperStatus() -> HelperStatus {
        if let validationError = runtimePrerequisiteError() {
            return .degraded(reason: validationError.localizedDescription)
        }

        switch statusProvider() {
        case .notRegistered:
            return .notInstalled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .degraded(reason: "Closed-lid access is not enabled yet")
        case .enabled:
            break
        }

        do {
            return try daemonClient.send(.queryStatus).helperStatus
        } catch {
            return .degraded(reason: "Unable to reach helper daemon")
        }
    }

    public func applyPortableContinuity(reason: String) throws {
        _ = try daemonClient.send(.armPortableContinuity(reason: reason))
    }

    public func restoreBaselinePolicy() throws {
        _ = try daemonClient.send(.restoreBaseline)
    }

    public func fetchRecoveryState() throws -> String? {
        try daemonClient.send(.fetchRecoveryState).recoveryReason
    }

    private func validateRuntimePrerequisites() throws {
        if let validationError = runtimePrerequisiteError() {
            throw validationError
        }
    }

    private func runtimePrerequisiteError() -> HelperRuntimeValidationError? {
        let bundleURL = bundleURLProvider()
        guard bundleURL.pathExtension == "app" else {
            return .notRunningFromAppBundle
        }

        let helperURL = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent("AIPowerContinuityHelper")
        let daemonPlistURL = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchDaemons", isDirectory: true)
            .appendingPathComponent(ContinuityXPC.launchDaemonPlistName)

        guard fileManager.fileExists(atPath: helperURL.path),
              fileManager.fileExists(atPath: daemonPlistURL.path)
        else {
            return .missingEmbeddedPayload
        }

        return nil
    }
}

public final class AppleScriptPMSetCommandRunner: PMSetCommandRunning {
    private let executor = ProcessAppleScriptExecutor()
    private let builder = AppleScriptCommandBuilder()

    public init() {}

    public func run(arguments: [String]) throws {
        try executor.run(script: builder.build(arguments: arguments))
    }
}

public struct InteractiveAdminContinuityService: ContinuityService {
    private let journalStore: RecoveryJournalStore

    public init(
        journalStore: RecoveryJournalStore = RecoveryJournalStore(
            fileURL: FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("AI Power Manager", isDirectory: true)
                .appendingPathComponent("portable-continuity.json")
        )
    ) {
        self.journalStore = journalStore
    }

    public func registerHelper() throws {}

    public func helperStatus() -> HelperStatus {
        FileManager.default.fileExists(atPath: "/usr/bin/osascript") ? .ready : .degraded(reason: "osascript is unavailable")
    }

    public func applyPortableContinuity(reason: String) throws {
        let engine = ContinuityHelperEngine(
            commandBuilder: PMSetCommandBuilder(),
            runner: AppleScriptPMSetCommandRunner(),
            journalStore: journalStore,
            now: Date.init
        )
        let baseline = try LivePMSetSnapshotReader().readCurrentSnapshot()
        try engine.armPortableContinuity(baseline: baseline, reason: reason)
    }

    public func restoreBaselinePolicy() throws {
        let engine = ContinuityHelperEngine(
            commandBuilder: PMSetCommandBuilder(),
            runner: AppleScriptPMSetCommandRunner(),
            journalStore: journalStore,
            now: Date.init
        )
        try engine.restoreBaseline()
    }

    public func fetchRecoveryState() throws -> String? {
        guard let state = try journalStore.load() else {
            return nil
        }
        return state.lastReason
    }
}

private final class ProcessAppleScriptExecutor {
    func run(script: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "AIPowerSystem.ProcessAppleScriptExecutor",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "osascript exited with status \(process.terminationStatus)"]
            )
        }
    }
}

@MainActor
public final class LocalContinuityHelperManager: ContinuityHelperManaging, ContinuityHelperControlling {
    private let service: any ContinuityService

    public init(service: (any ContinuityService)? = nil) {
        self.service = service ?? Self.defaultService()
    }

    public func installOrRegister() async -> HelperPreparationResult {
        do {
            try service.registerHelper()
            let status = service.helperStatus()
            return HelperPreparationResult(
                status: status,
                message: status.guidanceText ?? (status == .ready ? "AI Continuity helper is ready." : nil)
            )
        } catch {
            return Self.preparationResult(for: error)
        }
    }

    public func status() async -> HelperStatus {
        service.helperStatus()
    }

    public func apply(intent: HelperIntent) async {
        switch intent {
        case .installOrApprove:
            try? service.registerHelper()
        case .inactive, .disarm:
            try? service.restoreBaselinePolicy()
        case let .armPortableContinuity(reason):
            try? service.applyPortableContinuity(reason: reason)
        }
    }

    public func restoreBaselinePolicy() async {
        try? service.restoreBaselinePolicy()
    }

    public func fetchRecoveryState() async -> String? {
        try? service.fetchRecoveryState()
    }

    private static func defaultService() -> any ContinuityService {
        if ProcessInfo.processInfo.environment["AIPOWER_DEBUG_INTERACTIVE_PMSET"] == "1" {
            return InteractiveAdminContinuityService()
        }

        return SMAppContinuityService()
    }

    private static func preparationResult(for error: Error) -> HelperPreparationResult {
        let nsError = error as NSError
        let isSMAppError: Bool

        if #available(macOS 15.0, *) {
            isSMAppError = nsError.domain == SMAppServiceErrorDomain
        } else {
            isSMAppError = nsError.domain == "SMAppServiceErrorDomain"
        }

        guard isSMAppError else {
            let message = nsError.localizedDescription
            return HelperPreparationResult(
                status: .degraded(reason: message),
                message: message
            )
        }

        let message: String
        let status: HelperStatus

        switch nsError.code {
        case Int(kSMErrorInvalidSignature):
            message = "App signature is invalid for helper registration. Build and run the signed AI Power.app bundle from Xcode."
            status = .degraded(reason: message)
        case Int(kSMErrorLaunchDeniedByUser):
            message = "Approve AI Power in System Settings > Login Items & Extensions."
            status = .requiresApproval
        case Int(kSMErrorAlreadyRegistered):
            message = "AI Continuity helper is already registered. Refreshing approval state."
            status = .requiresApproval
        case Int(kSMErrorToolNotValid), Int(kSMErrorJobNotFound), Int(kSMErrorJobPlistNotFound):
            message = "Embedded helper payload is missing from the app bundle."
            status = .degraded(reason: message)
        default:
            message = nsError.localizedDescription
            status = .degraded(reason: message)
        }

        return HelperPreparationResult(status: status, message: message)
    }
}

@MainActor
public final class NoopContinuityHelperController: ContinuityHelperControlling {
    public init() {}

    public func apply(intent: HelperIntent) async {}
}

private struct CPUTickSnapshot {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64
}

public enum ProcessKeywordConfiguration {
    private static let customKeywordsDefaultsKey = "AIPowerCustomProcessKeywords"

    public static let builtInKeywords = [
        "vscode",
        "cursor",
        "windsurf",
        "zed",
        "kiro",
        "codex",
        "claude",
        "gemini",
        "qwen",
        "opencode",
        "aider",
        "goose",
        "continue",
        "junie",
        "augment",
        "copilot",
        "cline",
        "roo",
        "qodo",
        "cody",
        "lingma",
        "tabnine",
        "antigravity",
        "kimi",
    ]

    public static func customKeywords(userDefaults: UserDefaults = .standard) -> [String] {
        let values = userDefaults.stringArray(forKey: customKeywordsDefaultsKey) ?? []
        return normalizedKeywords(values)
    }

    public static func allKeywords(userDefaults: UserDefaults = .standard) -> [String] {
        normalizedKeywords(builtInKeywords + customKeywords(userDefaults: userDefaults))
    }

    @discardableResult
    public static func addCustomKeyword(_ keyword: String, userDefaults: UserDefaults = .standard) -> Bool {
        let normalized = normalizedKeyword(keyword)
        guard normalized.isEmpty == false else {
            return false
        }

        var values = customKeywords(userDefaults: userDefaults)
        guard values.contains(normalized) == false else {
            return false
        }

        values.append(normalized)
        userDefaults.set(values, forKey: customKeywordsDefaultsKey)
        return true
    }

    @discardableResult
    public static func removeCustomKeyword(_ keyword: String, userDefaults: UserDefaults = .standard) -> Bool {
        let normalized = normalizedKeyword(keyword)
        guard normalized.isEmpty == false else {
            return false
        }

        var values = customKeywords(userDefaults: userDefaults)
        let originalCount = values.count
        values.removeAll { $0 == normalized }
        guard values.count != originalCount else {
            return false
        }

        userDefaults.set(values, forKey: customKeywordsDefaultsKey)
        return true
    }

    private static func normalizedKeywords(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { result, value in
            let normalized = normalizedKeyword(value)
            guard normalized.isEmpty == false, result.contains(normalized) == false else {
                return
            }
            result.append(normalized)
        }
    }

    private static func normalizedKeyword(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

public enum AIModePortConfiguration {
    private static let customPortsDefaultsKey = "AIPowerCustomMonitoredPorts"

    public static let builtInPorts = [18789]

    public static func customPorts(userDefaults: UserDefaults = .standard) -> [Int] {
        let values = userDefaults.array(forKey: customPortsDefaultsKey) as? [Int] ?? []
        return normalizedPorts(values)
    }

    public static func allPorts(userDefaults: UserDefaults = .standard) -> [Int] {
        normalizedPorts(builtInPorts + customPorts(userDefaults: userDefaults))
    }

    @discardableResult
    public static func addCustomPort(_ rawValue: String, userDefaults: UserDefaults = .standard) -> Bool {
        guard let port = Int(rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }

        return addCustomPort(port, userDefaults: userDefaults)
    }

    @discardableResult
    public static func addCustomPort(_ port: Int, userDefaults: UserDefaults = .standard) -> Bool {
        guard (1...65535).contains(port) else {
            return false
        }

        var values = customPorts(userDefaults: userDefaults)
        guard values.contains(port) == false else {
            return false
        }

        values.append(port)
        userDefaults.set(values, forKey: customPortsDefaultsKey)
        return true
    }

    @discardableResult
    public static func removeCustomPort(_ port: Int, userDefaults: UserDefaults = .standard) -> Bool {
        guard (1...65535).contains(port) else {
            return false
        }

        var values = customPorts(userDefaults: userDefaults)
        let originalCount = values.count
        values.removeAll { $0 == port }
        guard values.count != originalCount else {
            return false
        }

        userDefaults.set(values, forKey: customPortsDefaultsKey)
        return true
    }

    private static func normalizedPorts(_ values: [Int]) -> [Int] {
        values.reduce(into: [Int]()) { result, value in
            guard (1...65535).contains(value), result.contains(value) == false else {
                return
            }
            result.append(value)
        }
    }
}

public enum WakeControlConfiguration {
    private static let preventComputerSleepDefaultsKey = "AIPowerPreventComputerSleep"
    private static let preventDisplaySleepDefaultsKey = "AIPowerPreventDisplaySleep"
    private static let preventLockScreenDefaultsKey = "AIPowerPreventLockScreen"
    private static let aiIdleGraceMinutesDefaultsKey = "AIPowerAIIdleGraceMinutes"

    public static func currentOptions(userDefaults: UserDefaults = .standard) -> WakeControlOptions {
        WakeControlOptions(
            preventComputerSleep: value(
                forKey: preventComputerSleepDefaultsKey,
                defaultValue: WakeControlOptions.default.preventComputerSleep,
                userDefaults: userDefaults
            ),
            preventDisplaySleep: value(
                forKey: preventDisplaySleepDefaultsKey,
                defaultValue: WakeControlOptions.default.preventDisplaySleep,
                userDefaults: userDefaults
            ),
            preventLockScreen: value(
                forKey: preventLockScreenDefaultsKey,
                defaultValue: WakeControlOptions.default.preventLockScreen,
                userDefaults: userDefaults
            ),
            aiIdleGraceMinutes: integerValue(
                forKey: aiIdleGraceMinutesDefaultsKey,
                defaultValue: WakeControlOptions.default.aiIdleGraceMinutes,
                userDefaults: userDefaults
            )
        )
    }

    public static func setOptions(_ options: WakeControlOptions, userDefaults: UserDefaults = .standard) {
        userDefaults.set(options.preventComputerSleep, forKey: preventComputerSleepDefaultsKey)
        userDefaults.set(options.preventDisplaySleep, forKey: preventDisplaySleepDefaultsKey)
        userDefaults.set(options.preventLockScreen, forKey: preventLockScreenDefaultsKey)
        userDefaults.set(options.aiIdleGraceMinutes, forKey: aiIdleGraceMinutesDefaultsKey)
    }

    private static func value(
        forKey key: String,
        defaultValue: Bool,
        userDefaults: UserDefaults
    ) -> Bool {
        if userDefaults.object(forKey: key) == nil {
            return defaultValue
        }

        return userDefaults.bool(forKey: key)
    }

    private static func integerValue(
        forKey key: String,
        defaultValue: Int,
        userDefaults: UserDefaults
    ) -> Int {
        if userDefaults.object(forKey: key) == nil {
            return defaultValue
        }

        return max(userDefaults.integer(forKey: key), 0)
    }
}

struct ProcessScanCandidate: Sendable {
    let localizedName: String?
    let bundleIdentifier: String?
    let executableName: String?
    let bundlePath: String?

    var searchFields: [String] {
        [
            localizedName,
            bundleIdentifier,
            executableName,
        ]
        .compactMap { $0?.lowercased() }
    }

    var shouldBeScanned: Bool {
        guard let bundlePath else {
            guard let executableName else {
                return false
            }
            return executableName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }

        let normalized = bundlePath.lowercased()
        guard normalized.hasSuffix(".app") else {
            return false
        }
        guard normalized.contains("/contents/frameworks/") == false else {
            return false
        }
        guard normalized.contains("/contents/plugins/") == false else {
            return false
        }
        guard normalized.contains("/contents/xpcservices/") == false else {
            return false
        }
        guard normalized.contains("/system/library/privateframeworks/") == false else {
            return false
        }

        return true
    }
}

enum ProcessKeywordMatcher {
    static func detectKeywords(
        in candidates: [ProcessScanCandidate],
        keywords: [String]
    ) -> [String] {
        let orderedKeywords = keywords
            .map { $0.lowercased() }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs < rhs
                }
                return lhs.count > rhs.count
            }

        return candidates
            .compactMap { candidate -> String? in
                guard candidate.shouldBeScanned else {
                    return nil
                }

                return orderedKeywords.first { keyword in
                    ActivityProcessFilter.shouldIgnore(candidate: candidate, for: keyword) == false &&
                        candidate.searchFields.contains(where: { $0.contains(keyword) })
                }
            }
            .reduce(into: [String]()) { processes, name in
                if processes.contains(name) == false {
                    processes.append(name)
                }
            }
    }
}

enum DeveloperProcessScanner {
    static func detectActiveProcesses(
        appBundleCandidates: [ProcessScanCandidate],
        cliProcessCandidates: [ProcessScanCandidate],
        keywords: [String] = ProcessKeywordConfiguration.allKeywords()
    ) -> [String] {
        let candidates = appBundleCandidates + cliProcessCandidates
        return ProcessKeywordMatcher.detectKeywords(
            in: candidates,
            keywords: keywords
        )
    }

    @MainActor
    static func appBundleCandidates() -> [ProcessScanCandidate] {
        NSWorkspace.shared.runningApplications.map { application in
            ProcessScanCandidate(
                localizedName: application.localizedName,
                bundleIdentifier: application.bundleIdentifier,
                executableName: application.executableURL?.lastPathComponent,
                bundlePath: application.bundleURL?.path
            )
        }
    }

    static func cliProcessCandidates() -> [ProcessScanCandidate] {
        let output = (try? runCommand(
            executableURL: URL(fileURLWithPath: "/bin/ps"),
            arguments: ["-axo", "command="]
        )) ?? ""

        return output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .map { command in
                ProcessScanCandidate(
                    localizedName: nil,
                    bundleIdentifier: nil,
                    executableName: command,
                    bundlePath: nil
                )
            }
    }

    static func runCommand(
        executableURL: URL,
        arguments: [String]
    ) throws -> String {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        try process.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return ""
        }

        return String(decoding: data, as: UTF8.self)
    }
}
