import AppKit
import Foundation
import CCSentinelCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var store = SessionStore()
    private var hookStore = SessionStore()
    @Published private var autoApprovalStats = AutoApprovalStats()
    @Published var monitoringPaused = false
    @Published var autoApprovalEnabled = false {
        didSet {
            guard autoApprovalEnabled != oldValue else { return }
            autoApprovalConfig.enabled = autoApprovalEnabled
            persistAutoApprovalConfig()
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
    @Published var iconStylePreference: MenuBarIconStyle {
        didSet {
            guard iconStylePreference != oldValue else { return }
            userDefaults.set(iconStylePreference.rawValue, forKey: Self.iconStyleDefaultsKey)
        }
    }

    private let storeURL: URL
    private let autoApprovalConfigURL: URL
    private let legacyAutoApprovalSettingsURL: URL
    private let autoApprovalStatsURL: URL
    private let settingsURL: URL
    private let hookBinaryURL: URL
    private let userDefaults: UserDefaults
    private var autoApprovalConfig: AutoApprovalConfig
    private static let languagePreferenceDefaultsKey = "ccSentinel.languagePreference"
    private static let iconStyleDefaultsKey = "ccSentinel.iconStylePreference"

    init(
        storeURL: URL = AppModel.defaultStoreURL(),
        autoApprovalConfigURL: URL = AppModel.defaultAutoApprovalConfigURL(),
        legacyAutoApprovalSettingsURL: URL = AppModel.defaultAutoApprovalSettingsURL(),
        autoApprovalStatsURL: URL = AppModel.defaultAutoApprovalStatsURL(),
        settingsURL: URL = AppModel.defaultClaudeSettingsURL(),
        hookBinaryURL: URL = AppModel.defaultHookBinaryURL(),
        userDefaults: UserDefaults = .standard
    ) {
        self.storeURL = storeURL
        self.autoApprovalConfigURL = autoApprovalConfigURL
        self.legacyAutoApprovalSettingsURL = legacyAutoApprovalSettingsURL
        self.autoApprovalStatsURL = autoApprovalStatsURL
        self.settingsURL = settingsURL
        self.hookBinaryURL = hookBinaryURL
        self.userDefaults = userDefaults
        self.languagePreference = AppLanguagePreference(
            rawValue: userDefaults.string(forKey: Self.languagePreferenceDefaultsKey) ?? ""
        ) ?? .system
        self.iconStylePreference = MenuBarIconStyle(
            rawValue: userDefaults.string(forKey: Self.iconStyleDefaultsKey) ?? ""
        ) ?? .dot
        self.hookStore = (try? SessionStorePersistence.load(from: storeURL)) ?? SessionStore()
        self.store = hookStore
        self.autoApprovalConfig = (try? AutoApprovalConfigMigration.loadMigrating(
            configURL: autoApprovalConfigURL,
            legacySettingsURL: legacyAutoApprovalSettingsURL
        )) ?? .default
        self.autoApprovalEnabled = autoApprovalConfig.enabled
        self.autoApprovalStats = (try? AutoApprovalStatsPersistence.load(from: autoApprovalStatsURL)) ?? AutoApprovalStats()
        refreshHookInstallationStatus()
        refreshVisibleRuntimeState()
        persistAutoApprovalConfig()
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

    var autoApprovalConfigFileURL: URL {
        autoApprovalConfigURL
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

    func refreshRuntimeStatus() {
        refreshAutoApprovalStats()
        refreshVisibleRuntimeState()
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
        hookStore.apply(event)
        store = hookStore
        persistStore()
        refreshVisibleRuntimeState()
    }

    func pauseOrResumeMonitoring() {
        monitoringPaused.toggle()
    }

    func clearStaleSessions() {
        hookStore.clearInactiveSessions()
        store = hookStore
        persistStore()
        refreshVisibleRuntimeState()
    }

    func recordAutoApproval(toolName: String, summary: String, workspace: String) {
        autoApprovalStats.record(toolName: toolName, summary: summary, workspace: workspace)
        try? AutoApprovalStatsPersistence.save(autoApprovalStats, to: autoApprovalStatsURL)
    }

    func importAutoApprovalConfig(from url: URL) {
        do {
            let backupURL = try AutoApprovalConfigPersistence.replaceActiveConfig(with: url, activeURL: autoApprovalConfigURL)
            let imported = try AutoApprovalConfigPersistence.load(from: autoApprovalConfigURL)
            autoApprovalConfig = imported
            autoApprovalEnabled = imported.enabled
            integrationMessage = IntegrationMessage(key: .autoApprovalConfigImported, detail: backupURL.path, isError: false)
        } catch {
            integrationMessage = IntegrationMessage(
                key: .autoApprovalConfigImportFailed,
                detail: autoApprovalConfigErrorDetail(error),
                isError: true
            )
        }
    }

    func exportAutoApprovalConfig(to url: URL) {
        do {
            try AutoApprovalConfigPersistence.save(autoApprovalConfig, to: url)
        } catch {
            integrationMessage = IntegrationMessage(key: .autoApprovalConfigImportFailed, detail: String(describing: error), isError: true)
        }
    }

    func presentImportAutoApprovalConfigPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        importAutoApprovalConfig(from: url)
    }

    func presentExportAutoApprovalConfigPanel() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "auto-approval-config.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        exportAutoApprovalConfig(to: url)
    }

    func revealAutoApprovalConfigInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([autoApprovalConfigURL])
    }

    private func autoApprovalConfigErrorDetail(_ error: Error) -> String {
        if let configError = error as? AutoApprovalConfigError {
            return configError.userFacingDescription
        }
        return String(describing: error)
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
        try? SessionStorePersistence.save(hookStore, to: storeURL)
    }

    private func refreshVisibleRuntimeState() {
        guard !monitoringPaused else {
            store = hookStore
            return
        }

        let snapshot = (try? ClaudeProcessDetector.scanCurrentProcesses()) ?? ClaudeProcessSnapshot()
        refreshStaleSessions(processSnapshot: snapshot)
        refreshProcessFallback(snapshot)
    }

    private func refreshProcessFallback(_ snapshot: ClaudeProcessSnapshot) {
        store = hookStore.includingProcessFallback(snapshot)
    }

    private func refreshStaleSessions(processSnapshot: ClaudeProcessSnapshot) {
        guard !monitoringPaused else {
            return
        }

        let previousStore = hookStore
        hookStore.markStale(
            timeout: SessionStore.defaultStaleTimeout,
            activeClaudeProcessIDs: Set(processSnapshot.processes.map(\.pid))
        )
        guard hookStore != previousStore else {
            return
        }

        store = hookStore
        persistStore()
    }

    private static func defaultStoreURL() -> URL {
        CCSentinelPaths.storeURL()
    }

    private func persistAutoApprovalConfig() {
        try? AutoApprovalConfigPersistence.save(autoApprovalConfig, to: autoApprovalConfigURL)
    }

    private static func defaultAutoApprovalConfigURL() -> URL {
        CCSentinelPaths.autoApprovalConfigURL()
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
