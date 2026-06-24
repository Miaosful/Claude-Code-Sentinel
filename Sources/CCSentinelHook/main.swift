import Foundation
import CCSentinelCore

let data = FileHandle.standardInput.readDataToEndOfFile()

guard !data.isEmpty else {
    FileHandle.standardError.write(Data("cc-sentinel-hook: empty stdin\n".utf8))
    Foundation.exit(2)
}

let applicationSupport = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask)
    .first ?? FileManager.default.temporaryDirectory
let defaultFallbackURL = applicationSupport
    .appendingPathComponent("CC Sentinel", isDirectory: true)
    .appendingPathComponent("events-fallback.jsonl")
let environment = ProcessInfo.processInfo.environment
let fallbackURL = environment["CC_SENTINEL_FALLBACK_PATH"]
    .map { URL(fileURLWithPath: $0) } ?? defaultFallbackURL
let endpoint = URL(string: environment["CC_SENTINEL_ENDPOINT"] ?? "http://127.0.0.1:47281/events")!

do {
    try await HookForwarder.forward(data: data, endpoint: endpoint, fallbackURL: fallbackURL)
    Foundation.exit(0)
} catch {
    FileHandle.standardError.write(Data("cc-sentinel-hook: \(error)\n".utf8))
    Foundation.exit(2)
}
