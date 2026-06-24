import Foundation

public enum SessionStoreDump {
    public static func render(store: SessionStore, now: Date = Date()) -> String {
        var lines = [
            "aggregate_status: \(store.aggregateStatus.rawValue)",
            "session_count: \(store.sessions.count)"
        ]

        if store.sessions.isEmpty {
            lines.append("sessions: []")
            return lines.joined(separator: "\n")
        }

        lines.append("sessions:")
        for session in store.sessions.sorted(by: sortSessions) {
            lines.append("- id: \(session.id)")
            lines.append("  source: \(session.source.rawValue)")
            lines.append("  status: \(session.status.rawValue)")
            lines.append("  cwd: \(session.cwd)")
            lines.append("  last_event_at: \(format(session.lastEventAt))")

            if let tool = session.lastToolName, !tool.isEmpty {
                lines.append("  tool: \(tool)")
            }
            if let summary = session.lastToolSummary, !summary.isEmpty {
                lines.append("  summary: \(summary)")
            }
            if let waitingSince = session.waitingSince {
                lines.append("  waiting_since: \(format(waitingSince))")
            }
            if let permissionMode = session.permissionMode, !permissionMode.isEmpty {
                lines.append("  permission_mode: \(permissionMode)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func sortSessions(_ lhs: ClaudeSession, _ rhs: ClaudeSession) -> Bool {
        if lhs.status != rhs.status {
            return priority(lhs.status) < priority(rhs.status)
        }
        if lhs.lastEventAt != rhs.lastEventAt {
            return lhs.lastEventAt > rhs.lastEventAt
        }
        return lhs.id < rhs.id
    }

    private static func priority(_ status: SessionStatus) -> Int {
        switch status {
        case .waitingApproval:
            return 0
        case .running:
            return 1
        case .stale, .error:
            return 2
        case .idle:
            return 3
        case .ended:
            return 4
        }
    }

    private static func format(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
