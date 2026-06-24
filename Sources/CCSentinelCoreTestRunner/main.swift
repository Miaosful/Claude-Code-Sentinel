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
