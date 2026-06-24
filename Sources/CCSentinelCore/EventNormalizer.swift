import Foundation

public enum EventNormalizer {
    public enum NormalizationError: Error, Equatable {
        case malformed
        case missingSessionID
    }

    public static func normalize(_ data: Data, sourceHint: SessionSource = .unknown) throws -> NormalizedEvent {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NormalizationError.malformed
        }

        guard let sessionID = object["session_id"] as? String, !sessionID.isEmpty else {
            throw NormalizationError.missingSessionID
        }

        let hookName = object["hook_event_name"] as? String ?? "Notification"
        let cwd = object["cwd"] as? String ?? ""
        let permissionMode = object["permission_mode"] as? String
        let toolName = object["tool_name"] as? String
        let toolInput = object["tool_input"]
        let toolSummary = toolInput.map { summarizeJSONObject($0) }
        let toolCommand = commandValue(from: toolInput)

        return NormalizedEvent(
            kind: mapHookName(hookName),
            sessionID: sessionID,
            source: mapSource(object["source"] as? String) ?? sourceHint,
            cwd: cwd,
            permissionMode: permissionMode,
            toolName: toolName,
            toolSummary: toolSummary,
            toolCommand: toolCommand,
            occurredAt: Date()
        )
    }

    private static func mapHookName(_ name: String) -> NormalizedEventKind {
        switch name {
        case "SessionStart":
            return .sessionStart
        case "PermissionRequest":
            return .permissionRequest
        case "PostToolUse":
            return .postToolUse
        case "PostToolUseFailure":
            return .postToolUseFailure
        case "Stop":
            return .stop
        case "SessionEnd":
            return .sessionEnd
        case "WrapperProcessStart":
            return .wrapperProcessStart
        case "WrapperProcessEnd":
            return .wrapperProcessEnd
        default:
            return .notification
        }
    }

    private static func mapSource(_ value: String?) -> SessionSource? {
        switch value {
        case "cli":
            return .cli
        case "vscode":
            return .vscode
        case "unknown":
            return .unknown
        default:
            return nil
        }
    }

    private static func summarizeJSONObject(_ value: Any) -> String {
        if let dict = value as? [String: Any] {
            return dict.keys.sorted().compactMap { key in
                guard let raw = dict[key] else { return nil }
                return "\(key)=\(Redactor.safeSummary(String(describing: raw)))"
            }.joined(separator: " ")
        }
        return Redactor.safeSummary(String(describing: value))
    }

    private static func commandValue(from value: Any?) -> String? {
        guard let dict = value as? [String: Any] else {
            return value.map { String(describing: $0) }
        }
        for key in ["command", "file_path", "path", "notebook_path"] {
            if let raw = dict[key] as? String, !raw.isEmpty {
                return raw
            }
        }
        return nil
    }
}
