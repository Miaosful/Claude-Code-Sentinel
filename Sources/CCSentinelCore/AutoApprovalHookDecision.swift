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
    public static func outputJSON(for panelDecision: PanelApprovalDecision) -> String {
        switch panelDecision {
        case .allowOnce, .allowSimilarNextTime:
            return decisionOutputJSON(behavior: "allow")
        case .rejectOnce:
            return decisionOutputJSON(behavior: "deny")
        }
    }

    public static func evaluate(
        inputData: Data,
        config: AutoApprovalConfig,
        stats: inout AutoApprovalStats,
        now: Date = Date()
    ) throws -> AutoApprovalHookResult {
        let event = try EventNormalizer.normalize(inputData)
        guard event.kind == .permissionRequest else {
            return AutoApprovalHookResult(decision: .ask, outputJSON: nil)
        }

        let tool = event.toolName ?? "Unknown"
        let command = event.toolCommand ?? event.toolSummary ?? ""
        let workspace = config.workspace.isEmpty ? event.cwd : config.workspace
        let decision = config.evaluate(
            tool: tool,
            command: command,
            cwd: event.cwd,
            fallbackWorkspace: workspace
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
        decisionOutputJSON(behavior: "allow")
    }

    private static func decisionOutputJSON(behavior: String) -> String {
        """
        {"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"\(behavior)"}}}
        """
    }
}
