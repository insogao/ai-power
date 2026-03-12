import Testing
@testable import AIPowerSystem

struct LiveMonitoringSamplerTests {
    @Test
    func normalizesDuplicateCPUProcessSamplesBySummingUsage() {
        let normalized = LiveMonitoringSampler.normalizePerProcessCPUSamples([
            PerProcessCPUSample(processName: "codex", cpuPercent: 1.5),
            PerProcessCPUSample(processName: "codex", cpuPercent: 2.25),
            PerProcessCPUSample(processName: "vscode", cpuPercent: 0.5),
        ])

        #expect(
            normalized == [
                PerProcessCPUSample(processName: "codex", cpuPercent: 3.75),
                PerProcessCPUSample(processName: "vscode", cpuPercent: 0.5),
            ]
        )
    }

    @Test
    func normalizesDuplicateNetworkProcessSamplesBySummingTotals() {
        let normalized = LiveMonitoringSampler.normalizePerProcessNetworkSamples([
            PerProcessNetworkSample(processName: "codex", totalBytes: 1024),
            PerProcessNetworkSample(processName: "codex", totalBytes: 2048),
            PerProcessNetworkSample(processName: "vscode", totalBytes: 512),
        ])

        #expect(
            normalized == [
                PerProcessNetworkSample(processName: "codex", totalBytes: 3072),
                PerProcessNetworkSample(processName: "vscode", totalBytes: 512),
            ]
        )
    }
}
