import Foundation
import Dispatch
import CCSentinelCore

let environment = ProcessInfo.processInfo.environment
let storeURL = CCSentinelPaths.storeURL(environment: environment)
let port = environment["CC_SENTINEL_PORT"].flatMap(UInt16.init) ?? 47281
let handler = PersistingEventHandler(storeURL: storeURL)

do {
    let receiver = try EventReceiver(port: port) { event in
        handler.handle(event)
        FileHandle.standardError.write(Data("cc-sentinel-debug-receiver: accepted \(event.kind.rawValue) \(event.sessionID)\n".utf8))
    }
    receiver.start()
    FileHandle.standardError.write(Data("cc-sentinel-debug-receiver: listening on 127.0.0.1:\(port)\n".utf8))
    FileHandle.standardError.write(Data("cc-sentinel-debug-receiver: store \(storeURL.path)\n".utf8))
    dispatchMain()
} catch {
    FileHandle.standardError.write(Data("cc-sentinel-debug-receiver: \(error)\n".utf8))
    Foundation.exit(2)
}
