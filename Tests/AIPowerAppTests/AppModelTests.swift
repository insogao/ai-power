import AIPowerCore
import AIPowerSystem
import Foundation
import Testing
@testable import AIPowerApp

@MainActor
struct AppModelTests {
    @Test
    func monitoringLoopUsesTwoSecondRefreshInterval() {
        #expect(AppModel.monitoringRefreshInterval == .seconds(2))
    }

    @Test
    func selectingAIModeShowsInstallCardWithoutImmediateInstall() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .notInstalled)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(
                status: .requiresApproval,
                message: "Approve AI Power in System Settings > Login Items & Extensions."
            )
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now }
        )

        model.applyTrackSelection(.aiMode)
        try await Task.sleep(for: .milliseconds(50))

        #expect(helperManager.installCallCount == 0)
        #expect(model.permissionCard == PermissionActionCard(
            title: "Enable AI Continuity",
            message: "Install the AI Continuity helper to enable closed-lid runs.",
            actionTitle: "Install Helper"
        ))
        #expect(model.onboardingAutoOpenToken != nil)
        #expect(model.primaryStatusText == "Not Installed")
        #expect(model.secondaryStatusText == "Install the AI Continuity helper to enable closed-lid runs.")
        #expect(model.menuBarIconState == .warning)
    }

    @Test
    func startingMonitoringRequestsAutoOpenForDefaultAIMode() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .notInstalled)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(
                status: .requiresApproval,
                message: "Approve AI Power in System Settings > Login Items & Extensions."
            )
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now }
        )

        model.startMonitoring()
        try await Task.sleep(for: .milliseconds(80))
        model.stopMonitoring()

        #expect(helperManager.installCallCount == 0)
        #expect(model.onboardingAutoOpenToken != nil)
        #expect(model.permissionCard?.actionTitle == "Install Helper")
    }

    @Test
    func aiModeWithoutActiveWorkloadLooksIdleWhenHelperIsReady() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now }
        )

        model.applyTrackSelection(.aiMode)
        try await Task.sleep(for: .milliseconds(50))
        await model.refreshForTesting()

        #expect(model.primaryStatusText == "Idle")
        #expect(model.secondaryStatusText == nil)
        #expect(model.menuBarIconState == .armed)
    }

    @Test
    func aiModeActivitySummaryUsesSlidingWindowInsteadOfGraceLabel() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let sampler = SequenceSampler(
            snapshots: [
                MonitoringSnapshot(
                    cpuUsagePercent: 0,
                    networkBytesPerSecond: 128_000,
                    diskBytesPerSecond: 0,
                    detectedApplicationKeywords: ["kimi"],
                    activeApplicationKeywords: ["kimi"],
                    listeningPorts: []
                ),
                MonitoringSnapshot(
                    cpuUsagePercent: 0,
                    networkBytesPerSecond: 0,
                    diskBytesPerSecond: 0,
                    detectedApplicationKeywords: [],
                    activeApplicationKeywords: [],
                    listeningPorts: []
                ),
                MonitoringSnapshot(
                    cpuUsagePercent: 0,
                    networkBytesPerSecond: 0,
                    diskBytesPerSecond: 0,
                    detectedApplicationKeywords: [],
                    activeApplicationKeywords: [],
                    listeningPorts: []
                ),
            ]
        )
        let model = AppModel(
            engine: makeEngine(
                statusBox: statusBox,
                helperController: helperManager,
                sampler: sampler
            ),
            helperManager: helperManager,
            now: { timeBox.now }
        )

        model.applyTrackSelection(.aiMode)
        try await Task.sleep(for: .milliseconds(50))

        #expect(model.primaryStatusText == "Active")
        #expect(model.secondaryStatusText == nil)
        #expect(model.activityBadges.map(\.label) == ["kimi"])
        #expect(model.menuBarIconState == .armed)

        timeBox.now = referenceDate.addingTimeInterval(1)
        await model.refreshForTesting()

        #expect(model.primaryStatusText == "Active")
        #expect(model.secondaryStatusText == nil)

        timeBox.now = referenceDate.addingTimeInterval(12)
        await model.refreshForTesting()

        #expect(model.primaryStatusText == "Active")
        #expect(model.secondaryStatusText == nil)
        #expect(model.activityBadges.isEmpty)
    }

    @Test
    func activityBadgesIncludePortsAndDeduplicateAcrossRefreshes() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let sampler = SequenceSampler(
            snapshots: [
                MonitoringSnapshot(
                    cpuUsagePercent: 0,
                    networkBytesPerSecond: 64_000,
                    diskBytesPerSecond: 0,
                    detectedApplicationKeywords: ["codex"],
                    activeApplicationKeywords: ["codex"],
                    listeningPorts: [18789]
                ),
                MonitoringSnapshot(
                    cpuUsagePercent: 0,
                    networkBytesPerSecond: 32_000,
                    diskBytesPerSecond: 0,
                    detectedApplicationKeywords: ["codex"],
                    activeApplicationKeywords: ["codex"],
                    listeningPorts: [18789]
                ),
            ]
        )
        let model = AppModel(
            engine: makeEngine(
                statusBox: statusBox,
                helperController: helperManager,
                sampler: sampler
            ),
            helperManager: helperManager,
            now: { timeBox.now }
        )

        model.applyTrackSelection(.aiMode)
        try await Task.sleep(for: .milliseconds(50))

        #expect(model.activityBadges.map(\.label) == ["codex", "port 18789"])

        timeBox.now = referenceDate.addingTimeInterval(1)
        await model.refreshForTesting()

        #expect(model.activityBadges.map(\.label) == ["codex", "port 18789"])
    }

    @Test
    func activityBadgesShowObservedAppsBeforeKeepAliveThresholdIsMet() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let sampler = SequenceSampler(
            snapshots: [
                MonitoringSnapshot(
                    cpuUsagePercent: 0,
                    networkBytesPerSecond: 1_024,
                    diskBytesPerSecond: 0,
                    detectedApplicationKeywords: ["codex"],
                    activeApplicationKeywords: ["codex"],
                    listeningPorts: [],
                    monitoredApplicationSamples: [
                        MonitoredApplicationSample(
                            keyword: "codex",
                            isDetected: true,
                            networkDeltaBytes: 1_024,
                            cpuPercent: 0.5
                        )
                    ]
                ),
            ]
        )
        let model = AppModel(
            engine: makeEngine(
                statusBox: statusBox,
                helperController: helperManager,
                sampler: sampler
            ),
            helperManager: helperManager,
            now: { timeBox.now }
        )

        model.applyTrackSelection(.aiMode)
        try await Task.sleep(for: .milliseconds(50))

        #expect(model.primaryStatusText == "Idle")
        #expect(model.activityBadges.map(\.label) == ["codex"])
    }

    @Test
    func timedSelectionHidesRemainingUntilPanelReopens() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now }
        )

        model.applyTrackSelection(.timed(duration: 8 * 60 * 60))
        await model.refreshForTesting()

        #expect(model.selectionBadgeText == "8h remaining")
        #expect(model.primaryStatusText.contains("Keeping awake until"))
        #expect(model.remainingText == nil)
        #expect(model.menuBarIconState == .armed)

        timeBox.now = referenceDate.addingTimeInterval(5 * 60 * 60 + 2 * 60)
        await model.refreshForTesting()

        #expect(model.selectionBadgeText == "2h 58m remaining")
        #expect(model.remainingText == nil)

        model.panelDidOpen()

        #expect(model.remainingText == "2h 58m remaining")
    }

    @Test
    func timedSelectionExpiresBackToOff() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now }
        )

        model.applyTrackSelection(.timed(duration: 30 * 60))
        await model.refreshForTesting()

        timeBox.now = referenceDate.addingTimeInterval(31 * 60)
        await model.refreshForTesting()

        #expect(model.currentTrackSelection == .off)
        #expect(model.primaryStatusText == "Idle")
        #expect(model.remainingText == nil)
        #expect(model.menuBarIconState == .off)
    }

    @Test
    func infinitySelectionUsesDedicatedInfinityIconState() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now }
        )

        model.applyTrackSelection(.infinity)
        await model.refreshForTesting()

        #expect(model.primaryStatusText == "Keeping awake indefinitely")
        #expect(model.menuBarIconState == .infinity)
    }

    @Test
    func performingInstallCardActionAdvancesToApprovalCard() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .notInstalled)
        let settingsRecorder = SettingsRecorder()
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(
                status: .requiresApproval,
                message: "Approve AI Power in System Settings > Login Items & Extensions."
            )
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now },
            openApprovalSettings: {
                settingsRecorder.openCount += 1
            }
        )

        model.applyTrackSelection(.aiMode)
        try await Task.sleep(for: .milliseconds(50))

        model.performPermissionCardAction()
        try await Task.sleep(for: .milliseconds(50))

        #expect(helperManager.installCallCount == 1)
        #expect(settingsRecorder.openCount == 0)
        #expect(model.permissionCard == PermissionActionCard(
            title: "Approve Closed-Lid Access",
            message: "Approve AI Power in System Settings > Login Items & Extensions.",
            actionTitle: "Open Settings"
        ))
    }

    @Test
    func degradedMissingHelperShowsInstallCard() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .degraded(reason: "Closed-lid access is not enabled yet"))
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(
                status: .degraded(reason: "Closed-lid access is not enabled yet"),
                message: "Closed-lid access is not enabled yet"
            )
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now }
        )

        model.applyTrackSelection(.aiMode)
        try await Task.sleep(for: .milliseconds(50))

        #expect(model.permissionCard?.actionTitle == "Install Helper")
    }

    @Test
    func installFailureMessagePersistsAfterRefresh() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .degraded(reason: "Closed-lid access is not enabled yet"))
        let specificFailure = "App signature is invalid for helper registration. Build and run the signed AI Power.app bundle from Xcode."
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(
                status: .degraded(reason: "Closed-lid access is not enabled yet"),
                message: specificFailure
            )
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now }
        )

        model.applyTrackSelection(.aiMode)
        try await Task.sleep(for: .milliseconds(50))

        model.performPermissionCardAction()
        try await Task.sleep(for: .milliseconds(50))

        #expect(model.helperStatus == .degraded(reason: "Closed-lid access is not enabled yet"))
        #expect(model.secondaryStatusText == specificFailure)
        #expect(model.permissionCard == PermissionActionCard(
            title: "Enable AI Continuity",
            message: specificFailure,
            actionTitle: "Install Helper"
        ))
    }

    @Test
    func requiresApprovalShowsApprovalCardWithoutOpeningSettings() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .requiresApproval)
        let settingsRecorder = SettingsRecorder()
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .requiresApproval, message: nil)
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now },
            openApprovalSettings: {
                settingsRecorder.openCount += 1
            }
        )

        model.applyTrackSelection(.aiMode)
        try await Task.sleep(for: .milliseconds(50))

        #expect(helperManager.installCallCount == 0)
        #expect(settingsRecorder.openCount == 0)
        #expect(model.permissionCard == PermissionActionCard(
            title: "Approve Closed-Lid Access",
            message: "Approve AI Power in System Settings > Login Items & Extensions.",
            actionTitle: "Open Settings"
        ))
    }

    @Test
    func changingDurationDoesNotReissueAutoOpenOrInstallAfterCardIsShown() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .notInstalled)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(
                status: .requiresApproval,
                message: "Approve AI Power in System Settings > Login Items & Extensions."
            )
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now }
        )

        model.applyTrackSelection(.timed(duration: 30 * 60))
        try await Task.sleep(for: .milliseconds(50))

        let autoOpenToken = try #require(model.onboardingAutoOpenToken)
        #expect(helperManager.installCallCount == 0)
        #expect(model.permissionCard?.actionTitle == "Install Helper")

        model.applyTrackSelection(.timed(duration: 3 * 60 * 60))
        try await Task.sleep(for: .milliseconds(50))

        #expect(helperManager.installCallCount == 0)
        #expect(model.onboardingAutoOpenToken == autoOpenToken)
    }

    @Test
    func changingDurationDoesNotReissueAutoOpenWhileAwaitingApproval() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .requiresApproval)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .requiresApproval, message: nil)
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now }
        )

        model.applyTrackSelection(.infinity)
        try await Task.sleep(for: .milliseconds(50))

        #expect(helperManager.installCallCount == 0)
        let autoOpenToken = try #require(model.onboardingAutoOpenToken)
        #expect(model.permissionCard?.actionTitle == "Open Settings")

        model.applyTrackSelection(.timed(duration: 8 * 60 * 60))
        try await Task.sleep(for: .milliseconds(50))

        #expect(helperManager.installCallCount == 0)
        #expect(model.onboardingAutoOpenToken == autoOpenToken)
    }

    @Test
    func performingApprovalCardActionOpensSettings() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .requiresApproval)
        let settingsRecorder = SettingsRecorder()
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(
                status: .requiresApproval,
                message: "Approve AI Power in System Settings > Login Items & Extensions."
            )
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now },
            openApprovalSettings: {
                settingsRecorder.openCount += 1
            }
        )

        model.applyTrackSelection(.aiMode)
        try await Task.sleep(for: .milliseconds(50))

        model.performPermissionCardAction()

        #expect(settingsRecorder.openCount == 1)
    }

    @Test
    func addingCustomKeywordRefreshesVisibleKeywordLists() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let keywordBox = KeywordBox(customKeywords: [])
        let portBox = PortBox(customPorts: [])
        let wakeOptionsBox = WakeOptionsBox(options: .default)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now },
            builtInKeywordsProvider: { ["codex", "claude"] },
            customKeywordsProvider: { keywordBox.customKeywords },
            addCustomKeywordAction: { keyword in
                keywordBox.customKeywords.append(keyword)
                return true
            },
            monitoredPortsProvider: { [18789] },
            customPortsProvider: { portBox.customPorts },
            addCustomPortAction: { rawValue in
                guard let port = Int(rawValue) else {
                    return false
                }
                portBox.customPorts.append(port)
                return true
            },
            wakeOptionsProvider: { wakeOptionsBox.options },
            setWakeOptionsAction: { options in
                wakeOptionsBox.options = options
            },
            debugLogPath: "/tmp/ai_power_debug.log"
        )

        #expect(model.builtInProcessKeywords == ["codex", "claude"])
        #expect(model.customProcessKeywords == [])
        #expect(model.monitoredPorts == [18789])
        #expect(model.customMonitoredPorts == [])
        #expect(model.monitorsSummaryText == "Apps 2 • Ports 1")
        #expect(model.builtInToolsSummaryText == "Monitoring 2 built-in AI tools")
        #expect(model.debugLogPath == "/tmp/ai_power_debug.log")
        #expect(model.wakeControlOptions == .default)

        model.addCustomKeyword("vscode")
        model.addCustomPort("19000")

        #expect(model.customProcessKeywords == ["vscode"])
        #expect(model.customMonitoredPorts == [19000])
        #expect(model.monitorsSummaryText == "Apps 3 • Ports 2")
        #expect(model.builtInToolsSummaryText == "Monitoring 2 built-in AI tools")
    }

    @Test
    func removingCustomMonitorsRefreshesVisibleLists() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let keywordBox = KeywordBox(customKeywords: ["kimi"])
        let portBox = PortBox(customPorts: [19000])
        let wakeOptionsBox = WakeOptionsBox(options: .default)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now },
            builtInKeywordsProvider: { ["codex", "claude"] },
            customKeywordsProvider: { keywordBox.customKeywords },
            addCustomKeywordAction: { keyword in
                guard keywordBox.customKeywords.contains(keyword) == false else {
                    return false
                }
                keywordBox.customKeywords.append(keyword)
                return true
            },
            removeCustomKeywordAction: { keyword in
                keywordBox.customKeywords.removeAll { $0 == keyword }
                return true
            },
            monitoredPortsProvider: { [18789] },
            customPortsProvider: { portBox.customPorts },
            addCustomPortAction: { rawValue in
                guard let port = Int(rawValue), portBox.customPorts.contains(port) == false else {
                    return false
                }
                portBox.customPorts.append(port)
                return true
            },
            removeCustomPortAction: { port in
                portBox.customPorts.removeAll { $0 == port }
                return true
            },
            wakeOptionsProvider: { wakeOptionsBox.options },
            setWakeOptionsAction: { options in
                wakeOptionsBox.options = options
            }
        )

        #expect(model.customProcessKeywords == ["kimi"])
        #expect(model.customMonitoredPorts == [19000])

        #expect(model.removeCustomKeyword("kimi"))
        #expect(model.removeCustomPort(19000))

        #expect(model.customProcessKeywords.isEmpty)
        #expect(model.customMonitoredPorts.isEmpty)
        #expect(model.monitorsSummaryText == "Apps 2 • Ports 1")
    }

    @Test
    func prepareForTerminationRestoresIdleSleepAndBaseline() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let assertionController = StubAssertionController()
        let model = AppModel(
            engine: makeEngine(
                statusBox: statusBox,
                helperController: helperManager,
                assertionController: assertionController
            ),
            helperManager: helperManager,
            now: { timeBox.now }
        )

        model.applyTrackSelection(.infinity)
        await model.refreshForTesting()
        await model.prepareForTermination()

        #expect(assertionController.appliedIntents.last == .allowIdleSleep)
        #expect(helperManager.appliedHelperIntents.last == .disarm)
    }

    @Test
    func selectingOffImmediatelyRestoresIdleSleepAndBaseline() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let assertionController = StubAssertionController()
        let model = AppModel(
            engine: makeEngine(
                statusBox: statusBox,
                helperController: helperManager,
                assertionController: assertionController
            ),
            helperManager: helperManager,
            now: { timeBox.now }
        )

        model.applyTrackSelection(.infinity)
        await model.refreshForTesting()

        model.applyTrackSelection(.off)
        try await Task.sleep(for: .milliseconds(50))

        #expect(assertionController.appliedIntents.last == .allowIdleSleep)
        #expect(helperManager.appliedHelperIntents.last == .disarm)
    }

    @Test
    func disablingComputerSleepImmediatelyRestoresIdleSleepAndBaseline() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let wakeOptionsBox = WakeOptionsBox(options: .default)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let assertionController = StubAssertionController()
        let model = AppModel(
            engine: makeEngine(
                statusBox: statusBox,
                helperController: helperManager,
                assertionController: assertionController
            ),
            helperManager: helperManager,
            now: { timeBox.now },
            wakeOptionsProvider: { wakeOptionsBox.options },
            setWakeOptionsAction: { options in
                wakeOptionsBox.options = options
            }
        )

        model.applyTrackSelection(.infinity)
        await model.refreshForTesting()

        model.setPreventComputerSleep(false)
        try await Task.sleep(for: .milliseconds(50))

        #expect(model.wakeControlOptions == WakeControlOptions(
            preventComputerSleep: false,
            preventDisplaySleep: false,
            preventLockScreen: false,
            aiIdleGraceMinutes: 5,
            aiNetworkThresholdKilobytes: 30
        ))
        #expect(assertionController.appliedIntents.last == .allowIdleSleep)
        #expect(helperManager.appliedHelperIntents.last == .disarm)
    }

    @Test
    func wakeOptionsDefaultToComputerSleepOnlyAndPromoteDependencies() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let wakeOptionsBox = WakeOptionsBox(options: .default)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now },
            wakeOptionsProvider: { wakeOptionsBox.options },
            setWakeOptionsAction: { options in
                wakeOptionsBox.options = options
            }
        )

        #expect(model.wakeControlOptions == .default)
        #expect(model.wakeControlOptions.aiIdleGraceMinutes == 5)

        model.setPreventDisplaySleep(true)
        #expect(model.wakeControlOptions == WakeControlOptions(
            preventComputerSleep: true,
            preventDisplaySleep: true,
            preventLockScreen: false,
            aiIdleGraceMinutes: 5,
            aiNetworkThresholdKilobytes: 30
        ))

        model.setPreventLockScreen(true)
        #expect(model.wakeControlOptions == WakeControlOptions(
            preventComputerSleep: true,
            preventDisplaySleep: true,
            preventLockScreen: true,
            aiIdleGraceMinutes: 5,
            aiNetworkThresholdKilobytes: 30
        ))

        model.setPreventComputerSleep(false)
        #expect(model.wakeControlOptions == WakeControlOptions(
            preventComputerSleep: false,
            preventDisplaySleep: false,
            preventLockScreen: false,
            aiIdleGraceMinutes: 5,
            aiNetworkThresholdKilobytes: 30
        ))
    }

    @Test
    func settingAiIdleGraceUpdatesWakeOptions() {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let wakeOptionsBox = WakeOptionsBox(options: .default)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now },
            wakeOptionsProvider: { wakeOptionsBox.options },
            setWakeOptionsAction: { options in
                wakeOptionsBox.options = options
            }
        )

        model.setAIIdleGraceMinutes(10)

        #expect(model.wakeControlOptions.aiIdleGraceMinutes == 10)
        #expect(wakeOptionsBox.options.aiIdleGraceMinutes == 10)
    }

    @Test
    func settingAiNetworkThresholdUpdatesWakeOptions() {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let wakeOptionsBox = WakeOptionsBox(options: .default)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now },
            wakeOptionsProvider: { wakeOptionsBox.options },
            setWakeOptionsAction: { options in
                wakeOptionsBox.options = options
            }
        )

        model.setAINetworkThresholdKilobytes(80)

        #expect(model.wakeControlOptions.aiNetworkThresholdKilobytes == 80)
        #expect(wakeOptionsBox.options.aiNetworkThresholdKilobytes == 80)
    }

    @Test
    func increasingAiNetworkThresholdMovesToNextPreset() {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let wakeOptionsBox = WakeOptionsBox(options: .default)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now },
            wakeOptionsProvider: { wakeOptionsBox.options },
            setWakeOptionsAction: { options in
                wakeOptionsBox.options = options
            }
        )

        model.increaseAINetworkThresholdKilobytes()

        #expect(model.wakeControlOptions.aiNetworkThresholdKilobytes == 50)
        #expect(wakeOptionsBox.options.aiNetworkThresholdKilobytes == 50)
    }

    @Test
    func decreasingAiNetworkThresholdMovesToPreviousPreset() {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let wakeOptionsBox = WakeOptionsBox(
            options: WakeControlOptions(
                preventComputerSleep: true,
                preventDisplaySleep: false,
                preventLockScreen: false,
                aiIdleGraceMinutes: 5,
                aiNetworkThresholdKilobytes: 50
            )
        )
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            now: { timeBox.now },
            wakeOptionsProvider: { wakeOptionsBox.options },
            setWakeOptionsAction: { options in
                wakeOptionsBox.options = options
            }
        )

        model.decreaseAINetworkThresholdKilobytes()

        #expect(model.wakeControlOptions.aiNetworkThresholdKilobytes == 30)
        #expect(wakeOptionsBox.options.aiNetworkThresholdKilobytes == 30)
    }

    @Test
    func panelOpenLoadsDiscoverFeedAndUsesRemoteDefaultExpansion() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let loader = StubDiscoverFeedLoader(
            result: DiscoverFeedLoadResult(
                feed: DiscoverFeed(
                    enabled: true,
                    defaultExpanded: true,
                    cards: [
                        DiscoverCard(
                            id: "github",
                            kind: "github",
                            title: "Explore More Projects",
                            subtitle: "See more AI tools on GitHub.",
                            ctaText: "Open GitHub",
                            url: "https://github.com/gaoshizai"
                        )
                    ]
                ),
                source: .remote
            )
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            discoverFeedLoader: loader,
            now: { timeBox.now }
        )

        model.panelDidOpen()
        try await Task.sleep(for: .milliseconds(50))

        #expect(model.discoverCards.count == 1)
        #expect(model.isDiscoverVisible == true)
        #expect(model.discoverDefaultExpanded == true)
    }

    @Test
    func fallbackDiscoverFeedStaysCollapsedByDefault() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let loader = StubDiscoverFeedLoader(
            result: DiscoverFeedLoadResult(
                feed: DiscoverFeed(
                    enabled: true,
                    defaultExpanded: true,
                    cards: [
                        DiscoverCard(
                            id: "community",
                            kind: "community",
                            title: "Discover AI",
                            subtitle: "Explore AI communities.",
                            ctaText: "Open Community",
                            url: "https://huggingface.co"
                        )
                    ]
                ),
                source: .fallback
            )
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            discoverFeedLoader: loader,
            now: { timeBox.now }
        )

        model.panelDidOpen()
        try await Task.sleep(for: .milliseconds(50))

        #expect(model.discoverCards.count == 1)
        #expect(model.isDiscoverVisible == true)
        #expect(model.discoverDefaultExpanded == false)
    }

    @Test
    func panelOpenLocalizesDiscoverFeedForPreferredLanguage() async throws {
        let timeBox = TimeBox(now: referenceDate)
        let statusBox = HelperStatusBox(initialStatus: .ready)
        let helperManager = RecordingHelperManager(
            statusBox: statusBox,
            installResult: HelperPreparationResult(status: .ready, message: nil)
        )
        let loader = StubDiscoverFeedLoader(
            result: DiscoverFeedLoadResult(
                feed: DiscoverFeed(
                    enabled: true,
                    defaultExpanded: false,
                    cards: [
                        DiscoverCard(
                            id: "github",
                            kind: nil,
                            title: "Explore More Projects",
                            subtitle: "See more AI tools on GitHub.",
                            ctaText: "Open GitHub",
                            url: "https://github.com/insogao",
                            localizations: [
                                "zh-Hans": DiscoverCardLocalization(
                                    title: "查看更多项目",
                                    subtitle: "在 GitHub 上查看更多 AI 工具。",
                                    ctaText: "打开 GitHub"
                                )
                            ]
                        )
                    ]
                ),
                source: .remote
            )
        )
        let model = AppModel(
            engine: makeEngine(statusBox: statusBox, helperController: helperManager),
            helperManager: helperManager,
            discoverFeedLoader: loader,
            preferredLanguagesProvider: { ["zh-Hans"] },
            now: { timeBox.now }
        )

        model.panelDidOpen()
        try await Task.sleep(for: .milliseconds(50))

        #expect(model.discoverCards.first?.title == "查看更多项目")
        #expect(model.discoverCards.first?.ctaText == "打开 GitHub")
    }
}

@MainActor
private func makeEngine(
    statusBox: HelperStatusBox,
    helperController: any ContinuityHelperControlling,
    sampler: any MonitoringSampling = StubSampler(),
    assertionController: any SleepAssertionControlling = StubAssertionController()
) -> MonitoringEngine {
    MonitoringEngine(
        sampler: sampler,
        assertionController: assertionController,
        continuityEnvironmentProvider: StubEnvironmentProvider(statusBox: statusBox),
        continuityHelperController: helperController
    )
}

private let referenceDate = Date(timeIntervalSince1970: 1_741_335_200)

private struct StubSampler: MonitoringSampling {
    func sample() async throws -> MonitoringSnapshot {
        MonitoringSnapshot(
            cpuUsagePercent: 0,
            networkBytesPerSecond: 0,
            diskBytesPerSecond: 0,
            detectedApplicationKeywords: [],
            activeApplicationKeywords: [],
            listeningPorts: []
        )
    }
}

@MainActor
private final class WakeOptionsBox {
    var options: WakeControlOptions

    init(options: WakeControlOptions) {
        self.options = options
    }
}

private actor SequenceSampler: MonitoringSampling {
    private var snapshots: [MonitoringSnapshot]
    private let fallback: MonitoringSnapshot

    init(snapshots: [MonitoringSnapshot]) {
        self.snapshots = snapshots
        self.fallback = snapshots.last ?? MonitoringSnapshot(
            cpuUsagePercent: 0,
            networkBytesPerSecond: 0,
            diskBytesPerSecond: 0,
            detectedApplicationKeywords: [],
            activeApplicationKeywords: [],
            listeningPorts: []
        )
    }

    func sample() async throws -> MonitoringSnapshot {
        guard snapshots.isEmpty == false else {
            return fallback
        }

        return snapshots.removeFirst()
    }
}

private actor StubDiscoverFeedLoader: DiscoverFeedLoading {
    let result: DiscoverFeedLoadResult

    init(result: DiscoverFeedLoadResult) {
        self.result = result
    }

    func load() async -> DiscoverFeedLoadResult {
        result
    }
}

private struct StubEnvironmentProvider: ContinuityEnvironmentProviding {
    let statusBox: HelperStatusBox

    func currentEnvironment() async -> ContinuityEnvironment {
        let helperStatus = await statusBox.status()
        return ContinuityEnvironment(
            hardwareClass: .portable,
            powerSource: .ac,
            helperStatus: helperStatus,
            isClamshellClosed: false
        )
    }
}

@MainActor
private final class TimeBox {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

private actor HelperStatusBox {
    private var currentStatus: HelperStatus

    init(initialStatus: HelperStatus) {
        self.currentStatus = initialStatus
    }

    func status() -> HelperStatus {
        currentStatus
    }

    func setStatus(_ status: HelperStatus) {
        currentStatus = status
    }
}

@MainActor
private final class RecordingHelperManager: ContinuityHelperManaging, ContinuityHelperControlling {
    private let statusBox: HelperStatusBox
    private let installResult: HelperPreparationResult
    private(set) var installCallCount = 0
    private(set) var appliedHelperIntents: [HelperIntent] = []
    private(set) var restoreBaselineCallCount = 0

    init(statusBox: HelperStatusBox, installResult: HelperPreparationResult) {
        self.statusBox = statusBox
        self.installResult = installResult
    }

    func installOrRegister() async -> HelperPreparationResult {
        installCallCount += 1
        await statusBox.setStatus(installResult.status)
        return installResult
    }

    func status() async -> HelperStatus {
        await statusBox.status()
    }

    func apply(intent: HelperIntent) async {
        appliedHelperIntents.append(intent)
    }

    func restoreBaselinePolicy() async {
        restoreBaselineCallCount += 1
    }

    func fetchRecoveryState() async -> String? { nil }
}

@MainActor
private final class StubAssertionController: SleepAssertionControlling {
    private(set) var appliedIntents: [AssertionIntent] = []

    func apply(intent: AssertionIntent) {
        appliedIntents.append(intent)
    }
}

@MainActor
private final class SettingsRecorder {
    var openCount = 0
}

@MainActor
private final class KeywordBox {
    var customKeywords: [String]

    init(customKeywords: [String]) {
        self.customKeywords = customKeywords
    }
}

@MainActor
private final class PortBox {
    var customPorts: [Int]

    init(customPorts: [Int]) {
        self.customPorts = customPorts
    }
}
