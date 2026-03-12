import AIPowerCore
import AIPowerIPC
import Foundation

public struct PMSetSnapshot: Codable, Equatable, Sendable {
    public let sleepDisabled: Bool
    public let sleepMinutes: Int
    public let displaySleepMinutes: Int
    public let diskSleepMinutes: Int

    public init(
        sleepDisabled: Bool,
        sleepMinutes: Int,
        displaySleepMinutes: Int,
        diskSleepMinutes: Int
    ) {
        self.sleepDisabled = sleepDisabled
        self.sleepMinutes = sleepMinutes
        self.displaySleepMinutes = displaySleepMinutes
        self.diskSleepMinutes = diskSleepMinutes
    }
}

public struct PortableContinuityRecoveryState: Codable, Equatable, Sendable {
    public let baseline: PMSetSnapshot
    public let lastReason: String
    public let updatedAt: Date

    public init(baseline: PMSetSnapshot, lastReason: String, updatedAt: Date) {
        self.baseline = baseline
        self.lastReason = lastReason
        self.updatedAt = updatedAt
    }
}

public struct PMSetCommandBuilder: Sendable {
    public init() {}

    public func armPortableContinuityCommands(
        baseline: PMSetSnapshot,
        reason: String
    ) -> [[String]] {
        _ = baseline
        _ = reason
        return [
            ["-a", "disablesleep", "1"],
        ]
    }

    public func restoreCommands(from baseline: PMSetSnapshot) -> [[String]] {
        [
            ["-a", "sleep", "\(baseline.sleepMinutes)"],
            ["-a", "displaysleep", "\(baseline.displaySleepMinutes)"],
            ["-a", "disksleep", "\(baseline.diskSleepMinutes)"],
            ["-a", "disablesleep", baseline.sleepDisabled ? "1" : "0"],
        ]
    }
}

public struct RecoveryJournalStore: Sendable {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func save(_ state: PortableContinuityRecoveryState) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(state)
        try data.write(to: fileURL, options: .atomic)
    }

    public func load() throws -> PortableContinuityRecoveryState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(PortableContinuityRecoveryState.self, from: data)
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        try FileManager.default.removeItem(at: fileURL)
    }
}

public struct PMSetSnapshotParser: Sendable {
    public init() {}

    public func parse(output: String) throws -> PMSetSnapshot {
        let sleepDisabled = value(for: "SleepDisabled", in: output) == "1"
        let sleepMinutes = Int(value(for: "sleep", in: output) ?? "0") ?? 0
        let displaySleepMinutes = Int(value(for: "displaysleep", in: output) ?? "0") ?? 0
        let diskSleepMinutes = Int(value(for: "disksleep", in: output) ?? "0") ?? 0

        return PMSetSnapshot(
            sleepDisabled: sleepDisabled,
            sleepMinutes: sleepMinutes,
            displaySleepMinutes: displaySleepMinutes,
            diskSleepMinutes: diskSleepMinutes
        )
    }

    private func value(for key: String, in output: String) -> String? {
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(key) else {
                continue
            }

            let parts = trimmed.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 2 else {
                continue
            }

            return String(parts[1])
        }

        return nil
    }
}

public struct AppleScriptCommandBuilder: Sendable {
    public init() {}

    public func build(arguments: [String]) -> String {
        let command = ([#"/usr/bin/pmset"#] + arguments).map(escapeShellArgument).joined(separator: " ")
        return #"do shell script "\#(command)" with administrator privileges"#
    }

    private func escapeShellArgument(_ argument: String) -> String {
        argument.replacingOccurrences(of: "\"", with: "\\\"")
    }
}

public protocol PMSetSnapshotReading {
    func readCurrentSnapshot() throws -> PMSetSnapshot
}

public struct LivePMSetSnapshotReader: PMSetSnapshotReading {
    private let parser: PMSetSnapshotParser

    public init(parser: PMSetSnapshotParser = PMSetSnapshotParser()) {
        self.parser = parser
    }

    public func readCurrentSnapshot() throws -> PMSetSnapshot {
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]
        process.standardOutput = outputPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "AIPowerHelperSupport.LivePMSetSnapshotReader",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "pmset -g exited with status \(process.terminationStatus)"]
            )
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
        return try parser.parse(output: output)
    }
}

public protocol PMSetCommandRunning {
    func run(arguments: [String]) throws
}

public struct ProcessPMSetCommandRunner: PMSetCommandRunning {
    public init() {}

    public func run(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "AIPowerHelperSupport.PMSetCommandRunner",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "pmset exited with status \(process.terminationStatus)"]
            )
        }
    }
}

public struct ContinuityHelperEngine {
    private let commandBuilder: PMSetCommandBuilder
    private let runner: any PMSetCommandRunning
    private let journalStore: RecoveryJournalStore
    private let now: @Sendable () -> Date

    public init(
        commandBuilder: PMSetCommandBuilder,
        runner: any PMSetCommandRunning,
        journalStore: RecoveryJournalStore,
        now: @escaping @Sendable () -> Date
    ) {
        self.commandBuilder = commandBuilder
        self.runner = runner
        self.journalStore = journalStore
        self.now = now
    }

    public func armPortableContinuity(
        baseline: PMSetSnapshot,
        reason: String
    ) throws {
        for command in commandBuilder.armPortableContinuityCommands(
            baseline: baseline,
            reason: reason
        ) {
            try runner.run(arguments: command)
        }

        try journalStore.save(
            PortableContinuityRecoveryState(
                baseline: baseline,
                lastReason: reason,
                updatedAt: now()
            )
        )
    }

    public func restoreBaseline() throws {
        guard let recoveryState = try journalStore.load() else {
            return
        }

        for command in commandBuilder.restoreCommands(from: recoveryState.baseline) {
            try runner.run(arguments: command)
        }

        try journalStore.clear()
    }
}

public final class ContinuityDaemonCommandHandler {
    private let snapshotReader: any PMSetSnapshotReading
    private let engine: ContinuityHelperEngine
    private let journalStore: RecoveryJournalStore

    public init(
        snapshotReader: any PMSetSnapshotReading,
        engine: ContinuityHelperEngine,
        journalStore: RecoveryJournalStore
    ) {
        self.snapshotReader = snapshotReader
        self.engine = engine
        self.journalStore = journalStore
    }

    public func queryStatus() throws -> ContinuityDaemonReply {
        ContinuityDaemonReply(
            helperStatus: .ready,
            recoveryReason: try journalStore.load()?.lastReason
        )
    }

    public func apply(_ request: ContinuityDaemonRequest) throws -> ContinuityDaemonReply {
        switch request.action {
        case .queryStatus:
            return try queryStatus()
        case .restoreBaseline:
            return try restoreBaseline()
        case .fetchRecoveryState:
            return try fetchRecoveryState()
        case .armPortableContinuity:
            let reason = request.reason ?? "AI Continuity"
            let baseline = try snapshotReader.readCurrentSnapshot()
            try engine.armPortableContinuity(baseline: baseline, reason: reason)
            return ContinuityDaemonReply(
                helperStatus: .ready,
                recoveryReason: reason
            )
        }
    }

    public func restoreBaseline() throws -> ContinuityDaemonReply {
        try engine.restoreBaseline()
        return ContinuityDaemonReply(helperStatus: .ready)
    }

    public func fetchRecoveryState() throws -> ContinuityDaemonReply {
        ContinuityDaemonReply(
            helperStatus: .ready,
            recoveryReason: try journalStore.load()?.lastReason
        )
    }
}

public final class ContinuityDaemonXPCService: NSObject, ContinuityDaemonXPCProtocol {
    private let handler: ContinuityDaemonCommandHandler

    public init(handler: ContinuityDaemonCommandHandler) {
        self.handler = handler
        super.init()
    }

    public func queryStatus(with reply: @escaping (ContinuityDaemonReply) -> Void) {
        reply(runCatchingReply { try handler.queryStatus() })
    }

    public func apply(_ request: ContinuityDaemonRequest, with reply: @escaping (ContinuityDaemonReply) -> Void) {
        reply(runCatchingReply { try handler.apply(request) })
    }

    public func restoreBaseline(with reply: @escaping (ContinuityDaemonReply) -> Void) {
        reply(runCatchingReply { try handler.restoreBaseline() })
    }

    public func fetchRecoveryState(with reply: @escaping (ContinuityDaemonReply) -> Void) {
        reply(runCatchingReply { try handler.fetchRecoveryState() })
    }

    private func runCatchingReply(_ operation: () throws -> ContinuityDaemonReply) -> ContinuityDaemonReply {
        do {
            return try operation()
        } catch {
            return ContinuityDaemonReply(
                helperStatus: .degraded(reason: error.localizedDescription)
            )
        }
    }
}

public final class ContinuityDaemonListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let exportedObject: ContinuityDaemonXPCService

    public init(exportedObject: ContinuityDaemonXPCService) {
        self.exportedObject = exportedObject
        super.init()
    }

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: ContinuityDaemonXPCProtocol.self)
        newConnection.exportedObject = exportedObject
        newConnection.resume()
        return true
    }
}
