import Foundation

public struct SessionStore: Codable, Equatable, Sendable {
    public private(set) var sessions: [ClaudeSession]

    public init(sessions: [ClaudeSession] = []) {
        self.sessions = sessions
    }

    public var aggregateStatus: AggregateStatus {
        AggregateStatus.resolve(sessions: sessions)
    }

    public mutating func apply(_ event: NormalizedEvent) {
        let existingIndex = sessions.firstIndex { $0.id == event.sessionID }
        var session = existingIndex.map { sessions[$0] } ?? ClaudeSession(
            id: event.sessionID,
            source: event.source,
            cwd: event.cwd,
            status: .running
        )

        session.source = event.source == .unknown ? session.source : event.source
        session.cwd = event.cwd.isEmpty ? session.cwd : event.cwd
        session.permissionMode = event.permissionMode ?? session.permissionMode
        session.lastToolName = event.toolName ?? session.lastToolName
        session.lastToolSummary = event.toolSummary ?? session.lastToolSummary
        session.lastEventAt = event.occurredAt

        switch event.kind {
        case .permissionRequest, .notification:
            session.status = .waitingApproval
            session.waitingSince = event.occurredAt
            session.approvalRequest = ApprovalRequest(
                toolName: event.toolName ?? "Unknown",
                summary: event.toolSummary ?? "",
                requestedAt: event.occurredAt
            )
        case .postToolUse, .postToolUseFailure:
            session.status = .running
            session.waitingSince = nil
            session.approvalRequest = nil
        case .stop:
            session.status = .idle
        case .sessionEnd, .wrapperProcessEnd:
            session.status = .ended
        case .sessionStart, .wrapperProcessStart:
            session.status = .running
        }

        if let existingIndex {
            sessions[existingIndex] = session
        } else {
            sessions.append(session)
        }
    }
}
