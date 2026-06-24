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
        let toolSummary = object["tool_input"].map { summarizeJSONObject($0) }

        return NormalizedEvent(
            kind: mapHookName(hookName),
            sessionID: sessionID,
            source: sourceHint,
            cwd: cwd,
            permissionMode: permissionMode,
            toolName: toolName,
            toolSummary: toolSummary,
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
        default:
            return .notification
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
}
