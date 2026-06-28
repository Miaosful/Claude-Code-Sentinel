import Foundation

public struct SessionStore: Codable, Equatable, Sendable {
    public static let defaultStaleTimeout: TimeInterval = 60
    public static let pendingApprovalRevivalTimeout: TimeInterval = 30 * 60

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
        session.claudePID = event.claudePID ?? session.claudePID
        session.permissionMode = event.permissionMode ?? session.permissionMode
        session.lastToolName = event.toolName ?? session.lastToolName
        session.lastToolSummary = event.toolSummary ?? session.lastToolSummary
        session.lastEventAt = event.occurredAt

        switch event.kind {
        case .permissionRequest:
            session.status = .waitingApproval
            session.waitingSince = event.occurredAt
            session.approvalRequest = ApprovalRequest(
                toolName: event.toolName ?? "Unknown",
                summary: event.toolSummary ?? "",
                requestedAt: event.occurredAt
            )
        case .notification:
            session.status = .waitingApproval
            if session.approvalRequest == nil {
                session.waitingSince = event.occurredAt
                session.approvalRequest = ApprovalRequest(
                    toolName: event.toolName ?? "Unknown",
                    summary: event.toolSummary ?? "",
                    requestedAt: event.occurredAt
                )
            } else if session.waitingSince == nil {
                session.waitingSince = event.occurredAt
            }
        case .sessionStart, .preToolUse, .postToolUse, .postToolUseFailure, .permissionDenied, .configChange, .wrapperProcessStart:
            session.status = .running
            session.waitingSince = nil
            session.approvalRequest = nil
        case .stop:
            session.status = .idle
            session.waitingSince = nil
            session.approvalRequest = nil
        case .stopFailure:
            session.status = .error
            session.waitingSince = nil
            session.approvalRequest = nil
        case .sessionEnd, .wrapperProcessEnd:
            session.status = .ended
            session.waitingSince = nil
            session.approvalRequest = nil
        }

        if let existingIndex {
            sessions[existingIndex] = session
        } else {
            sessions.append(session)
        }
    }

    public mutating func markStale(
        now: Date = Date(),
        timeout: TimeInterval,
        pendingApprovalRevivalTimeout: TimeInterval = Self.pendingApprovalRevivalTimeout,
        activeClaudeProcessIDs: Set<Int32> = []
    ) {
        sessions = sessions.map { session in
            let age = now.timeIntervalSince(session.lastEventAt)
            let sessionProcessIsActive = session.claudePID.map { activeClaudeProcessIDs.contains($0) } ?? false
            let legacyProcessProtectionApplies = session.claudePID == nil &&
                !activeClaudeProcessIDs.isEmpty &&
                age <= pendingApprovalRevivalTimeout

            if
                session.status == .stale,
                session.approvalRequest != nil,
                sessionProcessIsActive || legacyProcessProtectionApplies,
                age <= pendingApprovalRevivalTimeout
            {
                var revivedSession = session
                revivedSession.status = .waitingApproval
                return revivedSession
            }

            guard session.status == .running || session.status == .waitingApproval || session.status == .idle else {
                return session
            }
            if session.status == .waitingApproval && (sessionProcessIsActive || legacyProcessProtectionApplies) {
                return session
            }
            guard age > timeout else {
                return session
            }
            var staleSession = session
            staleSession.status = .stale
            return staleSession
        }
    }

    public mutating func clearInactiveSessions(
        now: Date = Date(),
        waitingApprovalTimeout: TimeInterval = Self.pendingApprovalRevivalTimeout
    ) {
        sessions = sessions.filter { session in
            switch session.status {
            case .stale, .ended:
                return false
            case .waitingApproval:
                return now.timeIntervalSince(session.lastEventAt) <= waitingApprovalTimeout
            case .running, .idle, .error:
                return true
            }
        }
    }

    public func includingProcessFallback(_ snapshot: ClaudeProcessSnapshot) -> SessionStore {
        let activeHookStore = SessionStore(sessions: activeHookSessions).inferringProcessMetadata(from: snapshot)
        guard !activeHookStore.sessions.isEmpty else {
            return SessionStore(sessions: snapshot.processSessions)
        }

        return activeHookStore
    }

    private func inferringProcessMetadata(from snapshot: ClaudeProcessSnapshot) -> SessionStore {
        let processesByPID = Dictionary(uniqueKeysWithValues: snapshot.processes.map { ($0.pid, $0) })
        return SessionStore(sessions: sessions.map { session in
            guard
                session.source == .unknown,
                let pid = session.claudePID,
                let process = processesByPID[pid]
            else {
                return session
            }

            var inferredSession = session
            inferredSession.source = process.source
            return inferredSession
        })
    }

    private var activeHookSessions: [ClaudeSession] {
        sessions.filter { session in
            switch session.status {
            case .running, .waitingApproval:
                return true
            case .idle, .ended, .stale, .error:
                return false
            }
        }
    }
}

private extension ClaudeProcessSnapshot {
    var processSessions: [ClaudeSession] {
        visibleFallbackProcesses.map { process in
            ClaudeSession(
                id: "process-\(process.pid)",
                source: process.source,
                cwd: "",
                status: .running,
                claudePID: process.pid,
                lastToolName: "Process",
                lastToolSummary: process.command,
                lastEventAt: scannedAt
            )
        }
    }

    private var visibleFallbackProcesses: [ClaudeProcess] {
        processes
            .reduce(into: [String: ClaudeProcess]()) { grouped, process in
                let key: String
                switch process.source {
                case .vscode:
                    key = "vscode-\(process.parentPID)"
                case .cli, .unknown:
                    key = "process-\(process.pid)"
                }

                if let existing = grouped[key], existing.pid < process.pid {
                    return
                }
                grouped[key] = process
            }
            .values
            .sorted { lhs, rhs in
                lhs.pid < rhs.pid
            }
    }
}
