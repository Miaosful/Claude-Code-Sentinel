import Foundation

public enum CCSentinelPaths {
    public static func applicationSupportDirectory(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let override = environment["CC_SENTINEL_APP_SUPPORT_DIR"] {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let applicationSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return applicationSupport.appendingPathComponent("CC Sentinel", isDirectory: true)
    }

    public static func storeURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        environment["CC_SENTINEL_STORE_PATH"]
            .map { URL(fileURLWithPath: $0) } ??
            applicationSupportDirectory(environment: environment).appendingPathComponent("session-store.json")
    }

    public static func fallbackURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        environment["CC_SENTINEL_FALLBACK_PATH"]
            .map { URL(fileURLWithPath: $0) } ??
            applicationSupportDirectory(environment: environment).appendingPathComponent("events-fallback.jsonl")
    }

    public static func autoApprovalConfigURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        environment["CC_SENTINEL_AUTO_APPROVAL_CONFIG_PATH"]
            .map { URL(fileURLWithPath: $0) } ??
            applicationSupportDirectory(environment: environment).appendingPathComponent("auto-approval-config.json")
    }

    public static func autoApprovalSettingsURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        environment["CC_SENTINEL_AUTO_APPROVAL_SETTINGS_PATH"]
            .map { URL(fileURLWithPath: $0) } ??
            applicationSupportDirectory(environment: environment).appendingPathComponent("auto-approval-settings.json")
    }

    public static func autoApprovalStatsURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        environment["CC_SENTINEL_AUTO_APPROVAL_STATS_PATH"]
            .map { URL(fileURLWithPath: $0) } ??
            applicationSupportDirectory(environment: environment).appendingPathComponent("auto-approval-stats.json")
    }

    public static func pendingApprovalsDirectory(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        environment["CC_SENTINEL_PENDING_APPROVALS_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) } ??
            applicationSupportDirectory(environment: environment).appendingPathComponent("pending-approvals", isDirectory: true)
    }

    public static func approvalDecisionsDirectory(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        environment["CC_SENTINEL_APPROVAL_DECISIONS_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) } ??
            applicationSupportDirectory(environment: environment).appendingPathComponent("approval-decisions", isDirectory: true)
    }
}
