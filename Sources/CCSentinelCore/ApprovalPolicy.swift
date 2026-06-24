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

    public func evaluate(tool: String, command: String, cwd: String, workspace: String) -> ApprovalDecision {
        let lowerCommand = command.lowercased()
        if isDeniedCommand(lowerCommand) {
            return .deny
        }

        if tool == "Read", allowWorkspaceReads, isWorkspaceScoped(command: command, cwd: cwd, workspace: workspace) {
            return .allow
        }

        if tool == "Edit", allowWorkspaceEdits, isWorkspaceScoped(command: command, cwd: cwd, workspace: workspace) {
            return .allow
        }

        return .ask
    }

    private func isDeniedCommand(_ command: String) -> Bool {
        command.contains("git push") ||
            command.contains("rm -rf") ||
            command.contains("sudo ") ||
            command.contains("chmod -r") ||
            command.contains("/.ssh") ||
            command.contains("/.gnupg")
    }

    private func isWorkspaceScoped(command: String, cwd: String, workspace: String) -> Bool {
        if command.hasPrefix("/") {
            return command.hasPrefix(workspace)
        }
        return cwd.hasPrefix(workspace)
    }
}
