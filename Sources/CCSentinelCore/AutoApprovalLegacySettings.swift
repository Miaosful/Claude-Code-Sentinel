import Foundation

public struct AutoApprovalSettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var policy: ApprovalPolicy
    public var workspace: String

    public static let `default` = AutoApprovalSettings(
        enabled: false,
        policy: .default,
        workspace: ""
    )

    public init(enabled: Bool, policy: ApprovalPolicy, workspace: String) {
        self.enabled = enabled
        self.policy = policy
        self.workspace = workspace
    }

    public var config: AutoApprovalConfig {
        AutoApprovalConfig(
            schemaVersion: 1,
            enabled: enabled,
            workspace: workspace,
            profile: nil,
            rules: policy.rules(workspace: workspace)
        )
    }

    public static func from(config: AutoApprovalConfig) -> AutoApprovalSettings {
        AutoApprovalSettings(
            enabled: config.enabled,
            policy: ApprovalPolicy.from(rules: config.rules),
            workspace: config.workspace
        )
    }
}

public enum AutoApprovalSettingsPersistence {
    public static func save(_ settings: AutoApprovalSettings, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: url, options: .atomic)
    }

    public static func load(from url: URL) throws -> AutoApprovalSettings {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .default
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AutoApprovalSettings.self, from: data)
    }
}
