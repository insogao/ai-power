import AIPowerCore
import Foundation

public enum ContinuityXPC {
    public static let machServiceName = "com.aipower.continuity-helper"
    public static let launchDaemonPlistName = "com.aipower.continuity-helper.plist"
    public static let helperExecutableName = "AIPowerContinuityHelper"
    public static let embeddedHelperRelativePath = "Contents/MacOS/AIPowerContinuityHelper"
    public static let associatedAppBundleIdentifier = "com.aipower.app"
}

public enum ContinuityDaemonAction: String, Sendable {
    case queryStatus
    case armPortableContinuity
    case restoreBaseline
    case fetchRecoveryState
}

@objcMembers
public final class ContinuityDaemonRequest: NSObject, NSSecureCoding {
    public static var supportsSecureCoding: Bool { true }

    public let actionRawValue: String
    public let reason: String?

    public var action: ContinuityDaemonAction {
        ContinuityDaemonAction(rawValue: actionRawValue) ?? .queryStatus
    }

    public init(action: ContinuityDaemonAction, reason: String? = nil) {
        self.actionRawValue = action.rawValue
        self.reason = reason
        super.init()
    }

    public required init?(coder: NSCoder) {
        guard let actionRawValue = coder.decodeObject(of: NSString.self, forKey: "actionRawValue") as? String else {
            return nil
        }

        self.actionRawValue = actionRawValue
        self.reason = coder.decodeObject(of: NSString.self, forKey: "reason") as? String
        super.init()
    }

    public func encode(with coder: NSCoder) {
        coder.encode(actionRawValue as NSString, forKey: "actionRawValue")
        if let reason {
            coder.encode(reason as NSString, forKey: "reason")
        }
    }
}

@objcMembers
public final class ContinuityDaemonReply: NSObject, NSSecureCoding {
    public static var supportsSecureCoding: Bool { true }

    public let helperStatusKindRawValue: String
    public let helperStatusReason: String?
    public let recoveryReason: String?

    public var helperStatus: HelperStatus {
        switch helperStatusKindRawValue {
        case "notInstalled":
            return .notInstalled
        case "requiresApproval":
            return .requiresApproval
        case "ready":
            return .ready
        case "degraded":
            return .degraded(reason: helperStatusReason ?? "Unknown error")
        default:
            return .degraded(reason: "Unknown helper reply")
        }
    }

    public init(helperStatus: HelperStatus, recoveryReason: String? = nil) {
        switch helperStatus {
        case .notInstalled:
            self.helperStatusKindRawValue = "notInstalled"
            self.helperStatusReason = nil
        case .requiresApproval:
            self.helperStatusKindRawValue = "requiresApproval"
            self.helperStatusReason = nil
        case .ready:
            self.helperStatusKindRawValue = "ready"
            self.helperStatusReason = nil
        case let .degraded(reason):
            self.helperStatusKindRawValue = "degraded"
            self.helperStatusReason = reason
        }

        self.recoveryReason = recoveryReason
        super.init()
    }

    public required init?(coder: NSCoder) {
        guard let helperStatusKindRawValue = coder.decodeObject(
            of: NSString.self,
            forKey: "helperStatusKindRawValue"
        ) as? String else {
            return nil
        }

        self.helperStatusKindRawValue = helperStatusKindRawValue
        self.helperStatusReason = coder.decodeObject(of: NSString.self, forKey: "helperStatusReason") as? String
        self.recoveryReason = coder.decodeObject(of: NSString.self, forKey: "recoveryReason") as? String
        super.init()
    }

    public func encode(with coder: NSCoder) {
        coder.encode(helperStatusKindRawValue as NSString, forKey: "helperStatusKindRawValue")
        if let helperStatusReason {
            coder.encode(helperStatusReason as NSString, forKey: "helperStatusReason")
        }
        if let recoveryReason {
            coder.encode(recoveryReason as NSString, forKey: "recoveryReason")
        }
    }
}

@objc public protocol ContinuityDaemonXPCProtocol {
    func queryStatus(with reply: @escaping (ContinuityDaemonReply) -> Void)
    func apply(_ request: ContinuityDaemonRequest, with reply: @escaping (ContinuityDaemonReply) -> Void)
    func restoreBaseline(with reply: @escaping (ContinuityDaemonReply) -> Void)
    func fetchRecoveryState(with reply: @escaping (ContinuityDaemonReply) -> Void)
}
