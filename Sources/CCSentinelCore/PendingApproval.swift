import Foundation

public struct SimilarApprovalRuleSuggestion: Codable, Equatable, Sendable {
    public var label: String
    public var rule: AutoApprovalRule

    public init(label: String, rule: AutoApprovalRule) {
        self.label = label
        self.rule = rule
    }
}

public struct PendingApproval: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var sessionID: String
    public var source: SessionSource
    public var cwd: String
    public var toolName: String
    public var summary: String
    public var command: String
    public var requestedAt: Date
    public var expiresAt: Date
    public var similarRuleSuggestion: SimilarApprovalRuleSuggestion?

    public init(
        id: String,
        sessionID: String,
        source: SessionSource,
        cwd: String,
        toolName: String,
        summary: String,
        command: String,
        requestedAt: Date,
        expiresAt: Date,
        similarRuleSuggestion: SimilarApprovalRuleSuggestion? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.source = source
        self.cwd = cwd
        self.toolName = toolName
        self.summary = summary
        self.command = command
        self.requestedAt = requestedAt
        self.expiresAt = expiresAt
        self.similarRuleSuggestion = similarRuleSuggestion
    }

    public func isExpired(now: Date = Date()) -> Bool {
        now >= expiresAt
    }
}

public enum PanelApprovalDecision: String, Codable, Equatable, Sendable {
    case allowOnce
    case rejectOnce
    case allowSimilarNextTime
}

public struct ApprovalDecisionRecord: Codable, Equatable, Sendable {
    public var id: String
    public var decision: PanelApprovalDecision
    public var decidedAt: Date
    public var ruleToAdd: AutoApprovalRule?

    public init(
        id: String,
        decision: PanelApprovalDecision,
        decidedAt: Date = Date(),
        ruleToAdd: AutoApprovalRule? = nil
    ) {
        self.id = id
        self.decision = decision
        self.decidedAt = decidedAt
        self.ruleToAdd = ruleToAdd
    }
}
