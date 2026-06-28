public enum CCSentinelVersion {
    public static let current = "0.1.0"
}

import Foundation

public enum NormalizedEventKind: String, Codable, Equatable, Sendable {
    case sessionStart
    case preToolUse
    case permissionRequest
    case permissionDenied
    case postToolUse
    case postToolUseFailure
    case stop
    case stopFailure
    case sessionEnd
    case configChange
    case notification
    case wrapperProcessStart
    case wrapperProcessEnd
}

public struct NormalizedEvent: Codable, Equatable, Sendable {
    public var kind: NormalizedEventKind
    public var sessionID: String
    public var source: SessionSource
    public var cwd: String
    public var claudePID: Int32?
    public var permissionMode: String?
    public var toolName: String?
    public var toolSummary: String?
    public var toolCommand: String?
    public var occurredAt: Date

    public init(
        kind: NormalizedEventKind,
        sessionID: String,
        source: SessionSource,
        cwd: String,
        claudePID: Int32? = nil,
        permissionMode: String? = nil,
        toolName: String? = nil,
        toolSummary: String? = nil,
        toolCommand: String? = nil,
        occurredAt: Date = Date()
    ) {
        self.kind = kind
        self.sessionID = sessionID
        self.source = source
        self.cwd = cwd
        self.claudePID = claudePID
        self.permissionMode = permissionMode
        self.toolName = toolName
        self.toolSummary = toolSummary
        self.toolCommand = toolCommand
        self.occurredAt = occurredAt
    }
}
