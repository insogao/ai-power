import AIPowerHelperSupport
import AIPowerIPC
import Foundation

enum HelperCommand: String {
    case arm
    case restore
    case status
    case serve
}

@main
struct AIPowerContinuityHelperMain {
    static func main() throws {
        let arguments = CommandLine.arguments
        guard let command = resolvedCommand(from: arguments)
        else {
            if arguments.count <= 1 || ProcessInfo.processInfo.environment["AIPOWER_XPC_MODE"] == "1" {
                try serveXPC()
                return
            }

            FileHandle.standardError.write(Data("usage: AIPowerContinuityHelper <arm|restore|status|serve>\n".utf8))
            return
        }

        let journal = RecoveryJournalStore(fileURL: recoveryStateURL())
        let handler = makeHandler(journal: journal)

        switch command {
        case .arm:
            _ = try handler.apply(
                ContinuityDaemonRequest(
                    action: .armPortableContinuity,
                    reason: resolvedArmReason(from: arguments) ?? "AI Continuity"
                )
            )
            print("armed")

        case .restore:
            _ = try handler.restoreBaseline()
            print("restored")

        case .status:
            if let reason = try handler.fetchRecoveryState().recoveryReason {
                print("armed: \(reason)")
            } else {
                print("idle")
            }

        case .serve:
            try serveXPC()
        }
    }

    private static func resolvedCommand(from arguments: [String]) -> HelperCommand? {
        if arguments.count >= 2, let command = HelperCommand(rawValue: arguments[1]) {
            return command
        }

        return nil
    }

    private static func resolvedArmReason(from arguments: [String]) -> String? {
        if let armIndex = arguments.firstIndex(where: { $0 == HelperCommand.arm.rawValue }),
           arguments.indices.contains(armIndex + 1) {
            return arguments[armIndex + 1]
        }

        return nil
    }

    private static func makeHandler(journal: RecoveryJournalStore) -> ContinuityDaemonCommandHandler {
        ContinuityDaemonCommandHandler(
            snapshotReader: LivePMSetSnapshotReader(),
            engine: ContinuityHelperEngine(
                commandBuilder: PMSetCommandBuilder(),
                runner: ProcessPMSetCommandRunner(),
                journalStore: journal,
                now: Date.init
            ),
            journalStore: journal
        )
    }

    private static func recoveryStateURL() -> URL {
        if let applicationSupportURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .localDomainMask)
            .first {
            return applicationSupportURL
                .appendingPathComponent("AI Power Manager", isDirectory: true)
                .appendingPathComponent("portable-continuity.json")
        }

        return URL(fileURLWithPath: "/tmp/com.aipower.continuity-helper.json")
    }

    private static func serveXPC() throws {
        let journal = RecoveryJournalStore(fileURL: recoveryStateURL())
        let service = ContinuityDaemonXPCService(handler: makeHandler(journal: journal))
        let delegate = ContinuityDaemonListenerDelegate(exportedObject: service)
        let listener = NSXPCListener(machServiceName: ContinuityXPC.machServiceName)
        listener.delegate = delegate
        listener.resume()
        RunLoop.current.run()
    }
}
