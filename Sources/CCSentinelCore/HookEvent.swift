public enum CCSentinelVersion {
    public static let current = "0.1.0"
}

import Foundation

public enum NormalizedEventKind: String, Codable, Equatable, Sendable {
    case sessionStart
    case permissionRequest
    case postToolUse
    case postToolUseFailure
    case stop
    case sessionEnd
    case notification
    case wrapperProcessStart
    case wrapperProcessEnd
}

public struct NormalizedEvent: Codable, Equatable, Sendable {
    public var kind: NormalizedEventKind
    public var sessionID: String
    public var source: SessionSource
    public var cwd: String
    public var permissionMode: String?
    public var toolName: String?
    public var toolSummary: String?
    public var occurredAt: Date

    public init(
        kind: NormalizedEventKind,
        sessionID: String,
        source: SessionSource,
        cwd: String,
        permissionMode: String? = nil,
        toolName: String? = nil,
        toolSummary: String? = nil,
        occurredAt: Date = Date()
    ) {
        self.kind = kind
        self.sessionID = sessionID
        self.source = source
        self.cwd = cwd
        self.permissionMode = permissionMode
        self.toolName = toolName
        self.toolSummary = toolSummary
        self.occurredAt = occurredAt
    }
}
