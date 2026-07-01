import Foundation

public enum SimilarApprovalSuggestion {
    public static func make(for event: NormalizedEvent, workspace: String) -> SimilarApprovalRuleSuggestion? {
        let tool = event.toolName ?? "Unknown"
        let command = (event.toolCommand ?? event.toolSummary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            return nil
        }

        if tool == "Bash" {
            return bashSuggestion(command: command)
        }

        if tool == "Read", isWorkspaceScoped(command: command, cwd: event.cwd, workspace: workspace) {
            return SimilarApprovalRuleSuggestion(
                label: "Read requests for \(command)",
                rule: AutoApprovalRule(
                    id: ruleID(prefix: "allow-similar-read", value: command),
                    effect: .allow,
                    tool: "Read",
                    scope: .workspace,
                    match: .init(commandPrefixes: [command])
                )
            )
        }

        return nil
    }

    private static func bashSuggestion(command: String) -> SimilarApprovalRuleSuggestion? {
        guard !containsShellControlOperator(command) else {
            return nil
        }

        let prefix: String
        if command.hasPrefix("git status") {
            prefix = "git status"
        } else if command.hasPrefix("git diff") {
            prefix = "git diff"
        } else if command.hasPrefix("git log") {
            prefix = "git log"
        } else if command.hasPrefix("swift build") {
            prefix = "swift build"
        } else if command.hasPrefix("swift test") {
            prefix = "swift test"
        } else if command.hasPrefix("npm run ") {
            prefix = command
        } else {
            return nil
        }

        return SimilarApprovalRuleSuggestion(
            label: "Bash commands starting with \"\(prefix)\"",
            rule: AutoApprovalRule(
                id: ruleID(prefix: "allow-similar-bash", value: prefix),
                effect: .allow,
                tool: "Bash",
                scope: .workspace,
                match: .init(commandPrefixes: [prefix])
            )
        )
    }

    private static func containsShellControlOperator(_ command: String) -> Bool {
        ["&&", "||", ";", "|", ">", "<"].contains { command.contains($0) }
    }

    private static func isWorkspaceScoped(command: String, cwd: String, workspace: String) -> Bool {
        guard !workspace.isEmpty else {
            return false
        }
        let candidate = command.hasPrefix("/") ? command : cwd
        let candidatePath = URL(fileURLWithPath: candidate).standardizedFileURL.path
        let workspacePath = URL(fileURLWithPath: workspace).standardizedFileURL.path
        return candidatePath == workspacePath || candidatePath.hasPrefix(workspacePath + "/")
    }

    private static func ruleID(prefix: String, value: String) -> String {
        let safe = value.lowercased()
            .map { character in
                character.isLetter || character.isNumber ? character : "-"
            }
        return ([prefix] + String(safe).split(separator: "-").map(String.init))
            .joined(separator: "-")
    }
}
