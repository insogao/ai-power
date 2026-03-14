import Foundation
import Testing
import AIPowerCore
@testable import AIPowerSystem

struct LiveMonitoringSamplerTests {
    @Test
    func runCommandReadsLargeOutputWithoutBlocking() throws {
        let output = try DeveloperProcessScanner.runCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: [
                "-c",
                "import sys; sys.stdout.write('copilot ' * 20000)"
            ]
        )

        #expect(output.hasPrefix("copilot copilot"))
        #expect(output.count == "copilot ".count * 20000)
    }

    @Test
    func mergesAppAndCLIProcessCandidatesWhenDetectingKeywords() {
        let detected = DeveloperProcessScanner.detectActiveProcesses(
            appBundleCandidates: [
                ProcessScanCandidate(
                    localizedName: "Visual Studio Code",
                    bundleIdentifier: "com.microsoft.VSCode",
                    executableName: "Code",
                    bundlePath: "/Applications/Visual Studio Code.app"
                ),
            ],
            cliProcessCandidates: [
                ProcessScanCandidate(
                    localizedName: nil,
                    bundleIdentifier: nil,
                    executableName: "/Applications/Codex.app/Contents/Resources/codex",
                    bundlePath: nil
                ),
            ],
            keywords: ["vscode", "codex"]
        )

        #expect(detected == ["vscode", "codex"])
    }

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

    @Test
    func attributesCodeHelperTrafficToCopilotAfterKeywordDetection() {
        let monitored = LiveMonitoringSampler.buildMonitoredApplicationSamples(
            configuredKeywords: ["copilot"],
            detectedKeywords: ["copilot"],
            cpuSamples: [
                PerProcessCPUSample(
                    processName: "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Plugin).app/Contents/MacOS/Code Helper (Plugin)",
                    cpuPercent: 3.5
                ),
            ],
            networkSamples: [
                DebugProcessNetworkSample(
                    processName: "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Plugin).app/Contents/MacOS/Code Helper (Plugin)",
                    totalBytes: 4096,
                    deltaBytes: 2048
                ),
            ]
        )

        #expect(
            monitored == [
                MonitoredApplicationSample(
                    keyword: "copilot",
                    isDetected: true,
                    networkDeltaBytes: 2048,
                    cpuPercent: 3.5
                ),
            ]
        )
        #expect(LiveMonitoringSampler.readActiveApplicationKeywords(monitoredApplicationSamples: monitored) == ["copilot"])
    }
}
