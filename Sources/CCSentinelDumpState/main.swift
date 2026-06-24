import Foundation
import CCSentinelCore

let environment = ProcessInfo.processInfo.environment
let storeURL = environment["CC_SENTINEL_STORE_PATH"]
    .map { URL(fileURLWithPath: $0) } ?? defaultStoreURL()

do {
    let store = try SessionStorePersistence.load(from: storeURL)
    print(SessionStoreDump.render(store: store))
    Foundation.exit(0)
} catch {
    FileHandle.standardError.write(Data("cc-sentinel-dump-state: \(error)\n".utf8))
    Foundation.exit(2)
}

private func defaultStoreURL() -> URL {
    let applicationSupport = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first ?? FileManager.default.temporaryDirectory
    return applicationSupport
        .appendingPathComponent("CC Sentinel", isDirectory: true)
        .appendingPathComponent("session-store.json")
}
