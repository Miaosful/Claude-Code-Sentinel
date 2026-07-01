import Foundation

public struct AutoApprovalProfile: Codable, Equatable, Sendable {
    public var name: String
    public var notes: String?

    public init(name: String, notes: String? = nil) {
        self.name = name
        self.notes = notes
    }
}

public struct AutoApprovalRule: Codable, Equatable, Sendable {
    public enum Effect: String, Codable, Equatable, Sendable {
        case allow
        case deny
    }

    public enum Scope: String, Codable, Equatable, Sendable {
        case workspace
        case any
    }

    public struct Match: Codable, Equatable, Sendable {
        public var commandContains: [String]
        public var commandPrefixes: [String]

        public init(commandContains: [String] = [], commandPrefixes: [String] = []) {
            self.commandContains = commandContains
            self.commandPrefixes = commandPrefixes
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.commandContains = try container.decodeIfPresent([String].self, forKey: .commandContains) ?? []
            self.commandPrefixes = try container.decodeIfPresent([String].self, forKey: .commandPrefixes) ?? []
        }
    }

    public var id: String
    public var effect: Effect
    public var tool: String
    public var scope: Scope?
    public var match: Match?

    public init(id: String, effect: Effect, tool: String, scope: Scope? = nil, match: Match? = nil) {
        self.id = id
        self.effect = effect
        self.tool = tool
        self.scope = scope
        self.match = match
    }

    public static func allowWorkspaceRead() -> AutoApprovalRule {
        AutoApprovalRule(id: "allow-workspace-read", effect: .allow, tool: "Read", scope: .workspace, match: nil)
    }

    public static func allowWorkspaceEdit() -> AutoApprovalRule {
        AutoApprovalRule(id: "allow-workspace-edit", effect: .allow, tool: "Edit", scope: .workspace, match: nil)
    }

    public static func allowTextInspection() -> AutoApprovalRule {
        AutoApprovalRule(
            id: "allow-text-inspection",
            effect: .allow,
            tool: "Bash",
            scope: .workspace,
            match: .init(commandPrefixes: [
                "pwd",
                "ls",
                "find .",
                "rg",
                "grep",
                "cat",
                "sed -n",
                "wc",
                "head",
                "tail"
            ])
        )
    }

    public static func allowGitInspection() -> AutoApprovalRule {
        AutoApprovalRule(
            id: "allow-git-inspection",
            effect: .allow,
            tool: "Bash",
            scope: .workspace,
            match: .init(commandPrefixes: [
                "git status",
                "git diff",
                "git log",
                "git branch",
                "git show",
                "git rev-parse",
                "git remote"
            ])
        )
    }

    public static func allowSwiftWorkflow() -> AutoApprovalRule {
        AutoApprovalRule(
            id: "allow-swift-workflow",
            effect: .allow,
            tool: "Bash",
            scope: .workspace,
            match: .init(commandPrefixes: [
                "swift build",
                "swift test",
                "swift run CCSentinelCoreTestRunner",
                "swift run cc-sentinel-dump-state",
                "script/build_and_run.sh --verify"
            ])
        )
    }

    public func matches(tool: String, command: String, cwd: String, workspace: String) -> Bool {
        guard self.tool == tool else {
            return false
        }

        if let scope, scope == .workspace, !isWorkspaceScoped(command: command, cwd: cwd, workspace: workspace) {
            return false
        }

        if let match {
            let lowerCommand = command.lowercased()
            let trimmedLowerCommand = lowerCommand.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !containsShellControlOperator(trimmedLowerCommand) else {
                return false
            }
            return match.commandContains.contains { needle in
                lowerCommand.contains(needle.lowercased())
            } || match.commandPrefixes.contains { prefix in
                trimmedLowerCommand.hasPrefix(prefix.lowercased())
            }
        }

        return true
    }

    private func containsShellControlOperator(_ command: String) -> Bool {
        ["&&", "||", ";", "|", ">", "<"].contains { command.contains($0) }
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

public struct AutoApprovalConfig: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var enabled: Bool
    public var workspace: String
    public var profile: AutoApprovalProfile?
    public var rules: [AutoApprovalRule]

    public static let `default` = AutoApprovalConfig(
        schemaVersion: 1,
        enabled: false,
        workspace: "",
        profile: nil,
        rules: [
            .allowWorkspaceRead(),
            .allowTextInspection(),
            .allowGitInspection(),
            .allowSwiftWorkflow()
        ]
    )

    public init(
        schemaVersion: Int,
        enabled: Bool,
        workspace: String,
        profile: AutoApprovalProfile? = nil,
        rules: [AutoApprovalRule]
    ) {
        self.schemaVersion = schemaVersion
        self.enabled = enabled
        self.workspace = workspace
        self.profile = profile
        self.rules = rules
    }

    public func evaluate(tool: String, command: String, cwd: String, fallbackWorkspace: String) -> ApprovalDecision {
        guard enabled else {
            return .ask
        }

        let workspace = workspace.isEmpty ? fallbackWorkspace : workspace
        for rule in rules {
            guard rule.matches(tool: tool, command: command, cwd: cwd, workspace: workspace) else {
                continue
            }
            return rule.effect == .allow ? .allow : .ask
        }
        return .ask
    }
}
