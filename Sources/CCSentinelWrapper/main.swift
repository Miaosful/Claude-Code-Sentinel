import Foundation
import CCSentinelCore

guard let arguments = WrapperArguments.parse(Array(CommandLine.arguments.dropFirst())) else {
    FileHandle.standardError.write(Data("cc-sentinel-wrapper: missing real Claude binary path\n".utf8))
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
let wrapperSessionID = "wrapper-\(ProcessInfo.processInfo.processIdentifier)"

func sendLifecycleEvent(_ name: String) async {
    let object: [String: Any] = [
        "hook_event_name": name,
        "session_id": wrapperSessionID,
        "cwd": FileManager.default.currentDirectoryPath,
        "source": "vscode"
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: object) else {
        return
    }
    try? await HookForwarder.forward(data: data, endpoint: endpoint, fallbackURL: fallbackURL)
}

await sendLifecycleEvent("WrapperProcessStart")

let process = Process()
process.executableURL = URL(fileURLWithPath: arguments.realClaudeBinary)
process.arguments = arguments.forwardedArguments
process.standardInput = FileHandle.standardInput
process.standardOutput = FileHandle.standardOutput
process.standardError = FileHandle.standardError

do {
    try process.run()
    process.waitUntilExit()
    await sendLifecycleEvent("WrapperProcessEnd")
    Foundation.exit(process.terminationStatus)
} catch {
    FileHandle.standardError.write(Data("cc-sentinel-wrapper: \(error)\n".utf8))
    await sendLifecycleEvent("WrapperProcessEnd")
    Foundation.exit(2)
}
