import Foundation

#if canImport(ServiceManagement)
import ServiceManagement
#endif

public enum LaunchAtLoginError: Error, Equatable {
    case unavailable(String)
    case requiresApproval

    public var userMessage: String {
        switch self {
        case let .unavailable(message):
            return message
        case .requiresApproval:
            return "Launch at login requires approval in System Settings."
        }
    }
}

enum LaunchAtLoginStatus {
    case notRegistered
    case enabled
    case requiresApproval
    case other
}

enum LaunchAtLoginDecision {
    case returnWithoutMutation
    case register
    case unregister
}

public enum LaunchAtLoginService {
    public static let unavailableMessage = "Launch at login is unavailable in this build."

    public static func setEnabled(_ enabled: Bool) throws {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            switch try decision(forEnabled: enabled, currentStatus: status(from: SMAppService.mainApp.status)) {
            case .returnWithoutMutation:
                return
            case .register:
                try SMAppService.mainApp.register()
            case .unregister:
                try SMAppService.mainApp.unregister()
            }
        } else {
            throw LaunchAtLoginError.unavailable(Self.unavailableMessage)
        }
        #else
        throw LaunchAtLoginError.unavailable(Self.unavailableMessage)
        #endif
    }

    static func decision(forEnabled enabled: Bool, currentStatus: LaunchAtLoginStatus) throws -> LaunchAtLoginDecision {
        if enabled {
            switch currentStatus {
            case .enabled:
                return .returnWithoutMutation
            case .requiresApproval:
                throw LaunchAtLoginError.requiresApproval
            case .notRegistered, .other:
                return .register
            }
        }

        switch currentStatus {
        case .notRegistered:
            return .returnWithoutMutation
        case .enabled, .requiresApproval, .other:
            return .unregister
        }
    }

    #if canImport(ServiceManagement)
    @available(macOS 13.0, *)
    private static func status(from serviceStatus: SMAppService.Status) -> LaunchAtLoginStatus {
        switch serviceStatus {
        case .notRegistered:
            return .notRegistered
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .other
        @unknown default:
            return .other
        }
    }
    #endif
}
