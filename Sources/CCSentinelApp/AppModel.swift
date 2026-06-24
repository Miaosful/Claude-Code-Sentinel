import Foundation
import CCSentinelCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var store = SessionStore()
    @Published var monitoringPaused = false
    @Published var autoApprovalEnabled = false
    @Published var autoApprovedToday = 0
    @Published var autoApprovedTotal = 0

    var aggregateStatus: AggregateStatus {
        monitoringPaused ? .degraded : store.aggregateStatus
    }

    func apply(_ event: NormalizedEvent) {
        guard !monitoringPaused else {
            return
        }
        store.apply(event)
    }

    func pauseOrResumeMonitoring() {
        monitoringPaused.toggle()
    }

    func clearStaleSessions() {
        let active = store.sessions.filter { session in
            session.status != .stale && session.status != .ended
        }
        store = SessionStore(sessions: active)
    }
}
