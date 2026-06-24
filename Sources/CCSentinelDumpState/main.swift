import Foundation
import CCSentinelCore

let environment = ProcessInfo.processInfo.environment
let storeURL = CCSentinelPaths.storeURL(environment: environment)

do {
    let store = try SessionStorePersistence.load(from: storeURL)
    print(SessionStoreDump.render(store: store))
    Foundation.exit(0)
} catch {
    FileHandle.standardError.write(Data("cc-sentinel-dump-state: \(error)\n".utf8))
    Foundation.exit(2)
}
