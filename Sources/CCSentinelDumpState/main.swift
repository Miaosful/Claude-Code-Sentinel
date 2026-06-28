import Foundation
import CCSentinelCore

let environment = ProcessInfo.processInfo.environment
let storeURL = CCSentinelPaths.storeURL(environment: environment)

var hookStore = (try? SessionStorePersistence.load(from: storeURL)) ?? SessionStore()
let store: SessionStore

if environment["CC_SENTINEL_DUMP_RAW_STORE"] == "1" {
    store = hookStore
} else {
    let snapshot = (try? ClaudeProcessDetector.scanCurrentProcesses()) ?? ClaudeProcessSnapshot()
    hookStore.markStale(
        timeout: SessionStore.defaultStaleTimeout,
        activeClaudeProcessIDs: Set(snapshot.processes.map(\.pid))
    )
    store = hookStore.includingProcessFallback(snapshot)
}

print(SessionStoreDump.render(store: store))
Foundation.exit(0)
