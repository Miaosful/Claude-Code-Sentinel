import Foundation
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
    let settingsURL = CCSentinelPaths.autoApprovalSettingsURL(environment: environment)
    let statsURL = CCSentinelPaths.autoApprovalStatsURL(environment: environment)
    do {
        let settings = try AutoApprovalSettingsPersistence.load(from: settingsURL)
        var stats = try AutoApprovalStatsPersistence.load(from: statsURL)
        let result = try AutoApprovalHookDecision.evaluate(
            inputData: data,
            settings: settings,
            stats: &stats
        )
        if result.decision == .allow {
            try AutoApprovalStatsPersistence.save(stats, to: statsURL)
        }
        return result.outputJSON
    } catch {
        FileHandle.standardError.write(Data("cc-sentinel-hook: auto approval skipped: \(error)\n".utf8))
        return nil
    }
}

private func enrichedDataWithClaudePID(_ data: Data) -> Data {
    do {
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
