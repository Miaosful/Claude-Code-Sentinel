import Foundation
import CCSentinelCore

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    if actual != expected {
        print("FAIL: \(message). Expected \(expected), got \(actual).")
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
