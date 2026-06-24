import Foundation

public struct HookSettingsPreview: Equatable, Sendable {
    public var previewJSON: String

    public init(previewJSON: String) {
        self.previewJSON = previewJSON
    }
}

public enum HookSettingsInstaller {
    public enum InstallerError: Error, Equatable {
        case invalidSettingsJSON
        case cannotSerializeSettings
    }

    private static let managedMarker = "cc-sentinel-managed"
    private static let hookEvents = [
        "SessionStart",
        "PermissionRequest",
        "PostToolUse",
        "PostToolUseFailure",
        "Stop",
        "SessionEnd",
        "Notification"
    ]

    public static func previewInstall(
        existingSettingsJSON: String,
        hookBinaryPath: String
    ) throws -> HookSettingsPreview {
        var root = try parseRoot(existingSettingsJSON)
        var hooks = root["hooks"] as? [String: Any] ?? [:]

        for event in hookEvents {
            var entries = hooks[event] as? [[String: Any]] ?? []
            entries = entries.filter { entry in
                (entry[managedMarker] as? Bool) != true
            }
            entries.append([
                "command": hookBinaryPath,
                managedMarker: true
            ])
            hooks[event] = entries
        }

        root["hooks"] = hooks
        return HookSettingsPreview(previewJSON: try serialize(root))
    }

    public static func previewUninstall(existingSettingsJSON: String) throws -> HookSettingsPreview {
        var root = try parseRoot(existingSettingsJSON)
        var hooks = root["hooks"] as? [String: Any] ?? [:]

        for (event, value) in hooks {
            guard let entries = value as? [[String: Any]] else {
                continue
            }
            let unmanagedEntries = entries.filter { entry in
                (entry[managedMarker] as? Bool) != true
            }
            if unmanagedEntries.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = unmanagedEntries
            }
        }

        root["hooks"] = hooks
        return HookSettingsPreview(previewJSON: try serialize(root))
    }

    public static func hasManagedHooks(existingSettingsJSON: String) throws -> Bool {
        let root = try parseRoot(existingSettingsJSON)
        let hooks = root["hooks"] as? [String: Any] ?? [:]

        for event in hookEvents {
            guard let entries = hooks[event] as? [[String: Any]] else {
                continue
            }
            if entries.contains(where: { ($0[managedMarker] as? Bool) == true }) {
                return true
            }
        }
        return false
    }

    public static func hasManagedHooks(settingsURL: URL) throws -> Bool {
        let existing = try readSettings(from: settingsURL)
        return try hasManagedHooks(existingSettingsJSON: existing)
    }

    @discardableResult
    public static func applyInstall(
        settingsURL: URL,
        hookBinaryPath: String,
        timestamp: String? = nil
    ) throws -> URL {
        let existing = try readSettings(from: settingsURL)
        let backupURL = try writeBackup(existing, settingsURL: settingsURL, timestamp: timestamp ?? defaultTimestamp())
        let preview = try previewInstall(existingSettingsJSON: existing, hookBinaryPath: hookBinaryPath)
        try writeSettings(preview.previewJSON, to: settingsURL)
        return backupURL
    }

    @discardableResult
    public static func applyUninstall(
        settingsURL: URL,
        timestamp: String? = nil
    ) throws -> URL {
        let existing = try readSettings(from: settingsURL)
        let backupURL = try writeBackup(existing, settingsURL: settingsURL, timestamp: timestamp ?? defaultTimestamp())
        let preview = try previewUninstall(existingSettingsJSON: existing)
        try writeSettings(preview.previewJSON, to: settingsURL)
        return backupURL
    }

    private static func parseRoot(_ json: String) throws -> [String: Any] {
        if json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [:]
        }
        guard
            let data = json.data(using: .utf8),
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw InstallerError.invalidSettingsJSON
        }
        return root
    }

    private static func serialize(_ object: [String: Any]) throws -> String {
        guard JSONSerialization.isValidJSONObject(object) else {
            throw InstallerError.cannotSerializeSettings
        }
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        guard let json = String(data: data, encoding: .utf8) else {
            throw InstallerError.cannotSerializeSettings
        }
        return json
    }

    private static func readSettings(from url: URL) throws -> String {
        if FileManager.default.fileExists(atPath: url.path) {
            return try String(contentsOf: url, encoding: .utf8)
        }
        return "{}"
    }

    private static func writeSettings(_ json: String, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try json.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeBackup(_ existing: String, settingsURL: URL, timestamp: String) throws -> URL {
        let backupURL = URL(fileURLWithPath: settingsURL.path + ".cc-sentinel-backup-\(timestamp)")
        let directory = backupURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try existing.write(to: backupURL, atomically: true, encoding: .utf8)
        return backupURL
    }

    private static func defaultTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}
