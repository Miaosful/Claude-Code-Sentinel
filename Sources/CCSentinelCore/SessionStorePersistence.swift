import Foundation

public enum SessionStorePersistence {
    public static func save(_ store: SessionStore, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(store)
        try data.write(to: url, options: .atomic)
    }

    public static func load(from url: URL) throws -> SessionStore {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return SessionStore()
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SessionStore.self, from: data)
    }
}
