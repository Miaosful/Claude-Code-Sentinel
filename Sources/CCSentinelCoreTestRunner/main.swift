import Foundation
import CCSentinelCore

let processEnvironment = ProcessInfo.processInfo.environment

if processEnvironment["CC_SENTINEL_PID_SMOKE_PARENT"] == "1" {
    guard let runner = processEnvironment["CC_SENTINEL_TEST_RUNNER"] else {
        FileHandle.standardError.write(Data("missing test runner path\n".utf8))
        Foundation.exit(2)
    }

    let child = Process()
    child.executableURL = URL(fileURLWithPath: runner)
    var childEnvironment = processEnvironment
    childEnvironment.removeValue(forKey: "CC_SENTINEL_PID_SMOKE_PARENT")
    childEnvironment["CC_SENTINEL_PID_SMOKE_CHILD"] = "1"
    child.environment = childEnvironment

    let output = Pipe()
    let error = Pipe()
    child.standardOutput = output
    child.standardError = error
    try child.run()
    let outputData = output.fileHandleForReading.readDataToEndOfFile()
    let errorData = error.fileHandleForReading.readDataToEndOfFile()
    child.waitUntilExit()

    FileHandle.standardOutput.write(outputData)
    FileHandle.standardError.write(errorData)
    Foundation.exit(child.terminationStatus)
}

if processEnvironment["CC_SENTINEL_PID_SMOKE_CHILD"] == "1" {
    if let pid = ClaudeProcessDetector.nearestClaudeAncestorPIDFromSystem() {
        print(pid)
        Foundation.exit(0)
    }
    FileHandle.standardError.write(Data("missing claude ancestor\n".utf8))
    Foundation.exit(3)
}

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

func parseJSONObject(_ json: String) throws -> [String: Any] {
    guard
        let data = json.data(using: .utf8),
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        print("FAIL: Could not parse JSON object.")
        Foundation.exit(1)
    }
    return object
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

func testProcessDetectorRecognizesClaudeCLIBinary() {
    let snapshot = ClaudeProcessDetector.detect(
        entries: [
            ProcessListEntry(pid: 101, parentPID: 1, command: "/opt/homebrew/bin/claude --resume")
        ],
        now: Date(timeIntervalSince1970: 200)
    )

    assertEqual(snapshot.processes.count, 1, "detector finds Claude CLI process")
    assertEqual(snapshot.processes.first?.pid, .some(101), "detector keeps process id")
    assertEqual(snapshot.processes.first?.source, .some(.cli), "detector marks direct CLI process")
}

func testProcessDetectorMarksVscodeDescendantAsVscodeSource() {
    let snapshot = ClaudeProcessDetector.detect(
        entries: [
            ProcessListEntry(pid: 10, parentPID: 1, command: "/Applications/Visual Studio Code.app/Contents/MacOS/Electron"),
            ProcessListEntry(pid: 11, parentPID: 10, command: "/bin/zsh -l"),
            ProcessListEntry(pid: 12, parentPID: 11, command: "/usr/local/bin/node /Users/example/.npm/_npx/@anthropic-ai/claude-code/cli.js")
        ],
        now: Date(timeIntervalSince1970: 201)
    )

    assertEqual(snapshot.processes.count, 1, "detector finds Claude Code under VS Code")
    assertEqual(snapshot.processes.first?.pid, .some(12), "detector keeps VS Code child process id")
    assertEqual(snapshot.processes.first?.source, .some(.vscode), "detector marks VS Code descendant")
}

func testProcessDetectorKeepsMultipleClaudeProcessesInSameVSCodeWindowForPIDTracking() {
    let snapshot = ClaudeProcessDetector.detect(
        entries: [
            ProcessListEntry(pid: 10, parentPID: 1, command: "/Applications/Visual Studio Code.app/Contents/MacOS/Electron"),
            ProcessListEntry(pid: 11, parentPID: 10, command: "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper.app/Contents/MacOS/Code Helper"),
            ProcessListEntry(pid: 20, parentPID: 11, command: "/Users/example/.vscode/extensions/anthropic.claude-code/resources/native-binary/claude --output-format stream-json"),
            ProcessListEntry(pid: 21, parentPID: 11, command: "/Users/example/.vscode/extensions/anthropic.claude-code/resources/native-binary/claude --output-format stream-json")
        ],
        now: Date(timeIntervalSince1970: 202)
    )

    assertEqual(snapshot.processes.map(\.pid), [20, 21], "detector keeps all VS Code Claude pids for stale tracking")
    assertEqual(snapshot.processes.map(\.source), [.vscode, .vscode], "detector marks both processes as VS Code")
}

func testProcessDetectorKeepsIndependentCLIProcessesSeparate() {
    let snapshot = ClaudeProcessDetector.detect(
        entries: [
            ProcessListEntry(pid: 30, parentPID: 1, command: "/opt/homebrew/bin/claude --resume"),
            ProcessListEntry(pid: 31, parentPID: 1, command: "/opt/homebrew/bin/claude --continue")
        ],
        now: Date(timeIntervalSince1970: 203)
    )

    assertEqual(snapshot.processes.count, 2, "detector keeps independent CLI Claude processes separate")
}

func testProcessDetectorFindsNearestClaudeAncestorForHookProcess() {
    let ancestorPID = ClaudeProcessDetector.nearestClaudeAncestorPID(
        for: 303,
        entries: [
            ProcessListEntry(pid: 300, parentPID: 1, command: "/Applications/Visual Studio Code.app/Contents/MacOS/Electron"),
            ProcessListEntry(pid: 301, parentPID: 300, command: "/Users/example/.vscode/extensions/anthropic.claude-code/resources/native-binary/claude"),
            ProcessListEntry(pid: 302, parentPID: 301, command: "/Users/example/Documents/vibe projects/CC Sentinel/dist/CCSentinelApp.app/Contents/MacOS/cc-sentinel-wrapper"),
            ProcessListEntry(pid: 303, parentPID: 301, command: "/Users/example/Documents/vibe projects/CC Sentinel/dist/CCSentinelApp.app/Contents/MacOS/cc-sentinel-hook")
        ]
    )

    assertEqual(ancestorPID, .some(301), "hook ancestry resolves to nearest real Claude process")
}

func testProcessDetectorFindsNearestClaudeAncestorFromLightweightProcessLookup() {
    let ancestors: [Int32: ProcessIdentity] = [
        40: ProcessIdentity(pid: 40, parentPID: 30, executablePath: "/Users/example/bin/cc-sentinel-hook"),
        30: ProcessIdentity(pid: 30, parentPID: 20, executablePath: "/Users/example/bin/cc-sentinel-wrapper"),
        20: ProcessIdentity(pid: 20, parentPID: 10, executablePath: "/Users/example/.vscode/extensions/anthropic.claude-code/resources/native-binary/claude"),
        10: ProcessIdentity(pid: 10, parentPID: 1, executablePath: "/bin/zsh")
    ]

    let ancestorPID = ClaudeProcessDetector.nearestClaudeAncestorPID(for: 40) { pid in
        ancestors[pid]
    }

    assertEqual(ancestorPID, .some(20), "detector finds Claude ancestor without a full process-list scan")
}

func testLightweightAncestorLookupWorksAgainstRealProcessTree() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("pid-smoke-\(UUID().uuidString)", isDirectory: true)
    let fakeClaudeURL = directory.appendingPathComponent("claude")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: URL(fileURLWithPath: CommandLine.arguments[0]), to: fakeClaudeURL)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeClaudeURL.path)
    defer { try? FileManager.default.removeItem(at: directory) }

    let process = Process()
    process.executableURL = fakeClaudeURL
    var environment = ProcessInfo.processInfo.environment
    environment["CC_SENTINEL_PID_SMOKE_PARENT"] = "1"
    environment["CC_SENTINEL_TEST_RUNNER"] = CommandLine.arguments[0]
    process.environment = environment

    let output = Pipe()
    process.standardOutput = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    let stdout = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    assertEqual(process.terminationStatus, 0, "lightweight lookup finds fake Claude parent in a real process tree")
    assertTrue(Int32(stdout ?? "") != nil, "lightweight lookup prints ancestor pid")
}

func testProcessFallbackMakesEmptyStoreLookRunning() {
    let store = SessionStore()
    let snapshot = ClaudeProcessSnapshot(
        scannedAt: Date(timeIntervalSince1970: 300),
        processes: [
            ClaudeProcess(pid: 22, parentPID: 11, source: .vscode, command: "/usr/local/bin/claude")
        ]
    )

    let visibleStore = store.includingProcessFallback(snapshot)

    assertEqual(visibleStore.aggregateStatus, .running, "process fallback makes empty store running")
    assertEqual(visibleStore.sessions.first?.id, .some("process-22"), "process fallback creates stable session id")
    assertEqual(visibleStore.sessions.first?.source, .some(.vscode), "process fallback keeps detected source")
}

func testProcessFallbackCollapsesMultipleVSCodeProcessesIntoOneVisibleSession() {
    let snapshot = ClaudeProcessSnapshot(
        scannedAt: Date(timeIntervalSince1970: 300),
        processes: [
            ClaudeProcess(pid: 20, parentPID: 11, source: .vscode, command: "/Users/example/.vscode/extensions/anthropic.claude-code/resources/native-binary/claude --output-format stream-json"),
            ClaudeProcess(pid: 21, parentPID: 11, source: .vscode, command: "/Users/example/.vscode/extensions/anthropic.claude-code/resources/native-binary/claude --output-format stream-json")
        ]
    )

    let visibleStore = SessionStore().includingProcessFallback(snapshot)

    assertEqual(visibleStore.sessions.count, 1, "process fallback collapses VS Code process siblings into one visible session")
    assertEqual(visibleStore.sessions.first?.source, .some(.vscode), "collapsed fallback keeps VS Code source")
}

func testProcessFallbackWorksWhenNoHookStoreExistsYet() {
    let snapshot = ClaudeProcessSnapshot(
        scannedAt: Date(timeIntervalSince1970: 301),
        processes: [
            ClaudeProcess(pid: 23, parentPID: 11, source: .cli, command: "/opt/homebrew/bin/claude")
        ]
    )

    let visibleStore = SessionStore().includingProcessFallback(snapshot)

    assertEqual(visibleStore.aggregateStatus, .running, "process fallback works before any hook events exist")
    assertEqual(visibleStore.sessions.first?.id, .some("process-23"), "process fallback creates first visible session")
}

func testHookSessionsTakePrecedenceOverProcessFallback() {
    let store = SessionStore(sessions: [
        ClaudeSession(
            id: "hooked",
            source: .cli,
            cwd: "/repo",
            status: .waitingApproval,
            lastEventAt: Date(timeIntervalSince1970: 100)
        )
    ])
    let snapshot = ClaudeProcessSnapshot(
        scannedAt: Date(timeIntervalSince1970: 300),
        processes: [
            ClaudeProcess(pid: 22, parentPID: 11, source: .vscode, command: "/usr/local/bin/claude")
        ]
    )

    let visibleStore = store.includingProcessFallback(snapshot)

    assertEqual(visibleStore.sessions.count, 1, "active hook sessions suppress process fallback duplicates")
    assertEqual(visibleStore.aggregateStatus, .waitingApproval, "hook waiting approval beats process fallback")
}

func testProcessFallbackInfersUnknownHookSessionSourceByPID() {
    let store = SessionStore(sessions: [
        ClaudeSession(
            id: "hooked",
            source: .unknown,
            cwd: "/repo",
            status: .running,
            claudePID: 22,
            lastEventAt: Date(timeIntervalSince1970: 100)
        )
    ])
    let snapshot = ClaudeProcessSnapshot(
        scannedAt: Date(timeIntervalSince1970: 300),
        processes: [
            ClaudeProcess(pid: 22, parentPID: 11, source: .vscode, command: "/usr/local/bin/claude")
        ]
    )

    let visibleStore = store.includingProcessFallback(snapshot)

    assertEqual(visibleStore.sessions.first?.source, .some(.vscode), "process metadata fills unknown hook session source")
}

func testProcessFallbackHidesInactiveHookHistoryWhenNoProcessesExist() {
    let store = SessionStore(sessions: [
        ClaudeSession(
            id: "ended",
            source: .unknown,
            cwd: "/repo",
            status: .ended,
            lastEventAt: Date(timeIntervalSince1970: 100)
        ),
        ClaudeSession(
            id: "stale",
            source: .unknown,
            cwd: "/repo",
            status: .stale,
            lastEventAt: Date(timeIntervalSince1970: 101)
        )
    ])

    let visibleStore = store.includingProcessFallback(ClaudeProcessSnapshot(
        scannedAt: Date(timeIntervalSince1970: 300),
        processes: []
    ))

    assertEqual(visibleStore.sessions.count, 0, "inactive hook history is hidden from the visible store")
    assertEqual(visibleStore.aggregateStatus, .idle, "inactive hook history does not degrade visible status")
}

testProcessDetectorRecognizesClaudeCLIBinary()
testProcessDetectorMarksVscodeDescendantAsVscodeSource()
testProcessDetectorKeepsMultipleClaudeProcessesInSameVSCodeWindowForPIDTracking()
testProcessDetectorKeepsIndependentCLIProcessesSeparate()
testProcessDetectorFindsNearestClaudeAncestorForHookProcess()
testProcessDetectorFindsNearestClaudeAncestorFromLightweightProcessLookup()
try testLightweightAncestorLookupWorksAgainstRealProcessTree()
testProcessFallbackMakesEmptyStoreLookRunning()
testProcessFallbackCollapsesMultipleVSCodeProcessesIntoOneVisibleSession()
testProcessFallbackWorksWhenNoHookStoreExistsYet()
testHookSessionsTakePrecedenceOverProcessFallback()
testProcessFallbackInfersUnknownHookSessionSourceByPID()
testProcessFallbackHidesInactiveHookHistoryWhenNoProcessesExist()
print("PASS: ClaudeProcessDetectorTests")

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

func testClaudePIDNormalizesFromHookPayload() throws {
    let json = """
    {"hook_event_name":"PermissionRequest","session_id":"s1","cwd":"/repo","tool_name":"Bash","claude_pid":4242,"tool_input":{"command":"pnpm test"}}
    """.data(using: .utf8)!

    let event = try EventNormalizer.normalize(json)

    assertEqual(event.claudePID, .some(4242), "normalizer preserves Claude process id")
}

func testHookPayloadEnricherAddsClaudePID() throws {
    let input = #"{"hook_event_name":"PermissionRequest","session_id":"s1","cwd":"/repo"}"#.data(using: .utf8)!
    let enriched = try HookPayloadEnricher.addClaudePID(4242, to: input)
    let object = try JSONSerialization.jsonObject(with: enriched) as? [String: Any]

    assertEqual(object?["session_id"] as? String, .some("s1"), "enricher preserves session id")
    assertEqual(object?["claude_pid"] as? Int, .some(4242), "enricher writes Claude process id")
}

func testRedactsTokenLikeValues() {
    let input = "curl -H Authorization: Bearer sk-live-secret-value https://example.test"
    let redacted = Redactor.safeSummary(input)

    assertTrue(!redacted.contains("sk-live-secret-value"), "redactor removes secret token")
    assertTrue(redacted.contains("[redacted]"), "redactor marks redacted content")
}

try testPermissionRequestBecomesWaitingApprovalEvent()
try testReadPathBecomesToolCommand()
try testClaudePIDNormalizesFromHookPayload()
try testHookPayloadEnricherAddsClaudePID()
testRedactsTokenLikeValues()
print("PASS: EventNormalizerTests")
print("PASS: RedactorTests")

func testAdditionalHookEventsNormalize() throws {
    let cases: [(String, NormalizedEventKind)] = [
        ("PreToolUse", .preToolUse),
        ("PermissionDenied", .permissionDenied),
        ("StopFailure", .stopFailure),
        ("ConfigChange", .configChange)
    ]

    for (hookName, expectedKind) in cases {
        let json = """
        {"hook_event_name":"\(hookName)","session_id":"s1","cwd":"/repo"}
        """.data(using: .utf8)!

        let event = try EventNormalizer.normalize(json)
        assertEqual(event.kind, expectedKind, "\(hookName) maps to normalized event kind")
    }
}

try testAdditionalHookEventsNormalize()
print("PASS: ExpandedEventNormalizerTests")

func testPermissionRequestMarksSessionWaitingApproval() {
    var store = SessionStore()
    store.apply(.init(
        kind: .permissionRequest,
        sessionID: "s1",
        source: .vscode,
        cwd: "/repo",
        claudePID: 4242,
        toolName: "Bash",
        toolSummary: "command=pnpm test"
    ))

    assertEqual(store.sessions.first?.status, .some(.waitingApproval), "permission request marks waiting approval")
    assertEqual(store.sessions.first?.claudePID, .some(4242), "permission request records Claude process id")
    assertEqual(store.aggregateStatus, .waitingApproval, "permission request updates aggregate status")
}

func testPostToolUseClearsWaitingApproval() {
    var store = SessionStore()
    store.apply(.init(kind: .permissionRequest, sessionID: "s1", source: .vscode, cwd: "/repo", toolName: "Bash"))
    store.apply(.init(kind: .postToolUse, sessionID: "s1", source: .vscode, cwd: "/repo", toolName: "Bash"))

    assertEqual(store.sessions.first?.status, .some(.running), "post tool use clears waiting approval")
    assertEqual(store.sessions.first?.approvalRequest, nil, "post tool use clears approval request")
}

func testNotificationDoesNotOverwritePermissionRequestApprovalState() {
    var store = SessionStore()
    store.apply(.init(
        kind: .permissionRequest,
        sessionID: "s1",
        source: .vscode,
        cwd: "/repo",
        toolName: "Bash",
        toolSummary: "command=pnpm test"
    ))
    store.apply(.init(
        kind: .notification,
        sessionID: "s1",
        source: .vscode,
        cwd: "/repo"
    ))

    assertEqual(store.sessions.first?.status, .some(.waitingApproval), "notification keeps waiting approval status")
    assertEqual(store.sessions.first?.approvalRequest?.toolName, .some("Bash"), "notification preserves richer tool name")
    assertEqual(store.sessions.first?.approvalRequest?.summary, .some("command=pnpm test"), "notification preserves richer summary")
}

func testExpandedLifecycleEventsUpdateSessionState() {
    var store = SessionStore()
    store.apply(.init(kind: .sessionStart, sessionID: "s1", source: .cli, cwd: "/repo"))
    store.apply(.init(kind: .permissionRequest, sessionID: "s1", source: .cli, cwd: "/repo", toolName: "Bash"))
    store.apply(.init(kind: .preToolUse, sessionID: "s1", source: .cli, cwd: "/repo", toolName: "Bash"))

    assertEqual(store.sessions.first?.status, .some(.running), "pre tool use keeps session running")
    assertEqual(store.sessions.first?.approvalRequest, nil, "pre tool use clears approval state")

    store.apply(.init(kind: .permissionDenied, sessionID: "s1", source: .cli, cwd: "/repo", toolName: "Bash"))
    assertEqual(store.sessions.first?.status, .some(.running), "permission denied keeps session active")
    assertEqual(store.sessions.first?.approvalRequest, nil, "permission denied clears approval state")

    store.apply(.init(kind: .stopFailure, sessionID: "s1", source: .cli, cwd: "/repo"))
    assertEqual(store.sessions.first?.status, .some(.error), "stop failure marks the session error")

    store.apply(.init(kind: .configChange, sessionID: "s1", source: .cli, cwd: "/repo"))
    assertEqual(store.sessions.first?.status, .some(.running), "config change keeps the session active")
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

func testWaitingApprovalDoesNotBecomeStaleWhileItsClaudeProcessIsActive() {
    var store = SessionStore(sessions: [
        ClaudeSession(
            id: "s1",
            source: .unknown,
            cwd: "/repo",
            status: .waitingApproval,
            claudePID: 42,
            lastEventAt: Date(timeIntervalSince1970: 10),
            waitingSince: Date(timeIntervalSince1970: 10),
            approvalRequest: ApprovalRequest(
                toolName: "Bash",
                summary: "command=find .",
                requestedAt: Date(timeIntervalSince1970: 10)
            )
        )
    ])

    store.markStale(
        now: Date(timeIntervalSince1970: 100),
        timeout: 30,
        activeClaudeProcessIDs: [42]
    )

    assertEqual(store.sessions.first?.status, .some(.waitingApproval), "active Claude process keeps pending approval visible")
    assertEqual(store.aggregateStatus, .waitingApproval, "pending approval still controls aggregate status")
}

func testWaitingApprovalBecomesStaleWhenOnlyUnrelatedClaudeProcessIsActive() {
    var store = SessionStore(sessions: [
        ClaudeSession(
            id: "s1",
            source: .cli,
            cwd: "/tmp/demo",
            status: .waitingApproval,
            claudePID: 42,
            lastEventAt: Date(timeIntervalSince1970: 10),
            waitingSince: Date(timeIntervalSince1970: 10),
            approvalRequest: ApprovalRequest(
                toolName: "Bash",
                summary: "command=echo hi",
                requestedAt: Date(timeIntervalSince1970: 10)
            )
        )
    ])

    store.markStale(
        now: Date(timeIntervalSince1970: 100),
        timeout: 30,
        activeClaudeProcessIDs: [99]
    )

    assertEqual(store.sessions.first?.status, .some(.stale), "unrelated Claude process does not keep old approval visible")
    assertEqual(store.aggregateStatus, .degraded, "stale orphaned approval degrades aggregate status")
}

func testPIDLessWaitingApprovalUsesFallbackRevivalTimeout() {
    var store = SessionStore(sessions: [
        ClaudeSession(
            id: "legacy",
            source: .cli,
            cwd: "/tmp/demo",
            status: .waitingApproval,
            lastEventAt: Date(timeIntervalSince1970: 10),
            waitingSince: Date(timeIntervalSince1970: 10),
            approvalRequest: ApprovalRequest(
                toolName: "Bash",
                summary: "command=echo hi",
                requestedAt: Date(timeIntervalSince1970: 10)
            )
        )
    ])

    store.markStale(
        now: Date(timeIntervalSince1970: 400),
        timeout: 30,
        pendingApprovalRevivalTimeout: 300,
        activeClaudeProcessIDs: [99]
    )

    assertEqual(store.sessions.first?.status, .some(.stale), "legacy approval without pid falls back to bounded protection")
}

func testRecentStaleApprovalRevivesWhileItsClaudeProcessIsActive() {
    var store = SessionStore(sessions: [
        ClaudeSession(
            id: "s1",
            source: .unknown,
            cwd: "/repo",
            status: .stale,
            claudePID: 42,
            lastEventAt: Date(timeIntervalSince1970: 100),
            waitingSince: Date(timeIntervalSince1970: 100),
            approvalRequest: ApprovalRequest(
                toolName: "Bash",
                summary: "command=find .",
                requestedAt: Date(timeIntervalSince1970: 100)
            )
        )
    ])

    store.markStale(
        now: Date(timeIntervalSince1970: 160),
        timeout: 30,
        pendingApprovalRevivalTimeout: 300,
        activeClaudeProcessIDs: [42]
    )

    assertEqual(store.sessions.first?.status, .some(.waitingApproval), "recent stale approval revives while Claude process is active")
    assertEqual(store.aggregateStatus, .waitingApproval, "revived approval controls aggregate status")
}

func testOldStaleApprovalDoesNotReviveWhileClaudeProcessIsActive() {
    var store = SessionStore(sessions: [
        ClaudeSession(
            id: "s1",
            source: .unknown,
            cwd: "/repo",
            status: .stale,
            lastEventAt: Date(timeIntervalSince1970: 100),
            waitingSince: Date(timeIntervalSince1970: 100),
            approvalRequest: ApprovalRequest(
                toolName: "Bash",
                summary: "command=find .",
                requestedAt: Date(timeIntervalSince1970: 100)
            )
        )
    ])

    store.markStale(
        now: Date(timeIntervalSince1970: 1_000),
        timeout: 30,
        pendingApprovalRevivalTimeout: 300,
        activeClaudeProcessIDs: [42]
    )

    assertEqual(store.sessions.first?.status, .some(.stale), "old stale approval stays stale")
    assertEqual(store.aggregateStatus, .degraded, "old stale approval remains degraded")
}

func testStaleApprovalClearsClaudePIDToAvoidPIDReuseRevival() {
    var store = SessionStore(sessions: [
        ClaudeSession(
            id: "s1",
            source: .vscode,
            cwd: "/repo",
            status: .waitingApproval,
            claudePID: 5000,
            lastEventAt: Date(timeIntervalSince1970: 0),
            waitingSince: Date(timeIntervalSince1970: 0),
            approvalRequest: ApprovalRequest(
                toolName: "Bash",
                summary: "command=echo hi",
                requestedAt: Date(timeIntervalSince1970: 0)
            )
        )
    ])

    store.markStale(
        now: Date(timeIntervalSince1970: 120),
        timeout: 60,
        activeClaudeProcessIDs: []
    )
    store.markStale(
        now: Date(timeIntervalSince1970: 130),
        timeout: 60,
        activeClaudeProcessIDs: [5000]
    )

    assertEqual(store.sessions.first?.status, .some(.stale), "PID reuse does not revive a stale approval")
    assertEqual(store.sessions.first?.claudePID, nil, "stale approval drops stale Claude process id")
}

func testClearInactiveSessionsRemovesExpiredWaitingApproval() {
    var store = SessionStore(sessions: [
        ClaudeSession(
            id: "waiting-old",
            source: .cli,
            cwd: "/tmp/demo",
            status: .waitingApproval,
            lastEventAt: Date(timeIntervalSince1970: 10),
            waitingSince: Date(timeIntervalSince1970: 10),
            approvalRequest: ApprovalRequest(
                toolName: "Bash",
                summary: "command=echo hi",
                requestedAt: Date(timeIntervalSince1970: 10)
            )
        ),
        ClaudeSession(
            id: "waiting-recent",
            source: .vscode,
            cwd: "/repo",
            status: .waitingApproval,
            lastEventAt: Date(timeIntervalSince1970: 250),
            waitingSince: Date(timeIntervalSince1970: 250),
            approvalRequest: ApprovalRequest(
                toolName: "Bash",
                summary: "command=pnpm test",
                requestedAt: Date(timeIntervalSince1970: 250)
            )
        ),
        ClaudeSession(id: "ended", source: .cli, cwd: "/repo", status: .ended),
        ClaudeSession(id: "stale", source: .cli, cwd: "/repo", status: .stale)
    ])

    store.clearInactiveSessions(
        now: Date(timeIntervalSince1970: 400),
        waitingApprovalTimeout: 300
    )

    assertEqual(store.sessions.map(\.id), ["waiting-recent"], "clear inactive removes stale, ended, and expired waiting approvals")
}

testPermissionRequestMarksSessionWaitingApproval()
testPostToolUseClearsWaitingApproval()
testNotificationDoesNotOverwritePermissionRequestApprovalState()
testExpandedLifecycleEventsUpdateSessionState()
testStaleTimeoutMarksOldRunningSessionsStale()
testWaitingApprovalDoesNotBecomeStaleWhileItsClaudeProcessIsActive()
testWaitingApprovalBecomesStaleWhenOnlyUnrelatedClaudeProcessIsActive()
testPIDLessWaitingApprovalUsesFallbackRevivalTimeout()
testRecentStaleApprovalRevivesWhileItsClaudeProcessIsActive()
testOldStaleApprovalDoesNotReviveWhileClaudeProcessIsActive()
testStaleApprovalClearsClaudePIDToAvoidPIDReuseRevival()
testClearInactiveSessionsRemovesExpiredWaitingApproval()
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
    let existing = #"{"theme":"dark","hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo keep"}]}]}}"#
    let result = try HookSettingsInstaller.previewInstall(
        existingSettingsJSON: existing,
        hookBinaryPath: "/opt/cc/cc-sentinel-hook"
    )

    assertTrue(result.previewJSON.contains(#""theme""#), "installer preserves unrelated settings")
    assertTrue(result.previewJSON.contains("echo keep"), "installer preserves unmarked hooks")
    assertTrue(result.previewJSON.contains("cc-sentinel-hook"), "installer adds sentinel hook")
    assertTrue(result.previewJSON.contains(#""type" : "command""#), "installer writes command hook type")
}

func testInstallerCoversExpandedHookEventList() throws {
    let result = try HookSettingsInstaller.previewInstall(
        existingSettingsJSON: #"{"theme":"dark"}"#,
        hookBinaryPath: "/opt/cc/cc-sentinel-hook"
    )
    for eventName in [
        "SessionStart",
        "Notification",
        "PermissionRequest",
        "PreToolUse",
        "PostToolUse",
        "PostToolUseFailure",
        "PermissionDenied",
        "Stop",
        "StopFailure",
        "SessionEnd",
        "ConfigChange"
    ] {
        assertTrue(result.previewJSON.contains(#""\#(eventName)""#), "installer includes \(eventName)")
    }
}

func testInstallerWritesClaudeHookConfigurationShape() throws {
    let result = try HookSettingsInstaller.previewInstall(
        existingSettingsJSON: #"{"theme":"dark"}"#,
        hookBinaryPath: "/opt/cc/cc-sentinel-hook"
    )
    let root = try parseJSONObject(result.previewJSON)
    let hooks = root["hooks"] as? [String: Any]
    let sessionStartEntries = hooks?["SessionStart"] as? [[String: Any]]
    let firstEntryHooks = sessionStartEntries?.first?["hooks"] as? [[String: Any]]
    let commandHook = firstEntryHooks?.first

    assertEqual(commandHook?["type"] as? String, "command", "installer writes Claude command hook type")
    assertEqual(commandHook?["command"] as? String, "\"/opt/cc/cc-sentinel-hook\"", "installer writes Claude command hook command")
    assertTrue(sessionStartEntries?.first?["command"] == nil, "installer does not write legacy direct command entry")
}

func testInstallerReplacesLegacyManagedHookShape() throws {
    let existing = """
    {"hooks":{"SessionStart":[{"command":"/old/cc-sentinel-hook","cc-sentinel-managed":true}]}}
    """

    let result = try HookSettingsInstaller.previewInstall(
        existingSettingsJSON: existing,
        hookBinaryPath: "/new/cc-sentinel-hook"
    )
    let root = try parseJSONObject(result.previewJSON)
    let hooks = root["hooks"] as? [String: Any]
    let sessionStartEntries = hooks?["SessionStart"] as? [[String: Any]]
    let firstEntryHooks = sessionStartEntries?.first?["hooks"] as? [[String: Any]]

    assertTrue(result.previewJSON.contains("/new/cc-sentinel-hook"), "installer writes new hook shape from legacy install")
    assertTrue(!result.previewJSON.contains("/old/cc-sentinel-hook"), "installer removes legacy direct command entry")
    assertTrue(firstEntryHooks?.isEmpty == false, "installer replacement includes nested hooks array")
}

func testInstallerReplacesOldManagedHookPath() throws {
    let existing = """
    {"hooks":{"PermissionRequest":[{"hooks":[{"type":"command","command":"/old/cc-sentinel-hook"},{"type":"command","command":"echo keep"}]}]}}
    """

    let result = try HookSettingsInstaller.previewInstall(
        existingSettingsJSON: existing,
        hookBinaryPath: "/new/cc-sentinel-hook"
    )

    assertTrue(result.previewJSON.contains("/new/cc-sentinel-hook"), "installer writes new managed hook path")
    assertTrue(!result.previewJSON.contains("/old/cc-sentinel-hook"), "installer removes old managed hook path")
    assertTrue(result.previewJSON.contains("echo keep"), "installer keeps unmanaged hook")
}

func testInstallerQuotesHookCommandPathWithSpaces() throws {
    let path = "/Users/example/vibe projects/CC Sentinel/cc-sentinel-hook"
    let result = try HookSettingsInstaller.previewInstall(
        existingSettingsJSON: #"{"theme":"dark"}"#,
        hookBinaryPath: path
    )
    let root = try parseJSONObject(result.previewJSON)
    let hooks = root["hooks"] as? [String: Any]
    let sessionStart = hooks?["SessionStart"] as? [[String: Any]]
    let command = (sessionStart?.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String

    // Claude Code runs hook commands through /bin/sh -c. An unquoted path
    // containing spaces gets word-split and fails with "is a directory",
    // so the installer must emit a shell-quoted command.
    assertEqual(command, #""\#(path)""#, "installer quotes hook command path containing spaces")
}

func testQuotedHookCommandPathWithSpacesExecutesThroughShell() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("cc sentinel hook path \(UUID().uuidString)", isDirectory: true)
    let executableURL = directory.appendingPathComponent("cc-sentinel-hook")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try """
    #!/bin/sh
    printf ok
    """.write(to: executableURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)
    defer { try? FileManager.default.removeItem(at: directory) }

    let installed = try HookSettingsInstaller.previewInstall(
        existingSettingsJSON: "{}",
        hookBinaryPath: executableURL.path
    ).previewJSON
    let root = try parseJSONObject(installed)
    let hooks = root["hooks"] as? [String: Any]
    let sessionStart = hooks?["SessionStart"] as? [[String: Any]]
    let command = (sessionStart?.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", command ?? ""]
    let output = Pipe()
    process.standardOutput = output

    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    assertEqual(process.terminationStatus, 0, "quoted hook command with spaces executes through shell")
    assertEqual(String(data: data, encoding: .utf8), .some("ok"), "quoted hook command runs expected executable")
}

func testInstallerRoundTripsQuotedHookPathWithSpaces() throws {
    let path = "/Users/example/vibe projects/CC Sentinel/cc-sentinel-hook"
    let installed = try HookSettingsInstaller.previewInstall(
        existingSettingsJSON: #"{"theme":"dark"}"#,
        hookBinaryPath: path
    ).previewJSON

    assertTrue(try HookSettingsInstaller.hasManagedHooks(existingSettingsJSON: installed), "installer detects its own quoted managed hook")

    let uninstalled = try HookSettingsInstaller.previewUninstall(existingSettingsJSON: installed).previewJSON
    assertTrue(!(try HookSettingsInstaller.hasManagedHooks(existingSettingsJSON: uninstalled)), "installer removes its own quoted managed hook")
    assertTrue(uninstalled.contains(#""theme""#), "uninstall preserves unrelated settings after removing quoted hook")
}

func testUninstallRemovesOnlyManagedHook() throws {
    let existing = """
    {"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo keep"},{"type":"command","command":"/opt/cc/cc-sentinel-hook"}]}]}}
    """

    let result = try HookSettingsInstaller.previewUninstall(existingSettingsJSON: existing)

    assertTrue(result.previewJSON.contains("echo keep"), "uninstall keeps unmarked hook")
    assertTrue(!result.previewJSON.contains("cc-sentinel-hook"), "uninstall removes managed hook")
    assertTrue(result.previewJSON.contains(#""hooks""#), "uninstall keeps valid hook wrapper")
}

func testInstallerDetectsManagedHooks() throws {
    let missing = #"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo keep"}]}]}}"#
    let installed = try HookSettingsInstaller.previewInstall(
        existingSettingsJSON: missing,
        hookBinaryPath: "/opt/cc/cc-sentinel-hook"
    ).previewJSON
    let uninstalled = try HookSettingsInstaller.previewUninstall(existingSettingsJSON: installed).previewJSON

    assertTrue(!(try HookSettingsInstaller.hasManagedHooks(existingSettingsJSON: missing)), "installer reports missing managed hooks")
    assertTrue(try HookSettingsInstaller.hasManagedHooks(existingSettingsJSON: installed), "installer reports installed managed hooks")
    assertTrue(!(try HookSettingsInstaller.hasManagedHooks(existingSettingsJSON: uninstalled)), "installer reports removed managed hooks")
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
    {"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo keep"},{"type":"command","command":"/opt/cc/cc-sentinel-hook"}]}]}}
    """.write(to: settingsURL, atomically: true, encoding: .utf8)

    let backupURL = try HookSettingsInstaller.applyUninstall(
        settingsURL: settingsURL,
        timestamp: "20260624-120001"
    )

    let updated = try String(contentsOf: settingsURL, encoding: .utf8)
    let backup = try String(contentsOf: backupURL, encoding: .utf8)

    assertTrue(updated.contains("echo keep"), "apply uninstall keeps user hook")
    assertTrue(!updated.contains("cc-sentinel-hook"), "apply uninstall removes managed hook")
    assertTrue(backup.contains("cc-sentinel-hook"), "apply uninstall writes pre-change backup")
    try? FileManager.default.removeItem(at: directory)
}

try testInstallerPreservesUnrelatedSettingsAndAddsManagedHook()
try testInstallerCoversExpandedHookEventList()
try testInstallerWritesClaudeHookConfigurationShape()
try testInstallerReplacesLegacyManagedHookShape()
try testInstallerReplacesOldManagedHookPath()
try testInstallerQuotesHookCommandPathWithSpaces()
try testQuotedHookCommandPathWithSpacesExecutesThroughShell()
try testInstallerRoundTripsQuotedHookPathWithSpaces()
try testUninstallRemovesOnlyManagedHook()
try testInstallerDetectsManagedHooks()
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
    let config = AutoApprovalConfig(schemaVersion: 1, enabled: true, workspace: "/repo", rules: [.allowWorkspaceRead()])

    let decision = config.evaluate(
        tool: "Read",
        command: "README.md",
        cwd: "/repo",
        fallbackWorkspace: "/repo"
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
    let config = AutoApprovalConfig(schemaVersion: 1, enabled: true, workspace: "/repo", rules: [.allowWorkspaceRead()])
    let decision = config.evaluate(
        tool: "Read",
        command: "/repo-sibling/README.md",
        cwd: "/repo",
        fallbackWorkspace: "/repo"
    )

    assertEqual(decision, .ask, "workspace prefix sibling is not allowed")
}

func testBashCommandPrefixRuleAllowsLowRiskCommand() {
    let config = AutoApprovalConfig(
        schemaVersion: 1,
        enabled: true,
        workspace: "/repo",
        rules: [
            AutoApprovalRule(
                id: "allow-git-status",
                effect: .allow,
                tool: "Bash",
                scope: .workspace,
                match: .init(commandPrefixes: ["git status"])
            )
        ]
    )

    let decision = config.evaluate(
        tool: "Bash",
        command: "git status --short",
        cwd: "/repo",
        fallbackWorkspace: "/repo"
    )

    assertEqual(decision, ApprovalDecision.allow, "command prefix allow rule permits low-risk bash command")
}

func testAutoApprovalConfigAllowsMultiplePrefixRules() {
    let config = AutoApprovalConfig(
        schemaVersion: 1,
        enabled: true,
        workspace: "/repo",
        rules: [
            AutoApprovalRule(
                id: "allow-git-diff",
                effect: .allow,
                tool: "Bash",
                scope: .workspace,
                match: .init(commandPrefixes: ["git status", "git diff"])
            )
        ]
    )

    let decision = config.evaluate(
        tool: "Bash",
        command: "git diff --stat",
        cwd: "/repo",
        fallbackWorkspace: "/repo"
    )

    assertEqual(decision, ApprovalDecision.allow, "multiple prefix rules allow matching command")
}

func testDenyRuleStillBeatsLaterLowRiskPrefixRule() {
    let config = AutoApprovalConfig(
        schemaVersion: 1,
        enabled: true,
        workspace: "/repo",
        rules: [
            .denySensitiveShell(),
            AutoApprovalRule(
                id: "allow-git-prefix",
                effect: .allow,
                tool: "Bash",
                scope: .workspace,
                match: .init(commandPrefixes: ["git"])
            )
        ]
    )

    let decision = config.evaluate(
        tool: "Bash",
        command: "git push origin main",
        cwd: "/repo",
        fallbackWorkspace: "/repo"
    )

    assertEqual(decision, ApprovalDecision.deny, "deny rule still wins before broad low-risk prefix rule")
}

func testAutoApprovalSettingsDefaultToDisabled() {
    assertEqual(AutoApprovalConfig.default.enabled, false, "auto approval defaults disabled")
}

func testAutoApprovalDoesNothingWhenDisabled() throws {
    let input = """
    {"hook_event_name":"PermissionRequest","session_id":"auto-disabled","cwd":"/repo","tool_name":"Read","tool_input":{"file_path":"/repo/README.md"}}
    """.data(using: .utf8)!
    var stats = AutoApprovalStats()

    let result = try AutoApprovalHookDecision.evaluate(
        inputData: input,
        config: .default,
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
    let config = AutoApprovalConfig(
        schemaVersion: 1,
        enabled: true,
        workspace: "/repo",
        rules: [.allowWorkspaceRead()]
    )
    var stats = AutoApprovalStats()

    let result = try AutoApprovalHookDecision.evaluate(
        inputData: input,
        config: config,
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
    let config = AutoApprovalConfig(
        schemaVersion: 1,
        enabled: true,
        workspace: "/repo",
        rules: [.allowWorkspaceRead()]
    )
    var stats = AutoApprovalStats()

    let result = try AutoApprovalHookDecision.evaluate(
        inputData: input,
        config: config,
        stats: &stats,
        now: Date(timeIntervalSince1970: 1_800_000_000)
    )

    assertEqual(result.decision, .ask, "outside workspace read is not auto-approved")
    assertEqual(result.outputJSON, nil, "outside workspace read has no hook output")
    assertEqual(stats.totalCount, 0, "outside workspace read does not increment stats")
}

func testAutoApprovalConfigRoundTripsJSON() throws {
    let config = AutoApprovalConfig(
        schemaVersion: 1,
        enabled: true,
        workspace: "/repo",
        profile: AutoApprovalProfile(name: "Preset", notes: "shared"),
        rules: [.allowWorkspaceRead(), .denySensitiveShell()]
    )
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("cc-sentinel-auto-config-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: url) }

    try AutoApprovalConfigPersistence.save(config, to: url)
    let loaded = try AutoApprovalConfigPersistence.load(from: url)

    assertEqual(loaded, config, "config persistence round trips")
}

func testAutoApprovalConfigRejectsUnsupportedSchemaVersion() throws {
    let data = """
    {"schemaVersion":99,"enabled":true,"workspace":"/repo","rules":[]}
    """.data(using: .utf8)!

    do {
        _ = try AutoApprovalConfigPersistence.decode(data)
        print("FAIL: unsupported schema version should be rejected.")
        Foundation.exit(1)
    } catch AutoApprovalConfigError.unsupportedSchemaVersion(99) {
    } catch {
        print("FAIL: unsupported schema version failed with unexpected error \(error).")
        Foundation.exit(1)
    }
}

func testAutoApprovalConfigErrorDescriptionsAreActionable() {
    assertEqual(
        AutoApprovalConfigError.unsupportedSchemaVersion(99).userFacingDescription,
        "Unsupported auto-approval config schemaVersion 99. This version supports schemaVersion 1.",
        "unsupported schema version description is actionable"
    )
    assertEqual(
        AutoApprovalConfigError.emptyRuleID.userFacingDescription,
        "Every auto-approval rule must have a non-empty id.",
        "empty rule id description is actionable"
    )
    assertEqual(
        AutoApprovalConfigError.emptyCommandMatch(ruleID: "deny-shell").userFacingDescription,
        "Rule deny-shell must define at least one commandContains or commandPrefixes matcher.",
        "empty command match description is actionable"
    )
}

func testAutoApprovalConfigMigratesLegacySettings() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("cc-sentinel-auto-migrate-\(UUID().uuidString)", isDirectory: true)
    let configURL = directory.appendingPathComponent("auto-approval-config.json")
    let legacyURL = directory.appendingPathComponent("auto-approval-settings.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    try AutoApprovalSettingsPersistence.save(
        AutoApprovalSettings(
            enabled: true,
            policy: ApprovalPolicy(allowWorkspaceReads: true, allowWorkspaceEdits: false),
            workspace: "/repo"
        ),
        to: legacyURL
    )

    let config = try AutoApprovalConfigMigration.loadMigrating(configURL: configURL, legacySettingsURL: legacyURL)

    assertEqual(config.enabled, true, "migration keeps enabled")
    assertEqual(config.workspace, "/repo", "migration keeps workspace")
    assertTrue(config.rules.contains(.allowWorkspaceRead()), "migration adds workspace read rule")
    assertTrue(config.rules.contains(.denySensitiveShell()), "migration adds sensitive shell deny rule")
    assertTrue(FileManager.default.fileExists(atPath: configURL.path), "migration writes new config")
}

func testAutoApprovalConfigImportBacksUpAndReplacesActiveConfig() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("cc-sentinel-auto-import-\(UUID().uuidString)", isDirectory: true)
    let activeURL = directory.appendingPathComponent("auto-approval-config.json")
    let sourceURL = directory.appendingPathComponent("incoming.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    let existing = AutoApprovalConfig(schemaVersion: 1, enabled: false, workspace: "/old", rules: [])
    let incoming = AutoApprovalConfig(schemaVersion: 1, enabled: true, workspace: "/new", rules: [.allowWorkspaceRead()])
    try AutoApprovalConfigPersistence.save(existing, to: activeURL)
    try AutoApprovalConfigPersistence.save(incoming, to: sourceURL)

    let backupURL = try AutoApprovalConfigPersistence.replaceActiveConfig(
        with: sourceURL,
        activeURL: activeURL,
        now: Date(timeIntervalSince1970: 1_800_000_000)
    )

    assertTrue(FileManager.default.fileExists(atPath: backupURL.path), "import creates backup")
    assertEqual(try AutoApprovalConfigPersistence.load(from: backupURL), existing, "backup preserves old config")
    assertEqual(try AutoApprovalConfigPersistence.load(from: activeURL), incoming, "import replaces active config")
}

func testAutoApprovalConfigImportRejectsInvalidFileWithoutReplacingActiveConfig() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("cc-sentinel-auto-import-invalid-\(UUID().uuidString)", isDirectory: true)
    let activeURL = directory.appendingPathComponent("auto-approval-config.json")
    let sourceURL = directory.appendingPathComponent("incoming.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    let existing = AutoApprovalConfig(schemaVersion: 1, enabled: false, workspace: "/old", rules: [])
    try AutoApprovalConfigPersistence.save(existing, to: activeURL)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data(#"{"schemaVersion":99,"enabled":true,"workspace":"/new","rules":[]}"#.utf8).write(to: sourceURL)

    do {
        _ = try AutoApprovalConfigPersistence.replaceActiveConfig(with: sourceURL, activeURL: activeURL)
        print("FAIL: invalid import should be rejected.")
        Foundation.exit(1)
    } catch AutoApprovalConfigError.unsupportedSchemaVersion(99) {
    } catch {
        print("FAIL: invalid import failed with unexpected error \(error).")
        Foundation.exit(1)
    }

    assertEqual(try AutoApprovalConfigPersistence.load(from: activeURL), existing, "invalid import keeps active config")
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
testBashCommandPrefixRuleAllowsLowRiskCommand()
testAutoApprovalConfigAllowsMultiplePrefixRules()
testDenyRuleStillBeatsLaterLowRiskPrefixRule()
testAutoApprovalSettingsDefaultToDisabled()
try testAutoApprovalDoesNothingWhenDisabled()
try testAutoApprovalAllowsWorkspaceReadAndRecordsStats()
try testAutoApprovalDoesNotAllowOutsideWorkspaceRead()
try testAutoApprovalConfigRoundTripsJSON()
try testAutoApprovalConfigRejectsUnsupportedSchemaVersion()
testAutoApprovalConfigErrorDescriptionsAreActionable()
try testAutoApprovalConfigMigratesLegacySettings()
try testAutoApprovalConfigImportBacksUpAndReplacesActiveConfig()
try testAutoApprovalConfigImportRejectsInvalidFileWithoutReplacingActiveConfig()
try testAutoApprovalStatsPersistenceRoundTripsJSON()
testRecordingAutoApprovalIncrementsTodayAndTotal()
print("PASS: ApprovalPolicyTests")
print("PASS: AutoApprovalStatsTests")
