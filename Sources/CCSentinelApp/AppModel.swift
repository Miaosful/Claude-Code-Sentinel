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
    @Published var integrationMessage: IntegrationMessage?
    @Published private(set) var hooksInstalled = false
    @Published var languagePreference: AppLanguagePreference {
        didSet {
            guard languagePreference != oldValue else { return }
            userDefaults.set(languagePreference.rawValue, forKey: Self.languagePreferenceDefaultsKey)
        }
    }

    private let storeURL: URL
    private let autoApprovalSettingsURL: URL
    private let autoApprovalStatsURL: URL
    private let settingsURL: URL
    private let hookBinaryURL: URL
    private let userDefaults: UserDefaults
    private var autoApprovalSettings: AutoApprovalSettings
    private static let languagePreferenceDefaultsKey = "ccSentinel.languagePreference"

    init(
        storeURL: URL = AppModel.defaultStoreURL(),
        autoApprovalSettingsURL: URL = AppModel.defaultAutoApprovalSettingsURL(),
        autoApprovalStatsURL: URL = AppModel.defaultAutoApprovalStatsURL(),
        settingsURL: URL = AppModel.defaultClaudeSettingsURL(),
        hookBinaryURL: URL = AppModel.defaultHookBinaryURL(),
        userDefaults: UserDefaults = .standard
    ) {
        self.storeURL = storeURL
        self.autoApprovalSettingsURL = autoApprovalSettingsURL
        self.autoApprovalStatsURL = autoApprovalStatsURL
        self.settingsURL = settingsURL
        self.hookBinaryURL = hookBinaryURL
        self.userDefaults = userDefaults
        self.languagePreference = AppLanguagePreference(
            rawValue: userDefaults.string(forKey: Self.languagePreferenceDefaultsKey) ?? ""
        ) ?? .system
        self.store = (try? SessionStorePersistence.load(from: storeURL)) ?? SessionStore()
        self.autoApprovalSettings = (try? AutoApprovalSettingsPersistence.load(from: autoApprovalSettingsURL)) ??
            AutoApprovalSettings(
                enabled: false,
                policy: ApprovalPolicy(allowWorkspaceReads: true, allowWorkspaceEdits: false),
                workspace: FileManager.default.homeDirectoryForCurrentUser.path
            )
        self.autoApprovalEnabled = autoApprovalSettings.enabled
        self.autoApprovalStats = (try? AutoApprovalStatsPersistence.load(from: autoApprovalStatsURL)) ?? AutoApprovalStats()
        refreshHookInstallationStatus()
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

    var approvalFocus: ApprovalFocus? {
        ApprovalFocus.resolve(store: store)
    }

    var requiresHookSetup: Bool {
        !hooksInstalled && store.sessions.isEmpty
    }

    func refreshAutoApprovalStats() {
        autoApprovalStats = (try? AutoApprovalStatsPersistence.load(from: autoApprovalStatsURL)) ?? autoApprovalStats
    }

    func refreshHookInstallationStatus() {
        hooksInstalled = (try? HookSettingsInstaller.hasManagedHooks(settingsURL: settingsURL)) ?? false
    }

    func localized(_ key: L10nKey) -> String {
        AppLocalizer.localized(key, languagePreference: languagePreference)
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
            let backupURL = try HookSettingsInstaller.applyInstall(
                settingsURL: settingsURL,
                hookBinaryPath: hookBinaryURL.path
            )
            hooksInstalled = true
            integrationMessage = IntegrationMessage(key: .hooksInstalled, detail: backupURL.path, isError: false)
        } catch {
            integrationMessage = IntegrationMessage(key: .hooksFailed, detail: String(describing: error), isError: true)
        }
    }

    func uninstallHooks() {
        do {
            let backupURL = try HookSettingsInstaller.applyUninstall(settingsURL: settingsURL)
            hooksInstalled = false
            integrationMessage = IntegrationMessage(key: .hooksUninstalled, detail: backupURL.path, isError: false)
        } catch {
            integrationMessage = IntegrationMessage(key: .hooksFailed, detail: String(describing: error), isError: true)
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

struct IntegrationMessage: Equatable {
    var key: L10nKey
    var detail: String
    var isError: Bool
}

private extension FileManager {
    var currentDirectoryPathURL: URL {
        URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
    }
}
