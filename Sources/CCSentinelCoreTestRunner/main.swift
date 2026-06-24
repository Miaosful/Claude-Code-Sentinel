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
}

func testRedactsTokenLikeValues() {
    let input = "curl -H Authorization: Bearer sk-live-secret-value https://example.test"
    let redacted = Redactor.safeSummary(input)

    assertTrue(!redacted.contains("sk-live-secret-value"), "redactor removes secret token")
    assertTrue(redacted.contains("[redacted]"), "redactor marks redacted content")
}

try testPermissionRequestBecomesWaitingApprovalEvent()
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

testPermissionRequestMarksSessionWaitingApproval()
testPostToolUseClearsWaitingApproval()
print("PASS: SessionStoreTests")

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
