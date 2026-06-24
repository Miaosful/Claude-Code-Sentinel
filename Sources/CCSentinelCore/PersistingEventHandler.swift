import Foundation

public final class PersistingEventHandler: @unchecked Sendable {
    private let storeURL: URL
    private let lock = NSLock()
    private var store: SessionStore

    public init(storeURL: URL) {
        self.storeURL = storeURL
        self.store = (try? SessionStorePersistence.load(from: storeURL)) ?? SessionStore()
    }

    public func handle(_ event: NormalizedEvent) {
        lock.lock()
        store.apply(event)
        let snapshot = store
        lock.unlock()

        try? SessionStorePersistence.save(snapshot, to: storeURL)
    }

    public func snapshot() -> SessionStore {
        lock.lock()
        let snapshot = store
        lock.unlock()
        return snapshot
    }
}
