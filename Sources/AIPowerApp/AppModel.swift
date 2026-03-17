import AIPowerCore
import AIPowerSystem
import AppKit
import Foundation

enum WakeTrackSelection: Sendable, Equatable {
    case aiMode
    case off
    case timed(duration: TimeInterval)
    case infinity

    var requiresContinuityPreparation: Bool {
        switch self {
        case .off:
            return false
        case .aiMode, .timed, .infinity:
            return true
        }
    }

    var isTimed: Bool {
        if case .timed = self {
            return true
        }
        return false
    }

    var label: String {
        switch self {
        case .aiMode:
            return "AI Mode"
        case .off:
            return "Off"
        case let .timed(duration):
            return Self.timeLabel(for: duration)
        case .infinity:
            return "∞"
        }
    }

    static func timeLabel(for duration: TimeInterval) -> String {
        if duration >= 24 * 60 * 60 {
            let days = duration / (24 * 60 * 60)
            return days.rounded(.toNearestOrEven) >= 10 ? "\(Int(days.rounded()))d" : String(format: "%.1fd", days)
        }
        if duration >= 60 * 60 {
            let hours = duration / (60 * 60)
            return hours.rounded(.toNearestOrEven) >= 10 ? "\(Int(hours.rounded()))h" : String(format: "%.1fh", hours)
        }

        return "\(Int((duration / 60).rounded()))m"
    }
}

enum MenuBarIconState: Sendable, Equatable {
    case off
    case armed
    case infinity
    case warning
}

struct PermissionActionCard: Sendable, Equatable {
    let title: String
    let message: String
    let actionTitle: String
}

struct ActivityBadge: Sendable, Equatable, Identifiable {
    let label: String

    var id: String { label }
}

@MainActor
final class AppModel: ObservableObject {
    static let monitoringRefreshInterval: Duration = .seconds(2)
    static let aiIdleGraceMinuteOptions = [1, 3, 5, 10, 15]

    @Published private(set) var mode: AppMode
    @Published private(set) var continuityMode: ContinuityMode
    @Published private(set) var currentTrackSelection: WakeTrackSelection
    @Published private(set) var primaryStatusText: String
    @Published private(set) var secondaryStatusText: String?
    @Published private(set) var remainingText: String?
    @Published private(set) var menuBarIconState: MenuBarIconState
    @Published private(set) var statusLines: [String]
    @Published private(set) var helperStatus: HelperStatus
    @Published private(set) var helperStatusText: String
    @Published private(set) var environmentSummary: String
    @Published private(set) var effectiveCapabilityText: String
    @Published private(set) var permissionCard: PermissionActionCard?
    @Published private(set) var onboardingAutoOpenToken: UUID?
    @Published private(set) var builtInProcessKeywords: [String]
    @Published private(set) var customProcessKeywords: [String]
    @Published private(set) var monitoredPorts: [Int]
    @Published private(set) var customMonitoredPorts: [Int]
    @Published private(set) var debugLogPath: String?
    @Published private(set) var wakeControlOptions: WakeControlOptions
    @Published private(set) var discoverCards: [DiscoverCard]
    @Published private(set) var isDiscoverVisible: Bool
    @Published private(set) var discoverDefaultExpanded: Bool

    private let engine: MonitoringEngine
    private let helperManager: any ContinuityHelperManaging
    private let discoverFeedLoader: any DiscoverFeedLoading
    private let preferredLanguagesProvider: () -> [String]
    private let now: () -> Date
    private let openApprovalSettings: () -> Void
    private let builtInKeywordsProvider: () -> [String]
    private let customKeywordsProvider: () -> [String]
    private let addCustomKeywordAction: (String) -> Bool
    private let removeCustomKeywordAction: (String) -> Bool
    private let monitoredPortsProvider: () -> [Int]
    private let customPortsProvider: () -> [Int]
    private let addCustomPortAction: (String) -> Bool
    private let removeCustomPortAction: (Int) -> Bool
    private let wakeOptionsProvider: () -> WakeControlOptions
    private let setWakeOptionsAction: (WakeControlOptions) -> Void
    private var monitoringTask: Task<Void, Never>?
    private var isPreparingHelper = false
    private var didBootstrapPermissionFlow = false
    private var manualWakeStartedAt: Date?
    private var manualWakeDeadline: Date?
    private var shouldShowRemainingOnNextOpen = false
    private var hasIssuedOnboardingAutoOpen = false
    private var recentActivityEntries: [RecentActivityEntry] = []
    private var recentActivitySummaryText: String?
    private var hasLoadedDiscoverFeed = false
    private var latestHelperPreparationMessage: String?

    init(
        engine: MonitoringEngine,
        helperManager: any ContinuityHelperManaging,
        discoverFeedLoader: any DiscoverFeedLoading = DiscoverFeedLoader(),
        preferredLanguagesProvider: @escaping () -> [String] = { Locale.preferredLanguages },
        now: @escaping () -> Date = Date.init,
        builtInKeywordsProvider: @escaping () -> [String] = { [] },
        customKeywordsProvider: @escaping () -> [String] = { [] },
        addCustomKeywordAction: @escaping (String) -> Bool = { _ in false },
        removeCustomKeywordAction: @escaping (String) -> Bool = { _ in false },
        monitoredPortsProvider: @escaping () -> [Int] = { [] },
        customPortsProvider: @escaping () -> [Int] = { [] },
        addCustomPortAction: @escaping (String) -> Bool = { _ in false },
        removeCustomPortAction: @escaping (Int) -> Bool = { _ in false },
        wakeOptionsProvider: @escaping () -> WakeControlOptions = { .default },
        setWakeOptionsAction: @escaping (WakeControlOptions) -> Void = { _ in },
        debugLogPath: String? = nil,
        openApprovalSettings: @escaping () -> Void = {
            guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else {
                return
            }
            NSWorkspace.shared.open(url)
        }
    ) {
        self.engine = engine
        self.helperManager = helperManager
        self.discoverFeedLoader = discoverFeedLoader
        self.preferredLanguagesProvider = preferredLanguagesProvider
        self.now = now
        self.builtInKeywordsProvider = builtInKeywordsProvider
        self.customKeywordsProvider = customKeywordsProvider
        self.addCustomKeywordAction = addCustomKeywordAction
        self.removeCustomKeywordAction = removeCustomKeywordAction
        self.monitoredPortsProvider = monitoredPortsProvider
        self.customPortsProvider = customPortsProvider
        self.addCustomPortAction = addCustomPortAction
        self.removeCustomPortAction = removeCustomPortAction
        self.wakeOptionsProvider = wakeOptionsProvider
        self.setWakeOptionsAction = setWakeOptionsAction
        self.openApprovalSettings = openApprovalSettings
        let initialSelection = Self.initialSelection(mode: engine.mode)
        self.mode = engine.mode
        self.continuityMode = engine.continuityMode
        self.currentTrackSelection = initialSelection
        self.primaryStatusText = "Idle"
        self.secondaryStatusText = nil
        self.remainingText = nil
        self.menuBarIconState = Self.iconState(for: initialSelection)
        self.statusLines = ["Idle"]
        self.helperStatus = .notInstalled
        self.helperStatusText = "Not Installed"
        self.environmentSummary = "Unknown environment"
        self.effectiveCapabilityText = "Inactive"
        self.permissionCard = nil
        self.onboardingAutoOpenToken = nil
        self.builtInProcessKeywords = builtInKeywordsProvider()
        self.customProcessKeywords = customKeywordsProvider()
        self.monitoredPorts = monitoredPortsProvider()
        self.customMonitoredPorts = customPortsProvider()
        self.debugLogPath = debugLogPath
        self.wakeControlOptions = wakeOptionsProvider()
        self.discoverCards = []
        self.isDiscoverVisible = false
        self.discoverDefaultExpanded = false
        self.engine.wakeControlOptions = self.wakeControlOptions
    }

    static func live() -> AppModel {
        let helperManager = LocalContinuityHelperManager()
        let debugLogger = FileMonitoringDebugLogger()
        let wakeOptions = WakeControlConfiguration.currentOptions()
        let engine = MonitoringEngine(
            continuityMode: .aiContinuity,
            sampler: LiveMonitoringSampler(),
            assertionController: PowerAssertionController(),
            continuityEnvironmentProvider: LiveContinuityEnvironmentProvider(
                helperManager: helperManager
            ),
            continuityHelperController: helperManager,
            debugLogger: { record in
                await debugLogger.record(record)
            }
        )
        engine.wakeControlOptions = wakeOptions
        return AppModel(
            engine: engine,
            helperManager: helperManager,
            builtInKeywordsProvider: {
                ProcessKeywordConfiguration.builtInKeywords
            },
            customKeywordsProvider: {
                ProcessKeywordConfiguration.customKeywords()
            },
            addCustomKeywordAction: { keyword in
                ProcessKeywordConfiguration.addCustomKeyword(keyword)
            },
            removeCustomKeywordAction: { keyword in
                ProcessKeywordConfiguration.removeCustomKeyword(keyword)
            },
            monitoredPortsProvider: {
                AIModePortConfiguration.builtInPorts
            },
            customPortsProvider: {
                AIModePortConfiguration.customPorts()
            },
            addCustomPortAction: { value in
                AIModePortConfiguration.addCustomPort(value)
            },
            removeCustomPortAction: { port in
                AIModePortConfiguration.removeCustomPort(port)
            },
            wakeOptionsProvider: {
                WakeControlConfiguration.currentOptions()
            },
            setWakeOptionsAction: { options in
                WakeControlConfiguration.setOptions(options)
            },
            debugLogPath: FileMonitoringDebugLogger.defaultFileURL.path
        )
    }

    func startMonitoring() {
        guard monitoringTask == nil else {
            return
        }

        bootstrapPermissionFlowIfNeeded()

        monitoringTask = Task { [weak self] in
            guard let self else { return }
            await self.runMonitoringLoop()
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        Task { [engine] in
            await engine.resetRuntimeState(clearDecisionState: true)
        }
    }

    func prepareForTermination() async {
        monitoringTask?.cancel()
        monitoringTask = nil
        await engine.resetRuntimeState(clearDecisionState: true)
    }

    func panelDidOpen() {
        shouldShowRemainingOnNextOpen = true
        updateRemainingPresentation()
        loadDiscoverFeedIfNeeded()
    }

    func applyTrackSelection(_ selection: WakeTrackSelection) {
        currentTrackSelection = selection
        remainingText = nil
        shouldShowRemainingOnNextOpen = false

        let currentTime = now()
        switch selection {
        case .aiMode:
            manualWakeStartedAt = nil
            manualWakeDeadline = nil
            mode = .auto
            continuityMode = .aiContinuity
        case .off:
            manualWakeStartedAt = nil
            manualWakeDeadline = nil
            mode = .off
            continuityMode = .standard
            clearRecentActivityWindow()
        case .infinity:
            manualWakeStartedAt = currentTime
            manualWakeDeadline = nil
            mode = .manual
            continuityMode = .aiContinuity
            clearRecentActivityWindow()
        case let .timed(duration):
            manualWakeStartedAt = currentTime
            manualWakeDeadline = currentTime.addingTimeInterval(duration)
            mode = .manual
            continuityMode = .aiContinuity
            clearRecentActivityWindow()
        }

        engine.mode = mode
        engine.continuityMode = continuityMode

        if selection.requiresContinuityPreparation {
            prepareAIContinuityIfNeeded()
        } else {
            Task { [engine] in
                await engine.resetRuntimeState(clearDecisionState: true)
            }
            updatePresentation(using: engine.state)
        }
    }

    func performPrimaryAction() {
        performPermissionCardAction()
    }

    func performPermissionCardAction() {
        switch helperStatus {
        case .requiresApproval:
            openApprovalSettings()
        case .notInstalled, .degraded:
            installContinuityHelper()
        case .ready:
            break
        }
    }

    @discardableResult
    func addCustomKeyword(_ keyword: String) -> Bool {
        let added = addCustomKeywordAction(keyword)
        refreshKeywordPresentation()
        return added
    }

    @discardableResult
    func addCustomPort(_ value: String) -> Bool {
        let added = addCustomPortAction(value)
        refreshKeywordPresentation()
        return added
    }

    @discardableResult
    func removeCustomKeyword(_ keyword: String) -> Bool {
        let removed = removeCustomKeywordAction(keyword)
        refreshKeywordPresentation()
        return removed
    }

    @discardableResult
    func removeCustomPort(_ port: Int) -> Bool {
        let removed = removeCustomPortAction(port)
        refreshKeywordPresentation()
        return removed
    }

    var primaryActionTitle: String? {
        permissionCard?.actionTitle
    }

    var effectiveMonitoredApplications: [String] {
        builtInProcessKeywords + customProcessKeywords
    }

    var effectiveMonitoredPorts: [Int] {
        monitoredPorts + customMonitoredPorts
    }

    var monitorsSummaryText: String {
        "Apps \(effectiveMonitoredApplications.count) • Ports \(effectiveMonitoredPorts.count)"
    }

    var builtInToolsSummaryText: String {
        "Monitoring \(builtInProcessKeywords.count) built-in AI tools"
    }

    var activityBadges: [ActivityBadge] {
        recentActivityEntries.map { ActivityBadge(label: $0.label) }
    }

    var selectionBadgeText: String {
        switch currentTrackSelection {
        case .timed:
            guard let manualWakeDeadline else {
                return currentTrackSelection.label
            }

            let remaining = max(manualWakeDeadline.timeIntervalSince(now()), 0)
            return Self.remainingText(for: remaining)
        case .aiMode, .off, .infinity:
            return currentTrackSelection.label
        }
    }

    func refreshForTesting() async {
        await refresh()
    }

    func setPreventComputerSleep(_ enabled: Bool) {
        var updated = wakeControlOptions
        updated.preventComputerSleep = enabled
        if enabled == false {
            updated.preventDisplaySleep = false
            updated.preventLockScreen = false
        }
        applyWakeControlOptions(updated)
    }

    func setPreventDisplaySleep(_ enabled: Bool) {
        var updated = wakeControlOptions
        updated.preventDisplaySleep = enabled
        if enabled {
            updated.preventComputerSleep = true
        }
        applyWakeControlOptions(updated)
    }

    func setPreventLockScreen(_ enabled: Bool) {
        var updated = wakeControlOptions
        updated.preventLockScreen = enabled
        if enabled {
            updated.preventComputerSleep = true
        }
        applyWakeControlOptions(updated)
    }

    func setAIIdleGraceMinutes(_ minutes: Int) {
        var updated = wakeControlOptions
        updated.aiIdleGraceMinutes = max(minutes, 0)
        applyWakeControlOptions(updated)
    }

    var aiIdleGraceSummaryText: String {
        "\(wakeControlOptions.aiIdleGraceMinutes) min"
    }

    var aiIdleGraceDescriptionText: String {
        "How long AI Mode stays awake after activity stops."
    }

    var discoverSummaryText: String? {
        guard discoverCards.count > 1 else {
            return nil
        }

        return "\(discoverCards.count) cards"
    }

    private func installContinuityHelper() {
        guard isPreparingHelper == false else {
            return
        }

        isPreparingHelper = true
        Task { [weak self] in
            guard let self else { return }
            defer { isPreparingHelper = false }
            let result = await helperManager.installOrRegister()
            helperStatus = result.status
            helperStatusText = result.status.displayText
            latestHelperPreparationMessage = result.status == .ready ? nil : (result.message ?? result.status.guidanceText)
            synchronizePermissionPresentation(for: result.status)
            await refresh()
            if result.status != .ready {
                latestHelperPreparationMessage = result.message ?? result.status.guidanceText
                synchronizePermissionPresentation(for: helperStatus)
                updatePresentation(using: engine.state)
            }
        }
    }

    private func runMonitoringLoop() async {
        while Task.isCancelled == false {
            await refresh()
            try? await Task.sleep(for: Self.monitoringRefreshInterval)
        }
    }

    private func refresh() async {
        synchronizeTimedSelectionIfNeeded()

        do {
            let state = try await engine.tick()
            apply(state: state)
        } catch {
            primaryStatusText = "Error"
            secondaryStatusText = error.localizedDescription
            remainingText = nil
            menuBarIconState = .warning
            statusLines = ["Sampling failed: \(error.localizedDescription)"]
        }
    }

    private func apply(state: MonitoringState) {
        mode = state.mode
        continuityMode = state.continuityMode
        helperStatus = state.continuityEnvironment.helperStatus
        helperStatusText = state.continuityEnvironment.helperStatus.displayText
        if helperStatus == .ready {
            latestHelperPreparationMessage = nil
        }
        recentActivitySummaryText = synchronizeRecentActivityWindow(using: state, at: now())
        synchronizePermissionPresentation(for: helperStatus)
        environmentSummary = [
            state.continuityEnvironment.hardwareClass == .portable ? "Portable Mac" : "Desktop Mac",
            state.continuityEnvironment.powerSource.displayText,
            state.continuityEnvironment.isClamshellClosed ? "Lid closed" : "Lid open",
        ].joined(separator: " • ")
        effectiveCapabilityText = state.executionPolicy.effectiveCapability.displayText
        statusLines = state.outcome.reasons.isEmpty
            ? ["Idle"]
            : state.outcome.reasons.map(\.displayText) + [state.executionPolicy.userVisibleStatus]

        updatePresentation(using: state)
    }

    private func prepareAIContinuityIfNeeded() {
        Task { [weak self] in
            guard let self else { return }

            let currentStatus = await helperManager.status()
            helperStatus = currentStatus
            helperStatusText = currentStatus.displayText
            if currentStatus == .ready {
                latestHelperPreparationMessage = nil
            }
            synchronizePermissionPresentation(for: currentStatus)

            guard currentStatus != .ready else {
                await refresh()
                return
            }

            await refresh()
        }
    }

    private func bootstrapPermissionFlowIfNeeded() {
        guard didBootstrapPermissionFlow == false else {
            return
        }

        didBootstrapPermissionFlow = true

        guard currentTrackSelection.requiresContinuityPreparation else {
            return
        }

        prepareAIContinuityIfNeeded()
    }

    private func synchronizeTimedSelectionIfNeeded() {
        guard let manualWakeDeadline else {
            return
        }

        if now() >= manualWakeDeadline {
            currentTrackSelection = .off
            mode = .off
            continuityMode = .standard
            manualWakeStartedAt = nil
            self.manualWakeDeadline = nil
            remainingText = nil
            shouldShowRemainingOnNextOpen = false
            engine.mode = .off
            engine.continuityMode = .standard
        }
    }

    private func synchronizePermissionPresentation(for status: HelperStatus) {
        permissionCard = permissionCard(for: status)

        let shouldAutoOpen = currentTrackSelection.requiresContinuityPreparation && permissionCard != nil
        if shouldAutoOpen == false {
            hasIssuedOnboardingAutoOpen = false
            return
        }

        guard hasIssuedOnboardingAutoOpen == false else {
            return
        }

        onboardingAutoOpenToken = UUID()
        hasIssuedOnboardingAutoOpen = true
    }

    private func refreshKeywordPresentation() {
        builtInProcessKeywords = builtInKeywordsProvider()
        customProcessKeywords = customKeywordsProvider()
        monitoredPorts = monitoredPortsProvider()
        customMonitoredPorts = customPortsProvider()
        wakeControlOptions = wakeOptionsProvider()
        engine.wakeControlOptions = wakeControlOptions
    }

    private func applyWakeControlOptions(_ options: WakeControlOptions) {
        wakeControlOptions = options
        setWakeOptionsAction(options)
        engine.wakeControlOptions = options
        Task { [engine] in
            await engine.reapplyCurrentPolicy()
        }
    }

    private func permissionCard(for status: HelperStatus) -> PermissionActionCard? {
        guard currentTrackSelection.requiresContinuityPreparation else {
            return nil
        }

        let helperMessage = helperGuidanceText(for: status)

        switch status {
        case .notInstalled, .degraded:
            return PermissionActionCard(
                title: "Enable AI Continuity",
                message: helperMessage ?? "Install the AI Continuity helper to enable closed-lid runs.",
                actionTitle: "Install Helper"
            )
        case .requiresApproval:
            return PermissionActionCard(
                title: "Approve Closed-Lid Access",
                message: helperMessage ?? "Approve AI Power in System Settings > Login Items & Extensions.",
                actionTitle: "Open Settings"
            )
        case .ready:
            return nil
        }
    }

    private func updatePresentation(using state: MonitoringState) {
        let helperNeedsAttention = state.continuityEnvironment.helperStatus != .ready &&
            currentTrackSelection.requiresContinuityPreparation
        let helperGuidance = helperNeedsAttention
            ? helperGuidanceText(for: state.continuityEnvironment.helperStatus)
            : nil

        switch currentTrackSelection {
        case .off:
            primaryStatusText = "Idle"
            secondaryStatusText = nil
            menuBarIconState = .off

        case .aiMode:
            remainingText = nil
            if helperNeedsAttention {
                primaryStatusText = state.continuityEnvironment.helperStatus.displayText
                secondaryStatusText = helperGuidance
                menuBarIconState = .warning
            } else {
                primaryStatusText = state.outcome.shouldPreventSleep ? "Active" : "Idle"
                secondaryStatusText = nil
                menuBarIconState = .armed
            }

        case .infinity:
            primaryStatusText = "Keeping awake indefinitely"
            secondaryStatusText = helperGuidance
            menuBarIconState = helperNeedsAttention ? .warning : .infinity

        case .timed:
            primaryStatusText = "Keeping awake until \(Self.deadlineFormatter.string(from: manualWakeDeadline ?? now()))"
            secondaryStatusText = helperGuidance
            menuBarIconState = helperNeedsAttention ? .warning : .armed
        }

        updateRemainingPresentation()
    }

    private func helperGuidanceText(for status: HelperStatus) -> String? {
        if status == .ready {
            return nil
        }

        return latestHelperPreparationMessage ?? status.guidanceText
    }

    private func updateRemainingPresentation() {
        guard shouldShowRemainingOnNextOpen else {
            remainingText = nil
            return
        }

        guard case .timed = currentTrackSelection, let manualWakeDeadline else {
            remainingText = nil
            return
        }

        let remaining = max(manualWakeDeadline.timeIntervalSince(now()), 0)
        remainingText = Self.remainingText(for: remaining)
    }

    private static func initialSelection(mode: AppMode) -> WakeTrackSelection {
        switch mode {
        case .off:
            return .off
        case .manual:
            return .infinity
        case .auto, .developer:
            return .aiMode
        }
    }

    private static func iconState(for selection: WakeTrackSelection) -> MenuBarIconState {
        switch selection {
        case .off:
            return .off
        case .aiMode, .timed:
            return .armed
        case .infinity:
            return .infinity
        }
    }

    private static func remainingText(for remaining: TimeInterval) -> String {
        let totalMinutes = max(Int(remaining / 60), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            if minutes == 0 {
                return "\(hours)h remaining"
            }
            return "\(hours)h \(minutes)m remaining"
        }

        return "\(max(minutes, 1))m remaining"
    }

    private func synchronizeRecentActivityWindow(
        using state: MonitoringState,
        at timestamp: Date
    ) -> String? {
        guard currentTrackSelection == .aiMode else {
            clearRecentActivityWindow()
            return nil
        }

        let cutoff = timestamp.addingTimeInterval(-10)
        recentActivityEntries.removeAll { $0.timestamp < cutoff }

        let labels = recentActivityLabels(from: state)
        for label in labels {
            recentActivityEntries.removeAll { $0.label == label }
            recentActivityEntries.append(RecentActivityEntry(label: label, timestamp: timestamp))
        }

        let visibleLabels = recentActivityEntries.map(\.label)
        guard visibleLabels.isEmpty == false else {
            return nil
        }

        return "Activity: \(visibleLabels.joined(separator: ", "))"
    }

    private func recentActivityLabels(from state: MonitoringState) -> [String] {
        var labels: [String] = []

        if let snapshot = state.snapshot {
            for keyword in snapshot.activeApplicationKeywords where labels.contains(keyword) == false {
                labels.append(keyword)
            }

            for port in snapshot.listeningPorts {
                let label = "port \(port)"
                if labels.contains(label) == false {
                    labels.append(label)
                }
            }
        }

        for reason in state.outcome.reasons {
            let label: String?
            switch reason {
            case let .developerProcess(keyword):
                label = keyword
            case let .monitoredPort(port):
                label = "port \(port)"
            default:
                label = nil
            }

            if let label, labels.contains(label) == false {
                labels.append(label)
            }
        }
        return labels
    }

    private func clearRecentActivityWindow() {
        recentActivityEntries.removeAll()
        recentActivitySummaryText = nil
    }

    private func loadDiscoverFeedIfNeeded() {
        guard hasLoadedDiscoverFeed == false else {
            return
        }

        hasLoadedDiscoverFeed = true
        Task { [weak self] in
            guard let self else { return }
            let result = await discoverFeedLoader.load()
            await MainActor.run {
                applyDiscoverFeed(result)
            }
        }
    }

    private func applyDiscoverFeed(_ result: DiscoverFeedLoadResult) {
        let validCards = result.feed.cards
            .map { $0.localized(for: preferredLanguagesProvider()) }
            .filter { $0.destinationURL != nil }
        let isVisible = result.feed.enabled && validCards.isEmpty == false

        discoverCards = validCards
        isDiscoverVisible = isVisible
        discoverDefaultExpanded = isVisible && result.source == .remote ? result.feed.defaultExpanded : false
    }

    private static let deadlineFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

private struct RecentActivityEntry {
    let label: String
    let timestamp: Date
}
