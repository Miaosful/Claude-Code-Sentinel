import Foundation
import CCSentinelCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var store = SessionStore()
    @Published private var autoApprovalStats = AutoApprovalStats()
    @Published var monitoringPaused = false
    @Published var autoApprovalEnabled = false

    private let storeURL: URL

    init(storeURL: URL = AppModel.defaultStoreURL()) {
        self.storeURL = storeURL
        self.store = (try? SessionStorePersistence.load(from: storeURL)) ?? SessionStore()
    }

    var aggregateStatus: AggregateStatus {
        monitoringPaused ? .degraded : store.aggregateStatus
    }

    var autoApprovedToday: Int {
        autoApprovalStats.todayCount()
    }

    var autoApprovedTotal: Int {
        autoApprovalStats.totalCount
    }

    func apply(_ event: NormalizedEvent) {
        guard !monitoringPaused else {
            return
        }
        store.apply(event)
        persistStore()
    }

    func pauseOrResumeMonitoring() {
        monitoringPaused.toggle()
    }

    func clearStaleSessions() {
        let active = store.sessions.filter { session in
            session.status != .stale && session.status != .ended
        }
        store = SessionStore(sessions: active)
        persistStore()
    }

    func recordAutoApproval(toolName: String, summary: String, workspace: String) {
        autoApprovalStats.record(toolName: toolName, summary: summary, workspace: workspace)
    }

    private func persistStore() {
        try? SessionStorePersistence.save(store, to: storeURL)
    }

    private static func defaultStoreURL() -> URL {
        let applicationSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return applicationSupport
            .appendingPathComponent("CC Sentinel", isDirectory: true)
            .appendingPathComponent("session-store.json")
    }
}
