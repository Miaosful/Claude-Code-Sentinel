import Foundation
import CCSentinelCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var store = SessionStore()
    @Published private var autoApprovalStats = AutoApprovalStats()
    @Published var monitoringPaused = false
    @Published var autoApprovalEnabled = false {
        didSet {
            guard autoApprovalEnabled != oldValue else { return }
            autoApprovalSettings.enabled = autoApprovalEnabled
            persistAutoApprovalSettings()
        }
    }
    @Published var integrationMessageKey: L10nKey?

    private let storeURL: URL
    private let autoApprovalSettingsURL: URL
    private let autoApprovalStatsURL: URL
    private let settingsURL: URL
    private let hookBinaryURL: URL
    private var autoApprovalSettings: AutoApprovalSettings

    init(
        storeURL: URL = AppModel.defaultStoreURL(),
        autoApprovalSettingsURL: URL = AppModel.defaultAutoApprovalSettingsURL(),
        autoApprovalStatsURL: URL = AppModel.defaultAutoApprovalStatsURL(),
        settingsURL: URL = AppModel.defaultClaudeSettingsURL(),
        hookBinaryURL: URL = AppModel.defaultHookBinaryURL()
    ) {
        self.storeURL = storeURL
        self.autoApprovalSettingsURL = autoApprovalSettingsURL
        self.autoApprovalStatsURL = autoApprovalStatsURL
        self.settingsURL = settingsURL
        self.hookBinaryURL = hookBinaryURL
        self.store = (try? SessionStorePersistence.load(from: storeURL)) ?? SessionStore()
        self.autoApprovalSettings = (try? AutoApprovalSettingsPersistence.load(from: autoApprovalSettingsURL)) ??
            AutoApprovalSettings(
                enabled: false,
                policy: ApprovalPolicy(allowWorkspaceReads: true, allowWorkspaceEdits: false),
                workspace: FileManager.default.homeDirectoryForCurrentUser.path
            )
        self.autoApprovalEnabled = autoApprovalSettings.enabled
        self.autoApprovalStats = (try? AutoApprovalStatsPersistence.load(from: autoApprovalStatsURL)) ?? AutoApprovalStats()
        persistAutoApprovalSettings()
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

    func refreshAutoApprovalStats() {
        autoApprovalStats = (try? AutoApprovalStatsPersistence.load(from: autoApprovalStatsURL)) ?? autoApprovalStats
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
        try? AutoApprovalStatsPersistence.save(autoApprovalStats, to: autoApprovalStatsURL)
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
        CCSentinelPaths.storeURL()
    }

    private func persistAutoApprovalSettings() {
        try? AutoApprovalSettingsPersistence.save(autoApprovalSettings, to: autoApprovalSettingsURL)
    }

    private static func defaultAutoApprovalSettingsURL() -> URL {
        CCSentinelPaths.autoApprovalSettingsURL()
    }

    private static func defaultAutoApprovalStatsURL() -> URL {
        CCSentinelPaths.autoApprovalStatsURL()
    }

    private static func defaultClaudeSettingsURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["CC_SENTINEL_SETTINGS_PATH"] {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    private static func defaultHookBinaryURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["CC_SENTINEL_HOOK_BINARY_PATH"] {
            return URL(fileURLWithPath: override)
        }
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
