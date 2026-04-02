import AIPowerCore
import Foundation

actor FileMonitoringDebugLogger {
    static let maxLogAge: TimeInterval = 24 * 60 * 60
    static let maxActivityLogBytes = 1 * 1024 * 1024
    static let maxProcessLogBytes = 1 * 1024 * 1024

    static let defaultFileURL: URL = {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseDirectory
            .appendingPathComponent("AI Power", isDirectory: true)
            .appendingPathComponent("debug-activity.log", isDirectory: false)
    }()

    static let defaultProcessFileURL: URL = {
        defaultFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("debug-processes.log", isDirectory: false)
    }()

    private let activityFileURL: URL
    private let processFileURL: URL
    private let formatter: ISO8601DateFormatter
    private let encoder: JSONEncoder
    private let now: () -> Date
    private let maxLogAge: TimeInterval
    private let maxActivityLogBytes: Int
    private let maxProcessLogBytes: Int

    init(
        activityFileURL: URL = defaultFileURL,
        processFileURL: URL = defaultProcessFileURL,
        now: @escaping () -> Date = Date.init,
        maxLogAge: TimeInterval = FileMonitoringDebugLogger.maxLogAge,
        maxActivityLogBytes: Int = FileMonitoringDebugLogger.maxActivityLogBytes,
        maxProcessLogBytes: Int = FileMonitoringDebugLogger.maxProcessLogBytes
    ) {
        self.activityFileURL = activityFileURL
        self.processFileURL = processFileURL
        self.formatter = ISO8601DateFormatter()
        self.formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.now = now
        self.maxLogAge = maxLogAge
        self.maxActivityLogBytes = maxActivityLogBytes
        self.maxProcessLogBytes = maxProcessLogBytes
    }

    func record(_ record: MonitoringDebugRecord) async {
        let activityLine = [
            "ts=\(formatter.string(from: record.timestamp))",
            "mode=\(record.mode.rawValue)",
            String(format: "cpu=%.2f", record.cpuUsagePercent),
            String(format: "net=%.0f", record.networkBytesPerSecond),
            "configured_apps=\(record.configuredApplicationKeywords.joined(separator: ","))",
            "configured_ports=\(record.configuredPorts.map(String.init).joined(separator: ","))",
            "apps=\(record.detectedApplicationKeywords.joined(separator: ","))",
            "active_apps=\(record.activeApplicationKeywords.joined(separator: ","))",
            "ports=\(record.listeningPorts.map(String.init).joined(separator: ","))",
            "reasons=\(record.reasons.map { $0.displayText }.joined(separator: "|"))",
            "prevent=\(record.shouldPreventSleep ? "1" : "0")",
        ]
        .joined(separator: " ")
        + "\n"

        let rawPayload = RawProcessLogRecord(
            ts: formatter.string(from: record.timestamp),
            mode: record.mode.rawValue,
            cpuPercent: record.cpuUsagePercent,
            netBytesPerSecond: record.networkBytesPerSecond,
            configuredKeywords: record.configuredApplicationKeywords,
            configuredPorts: record.configuredPorts,
            detectedKeywords: record.detectedApplicationKeywords,
            activeKeywords: record.activeApplicationKeywords,
            listeningPorts: record.listeningPorts,
            reasons: record.reasons.map(\.displayText),
            shouldPreventSleep: record.shouldPreventSleep,
            cpuSamples: record.processCPUSamples,
            networkSamples: record.processNetworkSamples,
            monitoredApplicationSamples: record.monitoredApplicationSamples
        )

        do {
            try append(activityLine.data(using: .utf8), to: activityFileURL)
            let rawData = try encoder.encode(rawPayload)
            try append(rawData + Data("\n".utf8), to: processFileURL)
        } catch {
            return
        }
    }

    private func append(_ data: Data?, to fileURL: URL) throws {
        guard let data else {
            return
        }

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try prepareLogFileIfNeeded(
            at: fileURL,
            appendingBytes: data.count,
            maximumBytes: fileURL == activityFileURL ? maxActivityLogBytes : maxProcessLogBytes
        )

        if FileManager.default.fileExists(atPath: fileURL.path) == false {
            try data.write(to: fileURL, options: .atomic)
            return
        }

        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    private func prepareLogFileIfNeeded(at fileURL: URL, appendingBytes: Int, maximumBytes: Int) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let creationDate = (attributes[.creationDate] as? Date) ?? (attributes[.modificationDate] as? Date)
        let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0

        let isExpired: Bool
        if let creationDate {
            isExpired = now().timeIntervalSince(creationDate) >= maxLogAge
        } else {
            isExpired = false
        }

        guard isExpired || fileSize + appendingBytes > maximumBytes else {
            return
        }

        try FileManager.default.removeItem(at: fileURL)
    }
}

private struct RawProcessLogRecord: Encodable {
    let ts: String
    let mode: String
    let cpuPercent: Double
    let netBytesPerSecond: Double
    let configuredKeywords: [String]
    let configuredPorts: [Int]
    let detectedKeywords: [String]
    let activeKeywords: [String]
    let listeningPorts: [Int]
    let reasons: [String]
    let shouldPreventSleep: Bool
    let cpuSamples: [DebugProcessCPUSample]
    let networkSamples: [DebugProcessNetworkSample]
    let monitoredApplicationSamples: [MonitoredApplicationSample]

    enum CodingKeys: String, CodingKey {
        case ts
        case mode
        case cpuPercent = "cpu_percent"
        case netBytesPerSecond = "net_bps"
        case configuredKeywords = "configured_keywords"
        case configuredPorts = "configured_ports"
        case detectedKeywords = "detected_keywords"
        case activeKeywords = "active_keywords"
        case listeningPorts = "listening_ports"
        case reasons
        case shouldPreventSleep = "prevent_sleep"
        case cpuSamples = "cpu_samples"
        case networkSamples = "network_samples"
        case monitoredApplicationSamples = "monitored_application_samples"
    }
}
