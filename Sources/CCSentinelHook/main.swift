import Foundation
import CryptoKit
import CCSentinelCore

let data = FileHandle.standardInput.readDataToEndOfFile()

guard !data.isEmpty else {
    FileHandle.standardError.write(Data("cc-sentinel-hook: empty stdin\n".utf8))
    Foundation.exit(2)
}

let environment = ProcessInfo.processInfo.environment
let fallbackURL = CCSentinelPaths.fallbackURL(environment: environment)
let endpoint = URL(string: environment["CC_SENTINEL_ENDPOINT"] ?? "http://127.0.0.1:47281/events")!
let forwardedData = enrichedDataWithClaudePID(data)

do {
    try await HookForwarder.forward(data: forwardedData, endpoint: endpoint, fallbackURL: fallbackURL)
    if let output = autoApprovalOutput(for: forwardedData, environment: environment) {
        print(output)
    }
    Foundation.exit(0)
} catch {
    FileHandle.standardError.write(Data("cc-sentinel-hook: \(error)\n".utf8))
    Foundation.exit(2)
}

private func autoApprovalOutput(for data: Data, environment: [String: String]) -> String? {
    let configURL = CCSentinelPaths.autoApprovalConfigURL(environment: environment)
    let legacySettingsURL = CCSentinelPaths.autoApprovalSettingsURL(environment: environment)
    let statsURL = CCSentinelPaths.autoApprovalStatsURL(environment: environment)
    do {
        let config = try AutoApprovalConfigMigration.loadMigrating(
            configURL: configURL,
            legacySettingsURL: legacySettingsURL
        )
        var stats = try AutoApprovalStatsPersistence.load(from: statsURL)
        let result = try AutoApprovalHookDecision.evaluate(
            inputData: data,
            config: config,
            stats: &stats
        )
        if result.decision == .allow {
            try AutoApprovalStatsPersistence.save(stats, to: statsURL)
            return result.outputJSON
        }
        guard result.decision == .ask else {
            return nil
        }
        return try panelApprovalOutput(
            for: data,
            config: config,
            environment: environment
        )
    } catch {
        FileHandle.standardError.write(Data("cc-sentinel-hook: auto approval skipped: \(error)\n".utf8))
        return nil
    }
}

private func panelApprovalOutput(
    for data: Data,
    config: AutoApprovalConfig,
    environment: [String: String]
) throws -> String? {
    let event = try EventNormalizer.normalize(data)
    guard event.kind == .permissionRequest else {
        return nil
    }

    let command = event.toolCommand ?? event.toolSummary ?? ""
    let now = Date()
    let timeout = panelApprovalTimeout(environment: environment)
    let workspace = config.workspace.isEmpty ? event.cwd : config.workspace
    let approval = PendingApproval(
        id: pendingApprovalID(event: event, command: command, requestedAt: now),
        sessionID: event.sessionID,
        source: event.source,
        cwd: event.cwd,
        toolName: event.toolName ?? "Unknown",
        summary: event.toolSummary ?? command,
        command: command,
        requestedAt: now,
        expiresAt: now.addingTimeInterval(timeout),
        similarRuleSuggestion: SimilarApprovalSuggestion.make(for: event, workspace: workspace)
    )
    let pendingDirectory = CCSentinelPaths.pendingApprovalsDirectory(environment: environment)
    let decisionsDirectory = CCSentinelPaths.approvalDecisionsDirectory(environment: environment)
    try PendingApprovalPersistence.save(approval, to: pendingDirectory)

    guard let decision = try PendingApprovalPersistence.waitForDecision(
        id: approval.id,
        in: decisionsDirectory,
        timeout: timeout
    ) else {
        try? PendingApprovalPersistence.removeApproval(id: approval.id, from: pendingDirectory)
        return nil
    }

    try? PendingApprovalPersistence.removeApproval(id: approval.id, from: pendingDirectory)
    return AutoApprovalHookDecision.outputJSON(for: decision.decision)
}

private func panelApprovalTimeout(environment: [String: String]) -> TimeInterval {
    guard
        let value = environment["CC_SENTINEL_PANEL_APPROVAL_TIMEOUT"],
        let timeout = TimeInterval(value),
        timeout >= 0
    else {
        return 120
    }
    return timeout
}

private func pendingApprovalID(event: NormalizedEvent, command: String, requestedAt: Date) -> String {
    let raw = "\(event.sessionID)\n\(event.cwd)\n\(event.toolName ?? "Unknown")\n\(command)\n\(Int(requestedAt.timeIntervalSince1970 * 1000))"
    let digest = SHA256.hash(data: Data(raw.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
}

private func enrichedDataWithClaudePID(_ data: Data) -> Data {
    do {
        if let pid = ClaudeProcessDetector.nearestClaudeAncestorPIDFromSystem() {
            return try HookPayloadEnricher.addClaudePID(pid, to: data)
        }

        let entries = try ProcessListEntry.current()
        guard let pid = ClaudeProcessDetector.nearestClaudeAncestorPID(
            for: ProcessInfo.processInfo.processIdentifier,
            entries: entries
        ) else {
            return data
        }
        return try HookPayloadEnricher.addClaudePID(pid, to: data)
    } catch {
        FileHandle.standardError.write(Data("cc-sentinel-hook: pid enrichment skipped: \(error)\n".utf8))
        return data
    }
}
