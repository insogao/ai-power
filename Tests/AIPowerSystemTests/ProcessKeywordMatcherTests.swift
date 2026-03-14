import Testing
@testable import AIPowerSystem

struct ProcessKeywordMatcherTests {
    @Test
    func ignoresCursorUIViewServiceDuringCursorActivityAttribution() {
        #expect(ActivityProcessFilter.shouldIgnore(processName: "cursoruiviewservice", for: "cursor"))
        #expect(ActivityProcessFilter.shouldIgnore(processName: "cursor helper", for: "cursor") == false)
        #expect(ActivityProcessFilter.shouldIgnore(processName: "cursor", for: "cursor") == false)
    }

    @Test
    func ignoresSystemXPCProcessesWhenMatchingKeywords() {
        let detected = ProcessKeywordMatcher.detectKeywords(
            in: [
                ProcessScanCandidate(
                    localizedName: "CursorUIViewService",
                    bundleIdentifier: "com.apple.CursorUIViewService",
                    executableName: "CursorUIViewService",
                    bundlePath: "/System/Library/PrivateFrameworks/TextInputUIMacHelper.framework/Versions/A/XPCServices/CursorUIViewService.xpc"
                ),
            ],
            keywords: ProcessKeywordConfiguration.builtInKeywords
        )

        #expect(detected.isEmpty)
    }

    @Test
    func ignoresCursorUIViewServiceWhenItAppearsAsCLIProcessCandidate() {
        let detected = ProcessKeywordMatcher.detectKeywords(
            in: [
                ProcessScanCandidate(
                    localizedName: nil,
                    bundleIdentifier: nil,
                    executableName: "/System/Library/PrivateFrameworks/TextInputUIMacHelper.framework/Versions/A/XPCServices/CursorUIViewService.xpc/Contents/MacOS/CursorUIViewService",
                    bundlePath: nil
                ),
            ],
            keywords: ProcessKeywordConfiguration.builtInKeywords
        )

        #expect(detected.isEmpty)
    }

    @Test
    func prefersSpecificKeywordsOverGenericCodeKeyword() {
        let detected = ProcessKeywordMatcher.detectKeywords(
            in: [
                ProcessScanCandidate(
                    localizedName: "Codex",
                    bundleIdentifier: "com.openai.codex",
                    executableName: "Codex",
                    bundlePath: "/Applications/Codex.app"
                ),
                ProcessScanCandidate(
                    localizedName: "Visual Studio Code",
                    bundleIdentifier: "com.microsoft.VSCode",
                    executableName: "Electron",
                    bundlePath: "/Applications/Visual Studio Code.app"
                ),
                ProcessScanCandidate(
                    localizedName: "Terminal",
                    bundleIdentifier: "com.apple.Terminal",
                    executableName: "Terminal",
                    bundlePath: "/System/Applications/Utilities/Terminal.app"
                ),
            ],
            keywords: ProcessKeywordConfiguration.builtInKeywords
        )

        #expect(detected == ["codex", "vscode"])
    }

    @Test
    func builtInKeywordsAreScopedToAICodingTools() {
        #expect(
            ProcessKeywordConfiguration.builtInKeywords
                == [
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
        )
    }

    @Test
    func matchesCLIToolProcessesWithoutAppBundleMetadata() {
        let detected = ProcessKeywordMatcher.detectKeywords(
            in: [
                ProcessScanCandidate(
                    localizedName: nil,
                    bundleIdentifier: nil,
                    executableName: "Kimi Code",
                    bundlePath: nil
                ),
                ProcessScanCandidate(
                    localizedName: nil,
                    bundleIdentifier: nil,
                    executableName: "kimi-code-worker",
                    bundlePath: nil
                ),
            ],
            keywords: ["kimi"]
        )

        #expect(detected == ["kimi"])
    }

    @Test
    func detectsCopilotFromVSCodeExtensionHostCommandLine() {
        let detected = ProcessKeywordMatcher.detectKeywords(
            in: [
                ProcessScanCandidate(
                    localizedName: nil,
                    bundleIdentifier: nil,
                    executableName: "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Plugin).app/Contents/MacOS/Code Helper (Plugin) --max-old-space-size=3072 /Applications/Visual Studio Code.app/Contents/Resources/app/extensions/node_modules/typescript/lib/tsserver.js --globalPlugins @vscode/copilot-typescript-server-plugin --pluginProbeLocations /Users/gaoshizai/.vscode/extensions/github.copilot-chat-0.37.9 --locale en",
                    bundlePath: nil
                ),
            ],
            keywords: ["copilot"]
        )

        #expect(detected == ["copilot"])
    }
}
