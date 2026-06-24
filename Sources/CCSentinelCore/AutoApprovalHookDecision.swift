import Foundation

public struct AutoApprovalHookResult: Equatable, Sendable {
    public var decision: ApprovalDecision
    public var outputJSON: String?

    public init(decision: ApprovalDecision, outputJSON: String?) {
        self.decision = decision
        self.outputJSON = outputJSON
    }
}

public enum AutoApprovalHookDecision {
    public static func evaluate(
        inputData: Data,
        settings: AutoApprovalSettings,
        stats: inout AutoApprovalStats,
        now: Date = Date()
    ) throws -> AutoApprovalHookResult {
        guard settings.enabled else {
            return AutoApprovalHookResult(decision: .ask, outputJSON: nil)
        }

        let event = try EventNormalizer.normalize(inputData)
        guard event.kind == .permissionRequest else {
            return AutoApprovalHookResult(decision: .ask, outputJSON: nil)
        }

        let tool = event.toolName ?? "Unknown"
        let command = event.toolCommand ?? event.toolSummary ?? ""
        let workspace = settings.workspace.isEmpty ? event.cwd : settings.workspace
        let decision = settings.policy.evaluate(
            tool: tool,
            command: command,
            cwd: event.cwd,
            workspace: workspace
        )

        guard decision == .allow else {
            return AutoApprovalHookResult(decision: decision, outputJSON: nil)
        }

        stats.record(
            toolName: tool,
            summary: event.toolSummary ?? command,
            workspace: workspace,
            at: now
        )

        return AutoApprovalHookResult(decision: .allow, outputJSON: allowOutputJSON())
    }

    private static func allowOutputJSON() -> String {
        """
        {"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}
        """
    }
}
