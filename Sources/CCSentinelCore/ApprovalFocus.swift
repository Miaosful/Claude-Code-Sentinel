import Foundation

public struct ApprovalFocus: Equatable, Sendable {
    public var sessionID: String
    public var source: SessionSource
    public var cwd: String
    public var toolName: String
    public var summary: String
    public var requestedAt: Date

    public init(
        sessionID: String,
        source: SessionSource,
        cwd: String,
        toolName: String,
        summary: String,
        requestedAt: Date
    ) {
        self.sessionID = sessionID
        self.source = source
        self.cwd = cwd
        self.toolName = toolName
        self.summary = summary
        self.requestedAt = requestedAt
    }

    public static func resolve(store: SessionStore) -> ApprovalFocus? {
        store.sessions
            .filter { $0.status == .waitingApproval && $0.approvalRequest != nil }
            .sorted { lhs, rhs in
                let lhsDate = lhs.approvalRequest?.requestedAt ?? lhs.waitingSince ?? lhs.lastEventAt
                let rhsDate = rhs.approvalRequest?.requestedAt ?? rhs.waitingSince ?? rhs.lastEventAt
                if lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }
                return lhs.id < rhs.id
            }
            .first
            .flatMap { session in
                guard let request = session.approvalRequest else {
                    return nil
                }
                return ApprovalFocus(
                    sessionID: session.id,
                    source: session.source,
                    cwd: session.cwd,
                    toolName: request.toolName,
                    summary: request.summary,
                    requestedAt: request.requestedAt
                )
            }
    }
}
