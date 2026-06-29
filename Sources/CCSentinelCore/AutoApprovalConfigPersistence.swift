import Foundation

public enum AutoApprovalConfigError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case emptyRuleID
    case emptyRuleTool
    case emptyCommandMatch(ruleID: String)

    public var userFacingDescription: String {
        switch self {
        case let .unsupportedSchemaVersion(version):
            return "Unsupported auto-approval config schemaVersion \(version). This version supports schemaVersion 1."
        case .emptyRuleID:
            return "Every auto-approval rule must have a non-empty id."
        case .emptyRuleTool:
            return "Every auto-approval rule must have a non-empty tool."
        case let .emptyCommandMatch(ruleID):
            return "Rule \(ruleID) must define at least one commandContains or commandPrefixes matcher."
        }
    }
}

public enum AutoApprovalConfigPersistence {
    public static func decode(_ data: Data) throws -> AutoApprovalConfig {
        let config = try JSONDecoder().decode(AutoApprovalConfig.self, from: data)
        try validate(config)
        return config
    }

    public static func save(_ config: AutoApprovalConfig, to url: URL) throws {
        try validate(config)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: url, options: .atomic)
    }

    public static func load(from url: URL) throws -> AutoApprovalConfig {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .default
        }

        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    @discardableResult
    public static func replaceActiveConfig(
        with sourceURL: URL,
        activeURL: URL,
        now: Date = Date()
    ) throws -> URL {
        let imported = try load(from: sourceURL)
        let directory = activeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let backupURL = directory
            .appendingPathComponent(activeURL.lastPathComponent + ".backup-\(backupTimestamp(for: now))")

        if FileManager.default.fileExists(atPath: activeURL.path) {
            try FileManager.default.copyItem(at: activeURL, to: backupURL)
        } else {
            try save(.default, to: backupURL)
        }
        try save(imported, to: activeURL)
        return backupURL
    }

    public static func validate(_ config: AutoApprovalConfig) throws {
        guard config.schemaVersion == 1 else {
            throw AutoApprovalConfigError.unsupportedSchemaVersion(config.schemaVersion)
        }
        for rule in config.rules {
            if rule.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw AutoApprovalConfigError.emptyRuleID
            }
            if rule.tool.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw AutoApprovalConfigError.emptyRuleTool
            }
            if let match = rule.match, match.commandContains.isEmpty, match.commandPrefixes.isEmpty {
                throw AutoApprovalConfigError.emptyCommandMatch(ruleID: rule.id)
            }
        }
    }

    private static func backupTimestamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}

public enum AutoApprovalConfigMigration {
    public static func loadMigrating(configURL: URL, legacySettingsURL: URL) throws -> AutoApprovalConfig {
        if FileManager.default.fileExists(atPath: configURL.path) {
            return try AutoApprovalConfigPersistence.load(from: configURL)
        }

        guard FileManager.default.fileExists(atPath: legacySettingsURL.path) else {
            return .default
        }

        let legacy = try AutoApprovalSettingsPersistence.load(from: legacySettingsURL)
        let config = legacy.config
        try AutoApprovalConfigPersistence.save(config, to: configURL)
        return config
    }
}
