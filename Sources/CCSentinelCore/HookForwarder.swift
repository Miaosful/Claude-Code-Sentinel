import Foundation

public enum HookForwarder {
    public enum ForwardError: Error, Equatable {
        case emptyInput
        case fallbackWriteFailed
    }

    public static func forward(
        data: Data,
        endpoint: URL,
        fallbackURL: URL,
        timeout: TimeInterval = 0.25
    ) async throws {
        guard !data.isEmpty else {
            throw ForwardError.emptyInput
        }

        if await post(data: data, endpoint: endpoint, timeout: timeout) {
            return
        }

        do {
            try appendFallback(data, to: fallbackURL)
        } catch {
            throw ForwardError.fallbackWriteFailed
        }
    }

    private static func post(data: Data, endpoint: URL, timeout: TimeInterval) async -> Bool {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        do {
            let (_, response) = try await URLSession.shared.upload(for: request, from: data)
            return (response as? HTTPURLResponse)?.statusCode == 202
        } catch {
            return false
        }
    }

    private static func appendFallback(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.write(contentsOf: Data("\n".utf8))
    }
}
