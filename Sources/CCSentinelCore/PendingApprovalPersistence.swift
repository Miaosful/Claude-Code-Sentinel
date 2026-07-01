import Foundation

public enum PendingApprovalPersistence {
    public static func save(_ approval: PendingApproval, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(approval)
        try data.write(to: fileURL(for: approval.id, in: directory), options: .atomic)
    }

    public static func loadActive(from directory: URL, now: Date = Date()) throws -> [PendingApproval] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        let decoder = JSONDecoder()
        return try files.compactMap { file in
            let approval = try decoder.decode(PendingApproval.self, from: Data(contentsOf: file))
            return approval.isExpired(now: now) ? nil : approval
        }.sorted { $0.requestedAt < $1.requestedAt }
    }

    public static func removeApproval(id: String, from directory: URL) throws {
        let url = fileURL(for: id, in: directory)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    public static func saveDecision(_ decision: ApprovalDecisionRecord, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(decision)
        try data.write(to: fileURL(for: decision.id, in: directory), options: .atomic)
    }

    public static func consumeDecision(id: String, from directory: URL) throws -> ApprovalDecisionRecord? {
        let url = fileURL(for: id, in: directory)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let decision = try JSONDecoder().decode(ApprovalDecisionRecord.self, from: Data(contentsOf: url))
        try FileManager.default.removeItem(at: url)
        return decision
    }

    public static func waitForDecision(
        id: String,
        in directory: URL,
        timeout: TimeInterval,
        pollInterval: TimeInterval = 0.2,
        now: () -> Date = Date.init,
        sleep: (TimeInterval) throws -> Void = { Thread.sleep(forTimeInterval: $0) }
    ) throws -> ApprovalDecisionRecord? {
        let deadline = now().addingTimeInterval(timeout)
        while now() < deadline {
            if let decision = try consumeDecision(id: id, from: directory) {
                return decision
            }
            try sleep(pollInterval)
        }
        return nil
    }

    private static func fileURL(for id: String, in directory: URL) -> URL {
        directory.appendingPathComponent(id).appendingPathExtension("json")
    }
}
