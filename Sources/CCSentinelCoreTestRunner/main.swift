import Foundation
import CCSentinelCore

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    if actual != expected {
        print("FAIL: \(message). Expected \(expected), got \(actual).")
        Foundation.exit(1)
    }
}

func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message).")
        Foundation.exit(1)
    }
}

assertEqual(CCSentinelVersion.current, "0.1.0", "core module exposes version")
print("PASS: FoundationSmokeTests")

func testApprovalBeatsRunningInAggregateStatus() {
    let sessions = [
        ClaudeSession(id: "a", source: .cli, cwd: "/tmp/a", status: .running),
        ClaudeSession(id: "b", source: .vscode, cwd: "/tmp/b", status: .waitingApproval)
    ]
    assertEqual(AggregateStatus.resolve(sessions: sessions), .waitingApproval, "approval beats running")
}

func testRunningBeatsStaleWhenNoApprovalExists() {
    let sessions = [
        ClaudeSession(id: "a", source: .unknown, cwd: "/tmp/a", status: .stale),
        ClaudeSession(id: "b", source: .cli, cwd: "/tmp/b", status: .running)
    ]
    assertEqual(AggregateStatus.resolve(sessions: sessions), .running, "running beats stale")
}

func testEmptySessionsAreIdle() {
    assertEqual(AggregateStatus.resolve(sessions: []), .idle, "empty sessions are idle")
}

testApprovalBeatsRunningInAggregateStatus()
testRunningBeatsStaleWhenNoApprovalExists()
testEmptySessionsAreIdle()
print("PASS: SessionStateTests")

func testPermissionRequestBecomesWaitingApprovalEvent() throws {
    let json = """
    {"hook_event_name":"PermissionRequest","session_id":"s1","cwd":"/repo","tool_name":"Bash","tool_input":{"command":"pnpm test"},"permission_mode":"default"}
    """.data(using: .utf8)!

    let event = try EventNormalizer.normalize(json)

    assertEqual(event.sessionID, "s1", "permission event session id")
    assertEqual(event.kind, .permissionRequest, "permission event kind")
    assertEqual(event.source, .unknown, "permission event source")
    assertEqual(event.cwd, "/repo", "permission event cwd")
    assertEqual(event.toolName, "Bash", "permission event tool name")
    assertEqual(event.toolSummary, "command=pnpm test", "permission event tool summary")
    assertEqual(event.toolCommand, "pnpm test", "permission event command")
}

func testReadPathBecomesToolCommand() throws {
    let json = """
    {"hook_event_name":"PermissionRequest","session_id":"s1","cwd":"/repo","tool_name":"Read","tool_input":{"file_path":"/repo/README.md"}}
    """.data(using: .utf8)!

    let event = try EventNormalizer.normalize(json)

    assertEqual(event.toolCommand, "/repo/README.md", "read path becomes command for policy evaluation")
}

func testRedactsTokenLikeValues() {
    let input = "curl -H Authorization: Bearer sk-live-secret-value https://example.test"
    let redacted = Redactor.safeSummary(input)

    assertTrue(!redacted.contains("sk-live-secret-value"), "redactor removes secret token")
    assertTrue(redacted.contains("[redacted]"), "redactor marks redacted content")
}

try testPermissionRequestBecomesWaitingApprovalEvent()
try testReadPathBecomesToolCommand()
testRedactsTokenLikeValues()
print("PASS: EventNormalizerTests")
print("PASS: RedactorTests")

func testPermissionRequestMarksSessionWaitingApproval() {
    var store = SessionStore()
    store.apply(.init(
        kind: .permissionRequest,
        sessionID: "s1",
        source: .vscode,
        cwd: "/repo",
        toolName: "Bash",
        toolSummary: "command=pnpm test"
    ))

    assertEqual(store.sessions.first?.status, .some(.waitingApproval), "permission request marks waiting approval")
    assertEqual(store.aggregateStatus, .waitingApproval, "permission request updates aggregate status")
}

func testPostToolUseClearsWaitingApproval() {
    var store = SessionStore()
    store.apply(.init(kind: .permissionRequest, sessionID: "s1", source: .vscode, cwd: "/repo", toolName: "Bash"))
    store.apply(.init(kind: .postToolUse, sessionID: "s1", source: .vscode, cwd: "/repo", toolName: "Bash"))

    assertEqual(store.sessions.first?.status, .some(.running), "post tool use clears waiting approval")
    assertEqual(store.sessions.first?.approvalRequest, nil, "post tool use clears approval request")
}

func testStaleTimeoutMarksOldRunningSessionsStale() {
    var store = SessionStore(sessions: [
        ClaudeSession(
            id: "s1",
            source: .cli,
            cwd: "/repo",
            status: .running,
            lastEventAt: Date(timeIntervalSince1970: 10)
        )
    ])

    store.markStale(now: Date(timeIntervalSince1970: 100), timeout: 30)

    assertEqual(store.sessions.first?.status, .some(.stale), "old running session becomes stale")
    assertEqual(store.aggregateStatus, .degraded, "stale session degrades aggregate status")
}

testPermissionRequestMarksSessionWaitingApproval()
testPostToolUseClearsWaitingApproval()
testStaleTimeoutMarksOldRunningSessionsStale()
print("PASS: SessionStoreTests")

func testSessionStorePersistenceRoundTripsJSON() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("cc-sentinel-store-\(UUID().uuidString)")
        .appendingPathExtension("json")
    let store = SessionStore(sessions: [
        ClaudeSession(
            id: "persisted",
            source: .vscode,
            cwd: "/repo",
            status: .waitingApproval,
            lastToolName: "Bash",
            lastToolSummary: "command=pnpm test",
            lastEventAt: Date(timeIntervalSince1970: 123)
        )
    ])

    try SessionStorePersistence.save(store, to: url)
    let loaded = try SessionStorePersistence.load(from: url)

    assertEqual(loaded.sessions.first?.id, .some("persisted"), "persisted store keeps session id")
    assertEqual(loaded.sessions.first?.status, .some(.waitingApproval), "persisted store keeps status")
    assertEqual(loaded.aggregateStatus, .waitingApproval, "persisted store keeps aggregate status")
    try? FileManager.default.removeItem(at: url)
}

try testSessionStorePersistenceRoundTripsJSON()
print("PASS: SessionStorePersistenceTests")

func testPersistingEventHandlerAppliesAndSavesEvents() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("cc-sentinel-persisting-handler-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: url) }

    let handler = PersistingEventHandler(storeURL: url)
    handler.handle(.init(
        kind: .sessionStart,
        sessionID: "persisting",
        source: .cli,
        cwd: "/repo"
    ))
    handler.handle(.init(
        kind: .permissionRequest,
        sessionID: "persisting",
        source: .cli,
        cwd: "/repo",
        toolName: "Bash",
        toolSummary: "command=pnpm test"
    ))

    let loaded = try SessionStorePersistence.load(from: url)
    assertEqual(loaded.aggregateStatus, .waitingApproval, "persisting handler saves aggregate status")
    assertEqual(loaded.sessions.first?.id, .some("persisting"), "persisting handler saves session id")
    assertEqual(loaded.sessions.first?.lastToolSummary, .some("command=pnpm test"), "persisting handler saves tool summary")
}

try testPersistingEventHandlerAppliesAndSavesEvents()
print("PASS: PersistingEventHandlerTests")

func testSessionStoreDumpShowsWaitingApprovalSession() {
    let store = SessionStore(sessions: [
        ClaudeSession(
            id: "s1",
            source: .vscode,
            cwd: "/repo",
            status: .waitingApproval,
            lastToolName: "Bash",
            lastToolSummary: "command=pnpm test",
            lastEventAt: Date(timeIntervalSince1970: 123),
            waitingSince: Date(timeIntervalSince1970: 123),
            approvalRequest: ApprovalRequest(
                toolName: "Bash",
                summary: "command=pnpm test",
                requestedAt: Date(timeIntervalSince1970: 123)
            )
        )
    ])

    let dump = SessionStoreDump.render(store: store)

    assertTrue(dump.contains("aggregate_status: waiting_approval"), "dump shows aggregate status")
    assertTrue(dump.contains("session_count: 1"), "dump shows session count")
    assertTrue(dump.contains("id: s1"), "dump shows session id")
    assertTrue(dump.contains("source: vscode"), "dump shows session source")
    assertTrue(dump.contains("status: waiting_approval"), "dump shows session status")
    assertTrue(dump.contains("tool: Bash"), "dump shows last tool")
    assertTrue(dump.contains("summary: command=pnpm test"), "dump shows safe summary")
    assertTrue(dump.contains("waiting_since: 1970-01-01T00:02:03Z"), "dump shows waiting timestamp")
}

testSessionStoreDumpShowsWaitingApprovalSession()
print("PASS: SessionStoreDumpTests")

func testApprovalFocusSelectsOldestWaitingApprovalRequest() {
    let store = SessionStore(sessions: [
        ClaudeSession(
            id: "later",
            source: .cli,
            cwd: "/repo/later",
            status: .waitingApproval,
            lastEventAt: Date(timeIntervalSince1970: 20),
            waitingSince: Date(timeIntervalSince1970: 20),
            approvalRequest: ApprovalRequest(
                toolName: "Edit",
                summary: "file_path=/repo/later.swift",
                requestedAt: Date(timeIntervalSince1970: 20)
            )
        ),
        ClaudeSession(
            id: "earlier",
            source: .vscode,
            cwd: "/repo",
            status: .waitingApproval,
            lastEventAt: Date(timeIntervalSince1970: 10),
            waitingSince: Date(timeIntervalSince1970: 10),
            approvalRequest: ApprovalRequest(
                toolName: "Bash",
                summary: "command=pnpm test",
                requestedAt: Date(timeIntervalSince1970: 10)
            )
        )
    ])

    let focus = ApprovalFocus.resolve(store: store)

    assertEqual(focus?.sessionID, .some("earlier"), "approval focus picks oldest waiting request")
    assertEqual(focus?.source, .some(.vscode), "approval focus keeps source")
    assertEqual(focus?.toolName, .some("Bash"), "approval focus keeps tool")
    assertEqual(focus?.summary, .some("command=pnpm test"), "approval focus keeps summary")
}

func testApprovalFocusIsNilWithoutWaitingApproval() {
    let store = SessionStore(sessions: [
        ClaudeSession(id: "running", source: .cli, cwd: "/repo", status: .running)
    ])

    assertEqual(ApprovalFocus.resolve(store: store), nil, "approval focus absent when no waiting approval exists")
}

testApprovalFocusSelectsOldestWaitingApprovalRequest()
testApprovalFocusIsNilWithoutWaitingApproval()
print("PASS: ApprovalFocusTests")

func testHookForwarderWritesFallbackWhenReceiverIsUnavailable() async throws {
    let temp = FileManager.default.temporaryDirectory
        .appendingPathComponent("cc-sentinel-\(UUID().uuidString)")
        .appendingPathExtension("jsonl")
    let data = #"{"hook_event_name":"SessionStart","session_id":"s1","cwd":"/repo"}"#.data(using: .utf8)!

    try await HookForwarder.forward(
        data: data,
        endpoint: URL(string: "http://127.0.0.1:1/events")!,
        fallbackURL: temp,
        timeout: 0.1
    )

    let saved = try String(contentsOf: temp, encoding: .utf8)
    assertTrue(saved.contains(#""session_id":"s1""#), "fallback file contains original event")
    try? FileManager.default.removeItem(at: temp)
}

try await testHookForwarderWritesFallbackWhenReceiverIsUnavailable()
print("PASS: HookForwarderTests")

func testEventReceiverAppliesHookEventsEndToEnd() async throws {
    let port = UInt16.random(in: 49152...65000)
    let endpoint = URL(string: "http://127.0.0.1:\(port)/events")!
    let fallbackURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("cc-sentinel-e2e-\(UUID().uuidString)")
        .appendingPathExtension("jsonl")
    let storeBox = LockedSessionStore()

    let receiver = try EventReceiver(port: port) { event in
        storeBox.apply(event)
    }
    receiver.start()
    defer {
        receiver.stop()
        try? FileManager.default.removeItem(at: fallbackURL)
    }

    try await Task.sleep(nanoseconds: 150_000_000)

    let sessionStart = #"{"hook_event_name":"SessionStart","session_id":"e2e","cwd":"/repo"}"#.data(using: .utf8)!
    try await HookForwarder.forward(data: sessionStart, endpoint: endpoint, fallbackURL: fallbackURL)
    try await waitUntil("session start reaches receiver") {
        storeBox.snapshot().sessions.first?.status == .running
    }

    let permissionRequest = #"{"hook_event_name":"PermissionRequest","session_id":"e2e","cwd":"/repo","tool_name":"Bash","tool_input":{"command":"pnpm test"}}"#.data(using: .utf8)!
    try await HookForwarder.forward(data: permissionRequest, endpoint: endpoint, fallbackURL: fallbackURL)
    try await waitUntil("permission request reaches receiver") {
        storeBox.snapshot().aggregateStatus == .waitingApproval
    }

    let postToolUse = #"{"hook_event_name":"PostToolUse","session_id":"e2e","cwd":"/repo","tool_name":"Bash"}"#.data(using: .utf8)!
    try await HookForwarder.forward(data: postToolUse, endpoint: endpoint, fallbackURL: fallbackURL)
    try await waitUntil("post tool use clears approval") {
        let store = storeBox.snapshot()
        return store.sessions.first?.status == .running && store.sessions.first?.approvalRequest == nil
    }
}

final class LockedSessionStore: @unchecked Sendable {
    private let lock = NSLock()
    private var store = SessionStore()

    func apply(_ event: NormalizedEvent) {
        lock.lock()
        store.apply(event)
        lock.unlock()
    }

    func snapshot() -> SessionStore {
        lock.lock()
        let snapshot = store
        lock.unlock()
        return snapshot
    }
}

func waitUntil(
    _ description: String,
    timeoutNanoseconds: UInt64 = 2_000_000_000,
    pollNanoseconds: UInt64 = 50_000_000,
    condition: () -> Bool
) async throws {
    let started = DispatchTime.now().uptimeNanoseconds
    while DispatchTime.now().uptimeNanoseconds - started < timeoutNanoseconds {
        if condition() {
            return
        }
        try await Task.sleep(nanoseconds: pollNanoseconds)
    }
    print("FAIL: Timed out waiting for \(description).")
    Foundation.exit(1)
}

try await testEventReceiverAppliesHookEventsEndToEnd()
print("PASS: EventReceiverE2ETests")

func testWrapperSeparatesRealClaudeBinaryFromArguments() {
    let parsed = WrapperArguments.parse(["/usr/local/bin/claude", "--print", "hello"])

    assertEqual(parsed?.realClaudeBinary, "/usr/local/bin/claude", "wrapper real binary")
    assertEqual(parsed?.forwardedArguments, ["--print", "hello"], "wrapper forwarded arguments")
}

func testWrapperProcessStartUsesVscodeSource() throws {
    let json = """
    {"hook_event_name":"WrapperProcessStart","session_id":"wrapper-123","cwd":"/repo","source":"vscode"}
    """.data(using: .utf8)!

    let event = try EventNormalizer.normalize(json)

    assertEqual(event.kind, .wrapperProcessStart, "wrapper process start kind")
    assertEqual(event.source, .vscode, "wrapper process source")
}

testWrapperSeparatesRealClaudeBinaryFromArguments()
try testWrapperProcessStartUsesVscodeSource()
print("PASS: WrapperTests")

func testInstallerPreservesUnrelatedSettingsAndAddsManagedHook() throws {
    let existing = #"{"theme":"dark","hooks":{"Stop":[{"command":"echo keep"}]}}"#
    let result = try HookSettingsInstaller.previewInstall(
        existingSettingsJSON: existing,
        hookBinaryPath: "/opt/cc/cc-sentinel-hook"
    )

    assertTrue(result.previewJSON.contains(#""theme""#), "installer preserves unrelated settings")
    assertTrue(result.previewJSON.contains("echo keep"), "installer preserves unmarked hooks")
    assertTrue(result.previewJSON.contains("cc-sentinel-hook"), "installer adds sentinel hook")
    assertTrue(result.previewJSON.contains("cc-sentinel-managed"), "installer marks managed hooks")
}

func testInstallerReplacesOldManagedHookPath() throws {
    let existing = """
    {"hooks":{"PermissionRequest":[{"command":"/old/cc-sentinel-hook","cc-sentinel-managed":true},{"command":"echo keep"}]}}
    """

    let result = try HookSettingsInstaller.previewInstall(
        existingSettingsJSON: existing,
        hookBinaryPath: "/new/cc-sentinel-hook"
    )

    assertTrue(result.previewJSON.contains("/new/cc-sentinel-hook"), "installer writes new managed hook path")
    assertTrue(!result.previewJSON.contains("/old/cc-sentinel-hook"), "installer removes old managed hook path")
    assertTrue(result.previewJSON.contains("echo keep"), "installer keeps unmanaged hook")
}

func testUninstallRemovesOnlyManagedHook() throws {
    let existing = """
    {"hooks":{"Stop":[{"command":"echo keep"},{"command":"/opt/cc/cc-sentinel-hook","cc-sentinel-managed":true}]}}
    """

    let result = try HookSettingsInstaller.previewUninstall(existingSettingsJSON: existing)

    assertTrue(result.previewJSON.contains("echo keep"), "uninstall keeps unmarked hook")
    assertTrue(!result.previewJSON.contains("cc-sentinel-hook"), "uninstall removes managed hook")
    assertTrue(!result.previewJSON.contains("cc-sentinel-managed"), "uninstall removes managed marker")
}

func testInstallerApplyCreatesBackupAndWritesPreview() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("cc-sentinel-settings-\(UUID().uuidString)", isDirectory: true)
    let settingsURL = directory.appendingPathComponent("settings.json")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try #"{"theme":"dark"}"#.write(to: settingsURL, atomically: true, encoding: .utf8)

    let backupURL = try HookSettingsInstaller.applyInstall(
        settingsURL: settingsURL,
        hookBinaryPath: "/opt/cc/cc-sentinel-hook",
        timestamp: "20260624-120000"
    )

    let updated = try String(contentsOf: settingsURL, encoding: .utf8)
    let backup = try String(contentsOf: backupURL, encoding: .utf8)

    assertTrue(updated.contains("cc-sentinel-hook"), "apply install writes managed hook")
    assertTrue(updated.contains(#""theme""#), "apply install keeps existing settings")
    assertEqual(backup, #"{"theme":"dark"}"#, "apply install writes backup")
    try? FileManager.default.removeItem(at: directory)
}

func testInstallerApplyUninstallCreatesBackupAndRemovesManagedHook() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("cc-sentinel-settings-\(UUID().uuidString)", isDirectory: true)
    let settingsURL = directory.appendingPathComponent("settings.json")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try """
    {"hooks":{"Stop":[{"command":"echo keep"},{"command":"/opt/cc/cc-sentinel-hook","cc-sentinel-managed":true}]}}
    """.write(to: settingsURL, atomically: true, encoding: .utf8)

    let backupURL = try HookSettingsInstaller.applyUninstall(
        settingsURL: settingsURL,
        timestamp: "20260624-120001"
    )

    let updated = try String(contentsOf: settingsURL, encoding: .utf8)
    let backup = try String(contentsOf: backupURL, encoding: .utf8)

    assertTrue(updated.contains("echo keep"), "apply uninstall keeps user hook")
    assertTrue(!updated.contains("cc-sentinel-hook"), "apply uninstall removes managed hook")
    assertTrue(backup.contains("cc-sentinel-managed"), "apply uninstall writes pre-change backup")
    try? FileManager.default.removeItem(at: directory)
}

try testInstallerPreservesUnrelatedSettingsAndAddsManagedHook()
try testInstallerReplacesOldManagedHookPath()
try testUninstallRemovesOnlyManagedHook()
try testInstallerApplyCreatesBackupAndWritesPreview()
try testInstallerApplyUninstallCreatesBackupAndRemovesManagedHook()
print("PASS: HookSettingsInstallerTests")

func testLocalizationFilesCoverAllKeys() throws {
    let keys = Set(L10nKey.allCases.map(\.rawValue))
    let paths = [
        "Sources/CCSentinelApp/Resources/en.lproj/Localizable.strings",
        "Sources/CCSentinelApp/Resources/zh-Hans.lproj/Localizable.strings"
    ]

    for path in paths {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        for key in keys {
            assertTrue(text.contains(#""\#(key)""#), "\(path) contains \(key)")
        }
    }
}

try testLocalizationFilesCoverAllKeys()
print("PASS: LocalizationCoverageTests")

func testDefaultPolicyAsksForEveryTool() {
    let decision = ApprovalPolicy.default.evaluate(
        tool: "Bash",
        command: "pnpm test",
        cwd: "/repo",
        workspace: "/repo"
    )

    assertEqual(decision, .ask, "default policy asks")
}

func testLowRiskReadCanBeAllowedWhenUserOptedIn() {
    var policy = ApprovalPolicy.default
    policy.allowWorkspaceReads = true

    let decision = policy.evaluate(
        tool: "Read",
        command: "README.md",
        cwd: "/repo",
        workspace: "/repo"
    )

    assertEqual(decision, .allow, "opted-in read is allowed")
}

func testGitPushIsDeniedByDefault() {
    let decision = ApprovalPolicy.default.evaluate(
        tool: "Bash",
        command: "git push origin main",
        cwd: "/repo",
        workspace: "/repo"
    )

    assertEqual(decision, .deny, "git push is denied")
}

func testWorkspacePrefixSiblingIsNotAllowed() {
    let policy = ApprovalPolicy(allowWorkspaceReads: true, allowWorkspaceEdits: false)
    let decision = policy.evaluate(
        tool: "Read",
        command: "/repo-sibling/README.md",
        cwd: "/repo",
        workspace: "/repo"
    )

    assertEqual(decision, .ask, "workspace prefix sibling is not allowed")
}

func testAutoApprovalSettingsDefaultToDisabled() {
    assertEqual(AutoApprovalSettings.default.enabled, false, "auto approval defaults disabled")
}

func testAutoApprovalDoesNothingWhenDisabled() throws {
    let input = """
    {"hook_event_name":"PermissionRequest","session_id":"auto-disabled","cwd":"/repo","tool_name":"Read","tool_input":{"file_path":"/repo/README.md"}}
    """.data(using: .utf8)!
    var stats = AutoApprovalStats()

    let result = try AutoApprovalHookDecision.evaluate(
        inputData: input,
        settings: .default,
        stats: &stats,
        now: Date(timeIntervalSince1970: 1_800_000_000)
    )

    assertEqual(result.outputJSON, nil, "disabled auto approval has no hook output")
    assertEqual(stats.totalCount, 0, "disabled auto approval does not record stats")
}

func testAutoApprovalAllowsWorkspaceReadAndRecordsStats() throws {
    let input = """
    {"hook_event_name":"PermissionRequest","session_id":"auto-read","cwd":"/repo","tool_name":"Read","tool_input":{"file_path":"/repo/README.md"}}
    """.data(using: .utf8)!
    let settings = AutoApprovalSettings(
        enabled: true,
        policy: ApprovalPolicy(allowWorkspaceReads: true, allowWorkspaceEdits: false),
        workspace: "/repo"
    )
    var stats = AutoApprovalStats()

    let result = try AutoApprovalHookDecision.evaluate(
        inputData: input,
        settings: settings,
        stats: &stats,
        now: Date(timeIntervalSince1970: 1_800_000_000)
    )

    assertEqual(result.decision, .allow, "workspace read is allowed")
    assertTrue(result.outputJSON?.contains(#""hookEventName":"PermissionRequest""#) == true, "allow output names permission request")
    assertTrue(result.outputJSON?.contains(#""decision":{"behavior":"allow"}"#) == true, "allow output uses permission request decision object")
    assertTrue(result.outputJSON?.contains(#""behavior":"allow""#) == true, "allow output grants permission")
    assertTrue(result.outputJSON?.contains("updatedInput") == false, "allow output does not replace input")
    assertEqual(stats.totalCount, 1, "allowed approval increments total")
    assertEqual(stats.todayCount(now: Date(timeIntervalSince1970: 1_800_000_100)), 1, "allowed approval increments today")
    assertEqual(stats.lastEvent?.toolName, .some("Read"), "allowed approval records tool")
}

func testAutoApprovalDoesNotAllowOutsideWorkspaceRead() throws {
    let input = """
    {"hook_event_name":"PermissionRequest","session_id":"auto-outside","cwd":"/repo","tool_name":"Read","tool_input":{"file_path":"/etc/passwd"}}
    """.data(using: .utf8)!
    let settings = AutoApprovalSettings(
        enabled: true,
        policy: ApprovalPolicy(allowWorkspaceReads: true, allowWorkspaceEdits: false),
        workspace: "/repo"
    )
    var stats = AutoApprovalStats()

    let result = try AutoApprovalHookDecision.evaluate(
        inputData: input,
        settings: settings,
        stats: &stats,
        now: Date(timeIntervalSince1970: 1_800_000_000)
    )

    assertEqual(result.decision, .ask, "outside workspace read is not auto-approved")
    assertEqual(result.outputJSON, nil, "outside workspace read has no hook output")
    assertEqual(stats.totalCount, 0, "outside workspace read does not increment stats")
}

func testAutoApprovalStatsPersistenceRoundTripsJSON() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("cc-sentinel-auto-stats-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: url) }
    var stats = AutoApprovalStats()
    stats.record(
        toolName: "Read",
        summary: "/repo/README.md",
        workspace: "/repo",
        at: Date(timeIntervalSince1970: 1_800_000_000)
    )

    try AutoApprovalStatsPersistence.save(stats, to: url)
    let loaded = try AutoApprovalStatsPersistence.load(from: url)

    assertEqual(loaded.totalCount, 1, "stats persistence keeps total")
    assertEqual(loaded.lastEvent?.workspace, .some("/repo"), "stats persistence keeps workspace")
}

func testRecordingAutoApprovalIncrementsTodayAndTotal() {
    var stats = AutoApprovalStats()
    stats.record(
        toolName: "Read",
        summary: "README.md",
        workspace: "/repo",
        at: Date(timeIntervalSince1970: 1_800_000_000)
    )

    assertEqual(stats.todayCount(now: Date(timeIntervalSince1970: 1_800_000_100)), 1, "today count increments")
    assertEqual(stats.totalCount, 1, "total count increments")
    assertEqual(stats.lastEvent?.toolName, .some("Read"), "last event is recorded")
}

testDefaultPolicyAsksForEveryTool()
testLowRiskReadCanBeAllowedWhenUserOptedIn()
testGitPushIsDeniedByDefault()
testWorkspacePrefixSiblingIsNotAllowed()
testAutoApprovalSettingsDefaultToDisabled()
try testAutoApprovalDoesNothingWhenDisabled()
try testAutoApprovalAllowsWorkspaceReadAndRecordsStats()
try testAutoApprovalDoesNotAllowOutsideWorkspaceRead()
try testAutoApprovalStatsPersistenceRoundTripsJSON()
testRecordingAutoApprovalIncrementsTodayAndTotal()
print("PASS: ApprovalPolicyTests")
print("PASS: AutoApprovalStatsTests")
