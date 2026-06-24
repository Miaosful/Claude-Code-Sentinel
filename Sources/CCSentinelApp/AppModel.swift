import Foundation
import CCSentinelCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var store = SessionStore()
    @Published private var autoApprovalStats = AutoApprovalStats()
    @Published var monitoringPaused = false
    @Published var autoApprovalEnabled = false
    @Published var integrationMessageKey: L10nKey?

    private let storeURL: URL
    private let settingsURL: URL
    private let hookBinaryURL: URL

    init(
        storeURL: URL = AppModel.defaultStoreURL(),
        settingsURL: URL = AppModel.defaultClaudeSettingsURL(),
        hookBinaryURL: URL = AppModel.defaultHookBinaryURL()
    ) {
        self.storeURL = storeURL
        self.settingsURL = settingsURL
        self.hookBinaryURL = hookBinaryURL
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

    func installHooks() {
        do {
            try HookSettingsInstaller.applyInstall(
                settingsURL: settingsURL,
                hookBinaryPath: hookBinaryURL.path
            )
            integrationMessageKey = .hooksInstalled
        } catch {
            integrationMessageKey = .hooksFailed
        }
    }

    func uninstallHooks() {
        do {
            try HookSettingsInstaller.applyUninstall(settingsURL: settingsURL)
            integrationMessageKey = .hooksUninstalled
        } catch {
            integrationMessageKey = .hooksFailed
        }
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

    private static func defaultClaudeSettingsURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    private static func defaultHookBinaryURL() -> URL {
        let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent()
            ?? FileManager.default.currentDirectoryPathURL
        return executableDirectory.appendingPathComponent("cc-sentinel-hook")
    }
}

private extension FileManager {
    var currentDirectoryPathURL: URL {
        URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
    }
}
