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
            let alreadyInstalled = entries.contains { entry in
                (entry[managedMarker] as? Bool) == true &&
                    (entry["command"] as? String) == hookBinaryPath
            }
            if !alreadyInstalled {
                entries.append([
                    "command": hookBinaryPath,
                    managedMarker: true
                ])
            }
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
            options: [.prettyPrinted, .sortedKeys]
        )
        guard let json = String(data: data, encoding: .utf8) else {
            throw InstallerError.cannotSerializeSettings
        }
        return json
    }
}
