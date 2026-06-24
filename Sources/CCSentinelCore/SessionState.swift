import Foundation

public enum SessionSource: String, Codable, Equatable, Sendable {
    case cli
    case vscode
    case unknown
}

public enum SessionStatus: String, Codable, Equatable, Sendable {
    case running
    case waitingApproval = "waiting_approval"
    case idle
    case ended
    case stale
    case error
}

public struct ApprovalRequest: Codable, Equatable, Sendable {
    public var toolName: String
    public var summary: String
    public var requestedAt: Date

    public init(toolName: String, summary: String, requestedAt: Date) {
        self.toolName = toolName
        self.summary = summary
        self.requestedAt = requestedAt
    }
}

public struct ClaudeSession: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var source: SessionSource
    public var cwd: String
    public var status: SessionStatus
    public var permissionMode: String?
    public var lastToolName: String?
    public var lastToolSummary: String?
    public var lastEventAt: Date
    public var waitingSince: Date?
    public var approvalRequest: ApprovalRequest?

    public init(
        id: String,
        source: SessionSource,
        cwd: String,
        status: SessionStatus,
        permissionMode: String? = nil,
        lastToolName: String? = nil,
        lastToolSummary: String? = nil,
        lastEventAt: Date = Date(timeIntervalSince1970: 0),
        waitingSince: Date? = nil,
        approvalRequest: ApprovalRequest? = nil
    ) {
        self.id = id
        self.source = source
        self.cwd = cwd
        self.status = status
        self.permissionMode = permissionMode
        self.lastToolName = lastToolName
        self.lastToolSummary = lastToolSummary
        self.lastEventAt = lastEventAt
        self.waitingSince = waitingSince
        self.approvalRequest = approvalRequest
    }
}

public enum AggregateStatus: String, Equatable, Sendable {
    case idle
    case running
    case waitingApproval = "waiting_approval"
    case degraded

    public static func resolve(sessions: [ClaudeSession]) -> AggregateStatus {
        if sessions.contains(where: { $0.status == .waitingApproval }) {
            return .waitingApproval
        }
        if sessions.contains(where: { $0.status == .running }) {
            return .running
        }
        if sessions.contains(where: { $0.status == .stale || $0.status == .error }) {
            return .degraded
        }
        return .idle
    }
}
