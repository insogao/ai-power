import AIPowerCore
import Foundation
import Testing
@testable import AIPowerApp

struct DebugLogStoreTests {
    @Test
    func recordWritesSummaryAndRawProcessLogs() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let activityURL = directory.appendingPathComponent("debug-activity.log")
        let processURL = directory.appendingPathComponent("debug-processes.log")
        let logger = FileMonitoringDebugLogger(
            activityFileURL: activityURL,
            processFileURL: processURL
        )

        await logger.record(
            MonitoringDebugRecord(
                timestamp: Date(timeIntervalSince1970: 1_741_414_560),
                mode: .auto,
                cpuUsagePercent: 12.5,
                networkBytesPerSecond: 4096,
                diskBytesPerSecond: 2048,
                configuredApplicationKeywords: ["codex", "vscode", "cursor"],
                configuredPorts: [18789],
                detectedApplicationKeywords: ["codex", "vscode"],
                activeApplicationKeywords: ["codex"],
                listeningPorts: [18789],
                reasons: [.developerProcess("codex")],
                shouldPreventSleep: true,
                processCPUSamples: [
                    DebugProcessCPUSample(processName: "codex", cpuPercent: 8.1),
                    DebugProcessCPUSample(processName: "cursoruiviewservice", cpuPercent: 1.2),
                ],
                processNetworkSamples: [
                    DebugProcessNetworkSample(processName: "codex", totalBytes: 10_240, deltaBytes: 2_048),
                    DebugProcessNetworkSample(processName: "Code Helper", totalBytes: 5_120, deltaBytes: 512),
                ]
            )
        )

        let activityLog = try String(contentsOf: activityURL, encoding: .utf8)
        #expect(activityLog.contains("configured_apps=codex,vscode,cursor"))
        #expect(activityLog.contains("configured_ports=18789"))
        #expect(activityLog.contains("active_apps=codex"))
        #expect(activityLog.contains("prevent=1"))

        let processLog = try String(contentsOf: processURL, encoding: .utf8)
        #expect(processLog.contains("\"configured_keywords\":[\"codex\",\"vscode\",\"cursor\"]"))
        #expect(processLog.contains("\"configured_ports\":[18789]"))
        #expect(processLog.contains("\"process\":\"codex\""))
        #expect(processLog.contains("\"cpu_percent\":8.1"))
        #expect(processLog.contains("\"delta_bytes\":2048"))
    }
}
