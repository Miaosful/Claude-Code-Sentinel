import Foundation

public struct AutoApprovalEvent: Codable, Equatable, Sendable {
    public var toolName: String
    public var summary: String
    public var workspace: String
    public var approvedAt: Date

    public init(toolName: String, summary: String, workspace: String, approvedAt: Date) {
        self.toolName = toolName
        self.summary = summary
        self.workspace = workspace
        self.approvedAt = approvedAt
    }
}

public struct AutoApprovalStats: Codable, Equatable, Sendable {
    public private(set) var events: [AutoApprovalEvent]

    public init(events: [AutoApprovalEvent] = []) {
        self.events = events
    }

    public var totalCount: Int {
        events.count
    }

    public var lastEvent: AutoApprovalEvent? {
        events.last
    }

    public mutating func record(toolName: String, summary: String, workspace: String, at date: Date = Date()) {
        events.append(AutoApprovalEvent(
            toolName: toolName,
            summary: summary,
            workspace: workspace,
            approvedAt: date
        ))
    }

    public func todayCount(now: Date = Date(), calendar: Calendar = .current) -> Int {
        events.filter { event in
            calendar.isDate(event.approvedAt, inSameDayAs: now)
        }.count
    }
}

public enum AutoApprovalStatsPersistence {
    public static func save(_ stats: AutoApprovalStats, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(stats)
        try data.write(to: url, options: .atomic)
    }

    public static func load(from url: URL) throws -> AutoApprovalStats {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return AutoApprovalStats()
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AutoApprovalStats.self, from: data)
    }
}
