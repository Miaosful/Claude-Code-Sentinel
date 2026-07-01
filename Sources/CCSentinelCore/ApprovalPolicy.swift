import Foundation

public enum ApprovalDecision: String, Codable, Equatable, Sendable {
    case allow
    case ask
    case deny
}

public struct ApprovalPolicy: Codable, Equatable, Sendable {
    public var allowWorkspaceReads: Bool
    public var allowWorkspaceEdits: Bool

    public static let `default` = ApprovalPolicy(
        allowWorkspaceReads: false,
        allowWorkspaceEdits: false
    )

    public init(allowWorkspaceReads: Bool, allowWorkspaceEdits: Bool) {
        self.allowWorkspaceReads = allowWorkspaceReads
        self.allowWorkspaceEdits = allowWorkspaceEdits
    }

    public static func from(rules: [AutoApprovalRule]) -> ApprovalPolicy {
        ApprovalPolicy(
            allowWorkspaceReads: rules.contains { $0.id == "allow-workspace-read" && $0.effect == .allow },
            allowWorkspaceEdits: rules.contains { $0.id == "allow-workspace-edit" && $0.effect == .allow }
        )
    }

    public func rules(workspace: String) -> [AutoApprovalRule] {
        var result: [AutoApprovalRule] = []
        if allowWorkspaceReads {
            result.append(.allowWorkspaceRead())
        }
        if allowWorkspaceEdits {
            result.append(.allowWorkspaceEdit())
        }
        return result
    }

    public func evaluate(tool: String, command: String, cwd: String, workspace: String) -> ApprovalDecision {
        if tool == "Read", allowWorkspaceReads, isWorkspaceScoped(command: command, cwd: cwd, workspace: workspace) {
            return .allow
        }

        if tool == "Edit", allowWorkspaceEdits, isWorkspaceScoped(command: command, cwd: cwd, workspace: workspace) {
            return .allow
        }

        return .ask
    }

    private func isWorkspaceScoped(command: String, cwd: String, workspace: String) -> Bool {
        guard !workspace.isEmpty else {
            return false
        }
        if command.hasPrefix("/") {
            return path(command, isWithin: workspace)
        }
        return path(cwd, isWithin: workspace)
    }

    private func path(_ candidate: String, isWithin workspace: String) -> Bool {
        let candidateURL = URL(fileURLWithPath: candidate).standardizedFileURL.path
        let workspaceURL = URL(fileURLWithPath: workspace).standardizedFileURL.path
        return candidateURL == workspaceURL || candidateURL.hasPrefix(workspaceURL + "/")
    }
}
