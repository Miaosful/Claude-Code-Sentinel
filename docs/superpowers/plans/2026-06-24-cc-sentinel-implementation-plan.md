# CC Sentinel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local-only macOS menu bar app that monitors Claude Code CLI and VS Code extension sessions, shows approval-needed state, supports bilingual English and Simplified Chinese UI, and prepares a controlled auto-approval audit/statistics path.

**目标：** 构建一个只在本机运行的 macOS 状态栏 App，用来监控 Claude Code CLI 与 VS Code 插件会话，展示需要审批的状态，支持英文和简体中文界面，并为受控自动审批审计与统计能力打好基础。

**Architecture:** Use a Swift Package with a testable `CCSentinelCore` library, a SwiftUI/AppKit menu bar app target, and two small command-line tools: `cc-sentinel-hook` and `cc-sentinel-wrapper`. Hooks are the source of truth, the VS Code wrapper only tags source/lifecycle, and process detection is only a degraded fallback.

**架构：** 使用 Swift Package 组织工程：`CCSentinelCore` 作为可测试核心库，SwiftUI/AppKit 状态栏 App 作为桌面入口，另外提供两个小型命令行工具：`cc-sentinel-hook` 与 `cc-sentinel-wrapper`。Hooks 是事实来源，VS Code wrapper 只负责来源和生命周期标记，进程检测仅作为降级兜底。

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSStatusItem`, Network framework `NWListener`, XCTest, macOS `UserNotifications`, `FileManager`, `JSONSerialization`, `.lproj/Localizable.strings`.

**技术栈：** Swift 6、SwiftUI、AppKit `NSStatusItem`、Network framework `NWListener`、XCTest、macOS `UserNotifications`、`FileManager`、`JSONSerialization`、`.lproj/Localizable.strings`。

---

## Scope / 范围

MVP ships passive monitoring, safe hook installation, multi-session menu display, stale cleanup, bilingual UI, and auto-approval counters that stay at zero unless the controlled policy engine records an approval. Direct auto-approval is Phase 2 and remains disabled by default.

MVP 交付被动监控、安全 hooks 安装、多会话菜单展示、过期清理、双语 UI，以及自动审批计数基础；除非受控策略引擎记录了一次审批，否则计数保持为零。真正的自动审批属于第二阶段，并且默认关闭。

## File Structure / 文件结构

- Create: `Package.swift`  
  SwiftPM package definition for core library, app executable, hook executable, wrapper executable, and tests.
- Create: `Sources/CCSentinelCore/HookEvent.swift`  
  Hook/wrapper event decoding and normalized event types.
- Create: `Sources/CCSentinelCore/SessionState.swift`  
  Session model, aggregate status priority, stale timeout logic.
- Create: `Sources/CCSentinelCore/EventNormalizer.swift`  
  Converts raw hook JSON into normalized core events.
- Create: `Sources/CCSentinelCore/Redactor.swift`  
  Truncates and redacts sensitive tool input for UI and logs.
- Create: `Sources/CCSentinelCore/SessionStore.swift`  
  In-memory state reducer plus JSON persistence under Application Support.
- Create: `Sources/CCSentinelCore/AutoApprovalStats.swift`  
  Today/total counters and audit event model.
- Create: `Sources/CCSentinelCore/ApprovalPolicy.swift`  
  Allow/ask/deny policy evaluator for Phase 2, defaulting to ask/deny.
- Create: `Sources/CCSentinelCore/HookSettingsInstaller.swift`  
  Safe `~/.claude/settings.json` merge, backup, preview, uninstall.
- Create: `Sources/CCSentinelCore/LocalizationKeys.swift`  
  Compile-time string keys used by app UI and tests.
- Create: `Sources/CCSentinelApp/CCSentinelApp.swift`  
  App entry point and app delegate bridge.
- Create: `Sources/CCSentinelApp/AppDelegate.swift`  
  `NSStatusItem`, popover lifecycle, app startup/shutdown.
- Create: `Sources/CCSentinelApp/EventReceiver.swift`  
  Localhost HTTP listener using `NWListener`; JSONL fallback importer.
- Create: `Sources/CCSentinelApp/MenuBarController.swift`  
  Maps aggregate status to menu bar icon/color/animation state.
- Create: `Sources/CCSentinelApp/StatusPopoverView.swift`  
  SwiftUI popover UI for summary, sessions, controls, and stats.
- Create: `Sources/CCSentinelApp/SettingsView.swift`  
  Hook install/uninstall, language selection, privacy toggles.
- Create: `Sources/CCSentinelApp/Resources/en.lproj/Localizable.strings`  
  English user-visible strings.
- Create: `Sources/CCSentinelApp/Resources/zh-Hans.lproj/Localizable.strings`  
  Simplified Chinese user-visible strings.
- Create: `Sources/CCSentinelHook/main.swift`  
  Reads Claude hook JSON from stdin, posts normalized event to app, writes JSONL fallback if app is down.
- Create: `Sources/CCSentinelWrapper/main.swift`  
  Wraps the real Claude binary, tags process lifecycle as likely VS Code, and passes arguments through unchanged.
- Create: `Tests/CCSentinelCoreTests/*.swift`  
  Unit tests for normalization, state reduction, redaction, installer behavior, policy, stats, and localization coverage.
- Create: `docs/installation.zh-CN.md` and `docs/installation.en.md`  
  Bilingual install, privacy, uninstall, and troubleshooting docs.

## Milestones / 里程碑

1. Project foundation and tests / 工程骨架与测试。
2. Hook event ingestion and session state / Hook 事件接入与会话状态。
3. Local receiver, hook CLI, and VS Code wrapper / 本地事件服务、Hook CLI 与 VS Code wrapper。
4. macOS menu bar UI with bilingual strings / 支持双语文案的 macOS 状态栏 UI。
5. Safe installer and privacy controls / 安全安装器与隐私控制。
6. Auto-approval policy foundation and statistics / 自动审批策略基础与统计。
7. Packaging, docs, and acceptance QA / 打包、文档与验收。

---

### Task 1: Repository And Package Foundation / 仓库与 Swift Package 骨架

**Files:**
- Create: `Package.swift`
- Create: `Sources/CCSentinelCore/HookEvent.swift`
- Create: `Sources/CCSentinelApp/CCSentinelApp.swift`
- Create: `Sources/CCSentinelHook/main.swift`
- Create: `Sources/CCSentinelWrapper/main.swift`
- Create: `Tests/CCSentinelCoreTests/FoundationSmokeTests.swift`

- [ ] **Step 1: Initialize git and create package directories / 初始化 git 与目录**

Run:

```bash
git init
mkdir -p Sources/CCSentinelCore Sources/CCSentinelApp Sources/CCSentinelHook Sources/CCSentinelWrapper Tests/CCSentinelCoreTests
```

Expected: `git status --short` shows newly created directories after files are added.

- [ ] **Step 2: Create `Package.swift` / 创建 Package.swift**

Use this package definition:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CCSentinel",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CCSentinelCore", targets: ["CCSentinelCore"]),
        .executable(name: "CCSentinelApp", targets: ["CCSentinelApp"]),
        .executable(name: "cc-sentinel-hook", targets: ["CCSentinelHook"]),
        .executable(name: "cc-sentinel-wrapper", targets: ["CCSentinelWrapper"])
    ],
    targets: [
        .target(name: "CCSentinelCore"),
        .executableTarget(
            name: "CCSentinelApp",
            dependencies: ["CCSentinelCore"],
            resources: [.process("Resources")]
        ),
        .executableTarget(name: "CCSentinelHook", dependencies: ["CCSentinelCore"]),
        .executableTarget(name: "CCSentinelWrapper", dependencies: ["CCSentinelCore"]),
        .testTarget(name: "CCSentinelCoreTests", dependencies: ["CCSentinelCore"])
    ]
)
```

- [ ] **Step 3: Add smoke test first / 先写冒烟测试**

Create `Tests/CCSentinelCoreTests/FoundationSmokeTests.swift`:

```swift
import XCTest
@testable import CCSentinelCore

final class FoundationSmokeTests: XCTestCase {
    func testCoreModuleExposesVersion() {
        XCTAssertEqual(CCSentinelVersion.current, "0.1.0")
    }
}
```

- [ ] **Step 4: Run failing test / 运行失败测试**

Run:

```bash
swift test --filter FoundationSmokeTests
```

Expected: FAIL because `CCSentinelVersion` is not defined.

- [ ] **Step 5: Add minimal core version / 添加最小核心代码**

Create `Sources/CCSentinelCore/HookEvent.swift`:

```swift
public enum CCSentinelVersion {
    public static let current = "0.1.0"
}
```

Create `Sources/CCSentinelApp/CCSentinelApp.swift`:

```swift
import SwiftUI

@main
struct CCSentinelApp: App {
    var body: some Scene {
        Settings {
            Text("CC Sentinel")
        }
    }
}
```

Create `Sources/CCSentinelHook/main.swift`:

```swift
import CCSentinelCore

print("cc-sentinel-hook \(CCSentinelVersion.current)")
```

Create `Sources/CCSentinelWrapper/main.swift`:

```swift
import CCSentinelCore

print("cc-sentinel-wrapper \(CCSentinelVersion.current)")
```

- [ ] **Step 6: Verify and commit / 验证并提交**

Run:

```bash
swift test --filter FoundationSmokeTests
swift build
git add Package.swift Sources Tests
git commit -m "chore: scaffold CC Sentinel package"
```

Expected: tests and build pass; commit is created.

---

### Task 2: Core Event And Session Model / 核心事件与会话模型

**Files:**
- Modify: `Sources/CCSentinelCore/HookEvent.swift`
- Create: `Sources/CCSentinelCore/SessionState.swift`
- Create: `Tests/CCSentinelCoreTests/SessionStateTests.swift`

- [ ] **Step 1: Write state aggregation tests / 编写聚合状态测试**

Create `Tests/CCSentinelCoreTests/SessionStateTests.swift`:

```swift
import XCTest
@testable import CCSentinelCore

final class SessionStateTests: XCTestCase {
    func testApprovalBeatsRunningInAggregateStatus() {
        let sessions = [
            ClaudeSession(id: "a", source: .cli, cwd: "/tmp/a", status: .running),
            ClaudeSession(id: "b", source: .vscode, cwd: "/tmp/b", status: .waitingApproval)
        ]
        XCTAssertEqual(AggregateStatus.resolve(sessions: sessions), .waitingApproval)
    }

    func testRunningBeatsStaleWhenNoApprovalExists() {
        let sessions = [
            ClaudeSession(id: "a", source: .unknown, cwd: "/tmp/a", status: .stale),
            ClaudeSession(id: "b", source: .cli, cwd: "/tmp/b", status: .running)
        ]
        XCTAssertEqual(AggregateStatus.resolve(sessions: sessions), .running)
    }

    func testEmptySessionsAreIdle() {
        XCTAssertEqual(AggregateStatus.resolve(sessions: []), .idle)
    }
}
```

- [ ] **Step 2: Run failing tests / 运行失败测试**

Run:

```bash
swift test --filter SessionStateTests
```

Expected: FAIL because `ClaudeSession`, `SessionSource`, `SessionStatus`, and `AggregateStatus` are missing.

- [ ] **Step 3: Implement model / 实现模型**

Create `Sources/CCSentinelCore/SessionState.swift`:

```swift
import Foundation

public enum SessionSource: String, Codable, Equatable, Sendable {
    case cli
    case vscode
    case unknown
}

public enum SessionStatus: String, Codable, Equatable, Sendable {
    case running
    case waitingApproval = "waiting_approval"
    case idle
    case ended
    case stale
    case error
}

public struct ApprovalRequest: Codable, Equatable, Sendable {
    public var toolName: String
    public var summary: String
    public var requestedAt: Date

    public init(toolName: String, summary: String, requestedAt: Date) {
        self.toolName = toolName
        self.summary = summary
        self.requestedAt = requestedAt
    }
}

public struct ClaudeSession: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var source: SessionSource
    public var cwd: String
    public var status: SessionStatus
    public var permissionMode: String?
    public var lastToolName: String?
    public var lastToolSummary: String?
    public var lastEventAt: Date
    public var waitingSince: Date?
    public var approvalRequest: ApprovalRequest?

    public init(
        id: String,
        source: SessionSource,
        cwd: String,
        status: SessionStatus,
        permissionMode: String? = nil,
        lastToolName: String? = nil,
        lastToolSummary: String? = nil,
        lastEventAt: Date = Date(timeIntervalSince1970: 0),
        waitingSince: Date? = nil,
        approvalRequest: ApprovalRequest? = nil
    ) {
        self.id = id
        self.source = source
        self.cwd = cwd
        self.status = status
        self.permissionMode = permissionMode
        self.lastToolName = lastToolName
        self.lastToolSummary = lastToolSummary
        self.lastEventAt = lastEventAt
        self.waitingSince = waitingSince
        self.approvalRequest = approvalRequest
    }
}

public enum AggregateStatus: String, Equatable, Sendable {
    case idle
    case running
    case waitingApproval = "waiting_approval"
    case degraded

    public static func resolve(sessions: [ClaudeSession]) -> AggregateStatus {
        if sessions.contains(where: { $0.status == .waitingApproval }) { return .waitingApproval }
        if sessions.contains(where: { $0.status == .running }) { return .running }
        if sessions.contains(where: { $0.status == .stale || $0.status == .error }) { return .degraded }
        return .idle
    }
}
```

- [ ] **Step 4: Verify and commit / 验证并提交**

Run:

```bash
swift test --filter SessionStateTests
git add Sources/CCSentinelCore/SessionState.swift Tests/CCSentinelCoreTests/SessionStateTests.swift
git commit -m "feat: add session state model"
```

Expected: `SessionStateTests` passes.

---

### Task 3: Hook Event Normalization And Redaction / Hook 事件归一化与脱敏

**Files:**
- Modify: `Sources/CCSentinelCore/HookEvent.swift`
- Create: `Sources/CCSentinelCore/EventNormalizer.swift`
- Create: `Sources/CCSentinelCore/Redactor.swift`
- Create: `Tests/CCSentinelCoreTests/EventNormalizerTests.swift`
- Create: `Tests/CCSentinelCoreTests/RedactorTests.swift`

- [ ] **Step 1: Write normalizer and redactor tests / 编写归一化与脱敏测试**

Create tests that cover `SessionStart`, `PermissionRequest`, `PostToolUse`, and secret redaction:

```swift
import XCTest
@testable import CCSentinelCore

final class EventNormalizerTests: XCTestCase {
    func testPermissionRequestBecomesWaitingApprovalEvent() throws {
        let json = """
        {"hook_event_name":"PermissionRequest","session_id":"s1","cwd":"/repo","tool_name":"Bash","tool_input":{"command":"pnpm test"},"permission_mode":"default"}
        """.data(using: .utf8)!

        let event = try EventNormalizer.normalize(json)

        XCTAssertEqual(event.sessionID, "s1")
        XCTAssertEqual(event.kind, .permissionRequest)
        XCTAssertEqual(event.source, .unknown)
        XCTAssertEqual(event.cwd, "/repo")
        XCTAssertEqual(event.toolName, "Bash")
        XCTAssertEqual(event.toolSummary, "command=pnpm test")
    }
}

final class RedactorTests: XCTestCase {
    func testRedactsTokenLikeValues() {
        let input = "curl -H Authorization: Bearer sk-live-secret-value https://example.test"
        let redacted = Redactor.safeSummary(input)
        XCTAssertFalse(redacted.contains("sk-live-secret-value"))
        XCTAssertTrue(redacted.contains("[redacted]"))
    }
}
```

- [ ] **Step 2: Run failing tests / 运行失败测试**

Run:

```bash
swift test --filter EventNormalizerTests
swift test --filter RedactorTests
```

Expected: FAIL because `EventNormalizer`, `NormalizedEvent`, and `Redactor` are missing.

- [ ] **Step 3: Implement event types / 实现事件类型**

Add to `Sources/CCSentinelCore/HookEvent.swift`:

```swift
import Foundation

public enum NormalizedEventKind: String, Codable, Equatable, Sendable {
    case sessionStart
    case permissionRequest
    case postToolUse
    case postToolUseFailure
    case stop
    case sessionEnd
    case notification
    case wrapperProcessStart
    case wrapperProcessEnd
}

public struct NormalizedEvent: Codable, Equatable, Sendable {
    public var kind: NormalizedEventKind
    public var sessionID: String
    public var source: SessionSource
    public var cwd: String
    public var permissionMode: String?
    public var toolName: String?
    public var toolSummary: String?
    public var occurredAt: Date

    public init(
        kind: NormalizedEventKind,
        sessionID: String,
        source: SessionSource,
        cwd: String,
        permissionMode: String? = nil,
        toolName: String? = nil,
        toolSummary: String? = nil,
        occurredAt: Date = Date()
    ) {
        self.kind = kind
        self.sessionID = sessionID
        self.source = source
        self.cwd = cwd
        self.permissionMode = permissionMode
        self.toolName = toolName
        self.toolSummary = toolSummary
        self.occurredAt = occurredAt
    }
}
```

- [ ] **Step 4: Implement redactor and normalizer / 实现脱敏与归一化**

Create `Sources/CCSentinelCore/Redactor.swift`:

```swift
import Foundation

public enum Redactor {
    public static func safeSummary(_ value: String, maxLength: Int = 120) -> String {
        let patterns = [
            #"(?i)(bearer\s+)[A-Za-z0-9._\-]+"#,
            #"(?i)(api[_-]?key=)[^&\s]+"#,
            #"sk-[A-Za-z0-9._\-]+"#
        ]
        var output = value
        for pattern in patterns {
            output = output.replacingOccurrences(
                of: pattern,
                with: "$1[redacted]",
                options: .regularExpression
            )
        }
        if output.count > maxLength {
            return String(output.prefix(maxLength)) + "..."
        }
        return output
    }
}
```

Create `Sources/CCSentinelCore/EventNormalizer.swift`:

```swift
import Foundation

public enum EventNormalizer {
    public enum Error: Swift.Error, Equatable {
        case malformed
        case missingSessionID
    }

    public static func normalize(_ data: Data, sourceHint: SessionSource = .unknown) throws -> NormalizedEvent {
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw Error.malformed }

        guard let sessionID = object["session_id"] as? String, !sessionID.isEmpty else {
            throw Error.missingSessionID
        }

        let hookName = object["hook_event_name"] as? String ?? "Notification"
        let cwd = object["cwd"] as? String ?? ""
        let permissionMode = object["permission_mode"] as? String
        let toolName = object["tool_name"] as? String
        let toolInput = object["tool_input"].map { summarizeJSONObject($0) }

        return NormalizedEvent(
            kind: mapHookName(hookName),
            sessionID: sessionID,
            source: sourceHint,
            cwd: cwd,
            permissionMode: permissionMode,
            toolName: toolName,
            toolSummary: toolInput,
            occurredAt: Date()
        )
    }

    private static func mapHookName(_ name: String) -> NormalizedEventKind {
        switch name {
        case "SessionStart": return .sessionStart
        case "PermissionRequest": return .permissionRequest
        case "PostToolUse": return .postToolUse
        case "PostToolUseFailure": return .postToolUseFailure
        case "Stop": return .stop
        case "SessionEnd": return .sessionEnd
        default: return .notification
        }
    }

    private static func summarizeJSONObject(_ value: Any) -> String {
        if let dict = value as? [String: Any] {
            return dict.keys.sorted().compactMap { key in
                guard let raw = dict[key] else { return nil }
                return "\(key)=\(Redactor.safeSummary(String(describing: raw)))"
            }.joined(separator: " ")
        }
        return Redactor.safeSummary(String(describing: value))
    }
}
```

- [ ] **Step 5: Verify and commit / 验证并提交**

Run:

```bash
swift test --filter EventNormalizerTests
swift test --filter RedactorTests
git add Sources/CCSentinelCore Tests/CCSentinelCoreTests
git commit -m "feat: normalize Claude hook events"
```

Expected: normalizer and redactor tests pass.

---

### Task 4: Session Store And Persistence / 会话状态存储与持久化

**Files:**
- Create: `Sources/CCSentinelCore/SessionStore.swift`
- Create: `Tests/CCSentinelCoreTests/SessionStoreTests.swift`

- [ ] **Step 1: Write reducer tests / 编写状态 reducer 测试**

Create tests for `PermissionRequest` setting `waitingApproval`, `PostToolUse` clearing it, and stale cleanup:

```swift
import XCTest
@testable import CCSentinelCore

final class SessionStoreTests: XCTestCase {
    func testPermissionRequestMarksSessionWaitingApproval() {
        var store = SessionStore()
        store.apply(.init(kind: .permissionRequest, sessionID: "s1", source: .vscode, cwd: "/repo", toolName: "Bash", toolSummary: "command=pnpm test"))

        XCTAssertEqual(store.sessions.first?.status, .waitingApproval)
        XCTAssertEqual(store.aggregateStatus, .waitingApproval)
    }

    func testPostToolUseClearsWaitingApproval() {
        var store = SessionStore()
        store.apply(.init(kind: .permissionRequest, sessionID: "s1", source: .vscode, cwd: "/repo", toolName: "Bash"))
        store.apply(.init(kind: .postToolUse, sessionID: "s1", source: .vscode, cwd: "/repo", toolName: "Bash"))

        XCTAssertEqual(store.sessions.first?.status, .running)
    }
}
```

- [ ] **Step 2: Run failing tests / 运行失败测试**

Run:

```bash
swift test --filter SessionStoreTests
```

Expected: FAIL because `SessionStore` is missing.

- [ ] **Step 3: Implement reducer / 实现 reducer**

Create `Sources/CCSentinelCore/SessionStore.swift` with:

```swift
import Foundation

public struct SessionStore: Codable, Equatable, Sendable {
    public private(set) var sessions: [ClaudeSession]

    public init(sessions: [ClaudeSession] = []) {
        self.sessions = sessions
    }

    public var aggregateStatus: AggregateStatus {
        AggregateStatus.resolve(sessions: sessions)
    }

    public mutating func apply(_ event: NormalizedEvent) {
        let index = sessions.firstIndex(where: { $0.id == event.sessionID })
        var session = index.map { sessions[$0] } ?? ClaudeSession(
            id: event.sessionID,
            source: event.source,
            cwd: event.cwd,
            status: .running
        )

        session.source = event.source == .unknown ? session.source : event.source
        session.cwd = event.cwd.isEmpty ? session.cwd : event.cwd
        session.permissionMode = event.permissionMode ?? session.permissionMode
        session.lastToolName = event.toolName ?? session.lastToolName
        session.lastToolSummary = event.toolSummary ?? session.lastToolSummary
        session.lastEventAt = event.occurredAt

        switch event.kind {
        case .permissionRequest, .notification:
            session.status = .waitingApproval
            session.waitingSince = event.occurredAt
            session.approvalRequest = ApprovalRequest(
                toolName: event.toolName ?? "Unknown",
                summary: event.toolSummary ?? "",
                requestedAt: event.occurredAt
            )
        case .postToolUse, .postToolUseFailure:
            session.status = .running
            session.waitingSince = nil
            session.approvalRequest = nil
        case .stop:
            session.status = .idle
        case .sessionEnd, .wrapperProcessEnd:
            session.status = .ended
        case .sessionStart, .wrapperProcessStart:
            session.status = .running
        }

        if let index {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
    }
}
```

- [ ] **Step 4: Verify and commit / 验证并提交**

Run:

```bash
swift test --filter SessionStoreTests
git add Sources/CCSentinelCore/SessionStore.swift Tests/CCSentinelCoreTests/SessionStoreTests.swift
git commit -m "feat: reduce events into session state"
```

Expected: session store tests pass.

---

### Task 5: Local Event Receiver And Hook CLI / 本地事件服务与 Hook CLI

**Files:**
- Create: `Sources/CCSentinelApp/EventReceiver.swift`
- Modify: `Sources/CCSentinelHook/main.swift`
- Create: `Tests/CCSentinelCoreTests/HookCLITests.swift`

- [ ] **Step 1: Define receiver contract / 定义接收服务契约**

Contract:

```text
POST http://127.0.0.1:47281/events
Content-Type: application/json
Body: raw Claude hook JSON
Response: 202 Accepted when normalized and queued
Fallback: append one JSON object per line to ~/Library/Application Support/CC Sentinel/events-fallback.jsonl
```

- [ ] **Step 2: Test hook fallback path / 测试 hook 兜底写入**

Create a test helper around a pure function `HookForwarder.forward(data:endpoint:fallbackURL:)` so the CLI is testable without launching the executable:

```swift
func testHookForwarderWritesFallbackWhenReceiverIsUnavailable() throws {
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let data = #"{"hook_event_name":"SessionStart","session_id":"s1","cwd":"/repo"}"#.data(using: .utf8)!

    try HookForwarder.forward(data: data, endpoint: URL(string: "http://127.0.0.1:1/events")!, fallbackURL: temp)

    let saved = try String(contentsOf: temp, encoding: .utf8)
    XCTAssertTrue(saved.contains("\"session_id\":\"s1\""))
}
```

- [ ] **Step 3: Implement receiver / 实现接收服务**

Implement `EventReceiver` with `NWListener` on `127.0.0.1:47281`, parse only `POST /events`, reject bodies larger than 512 KB, call `EventNormalizer.normalize`, then apply the event to `SessionStore`.

Acceptance behavior:

```text
Valid event -> 202 Accepted
Malformed JSON -> 400 Bad Request
Wrong path -> 404 Not Found
Oversized body -> 413 Payload Too Large
```

- [ ] **Step 4: Implement hook CLI / 实现 Hook CLI**

`Sources/CCSentinelHook/main.swift` reads all stdin bytes, calls `HookForwarder.forward`, and exits `0` even when fallback succeeds. It exits `2` only when stdin is empty or fallback write fails.

- [ ] **Step 5: Verify and commit / 验证并提交**

Run:

```bash
swift test --filter HookCLITests
swift build --product cc-sentinel-hook
printf '{"hook_event_name":"SessionStart","session_id":"manual","cwd":"/tmp"}' | .build/debug/cc-sentinel-hook
git add Sources Tests
git commit -m "feat: receive hook events locally"
```

Expected: test passes; CLI exits `0` and writes fallback when the app receiver is not running.

---

### Task 6: VS Code Wrapper / VS Code 进程 Wrapper

**Files:**
- Modify: `Sources/CCSentinelWrapper/main.swift`
- Create: `Tests/CCSentinelCoreTests/WrapperArgumentTests.swift`

- [ ] **Step 1: Write pass-through argument test / 编写参数透传测试**

Test a pure parser:

```swift
func testWrapperSeparatesRealClaudeBinaryFromArguments() {
    let parsed = WrapperArguments.parse(["/usr/local/bin/claude", "--dangerously-skip-permissions", "prompt"])
    XCTAssertEqual(parsed.realClaudeBinary, "/usr/local/bin/claude")
    XCTAssertEqual(parsed.forwardedArguments, ["--dangerously-skip-permissions", "prompt"])
}
```

- [ ] **Step 2: Implement wrapper behavior / 实现 wrapper 行为**

Behavior:

```text
1. First argument is the real Claude binary path.
2. Remaining arguments are passed unchanged to that binary.
3. Before launch, emit wrapperProcessStart with source=vscode.
4. After exit, emit wrapperProcessEnd with source=vscode.
5. Exit with the same exit code as the real Claude process.
```

- [ ] **Step 3: Verify and commit / 验证并提交**

Run:

```bash
swift test --filter WrapperArgumentTests
swift build --product cc-sentinel-wrapper
git add Sources Tests
git commit -m "feat: add VS Code Claude wrapper"
```

Expected: wrapper parser tests pass; executable builds.

---

### Task 7: Safe Claude Settings Installer / 安全 Claude 设置安装器

**Files:**
- Create: `Sources/CCSentinelCore/HookSettingsInstaller.swift`
- Create: `Tests/CCSentinelCoreTests/HookSettingsInstallerTests.swift`

- [ ] **Step 1: Write installer tests / 编写安装器测试**

Cover preview, backup naming, merge preservation, and uninstall:

```swift
func testInstallerPreservesUnrelatedSettingsAndAddsManagedHook() throws {
    let existing = #"{"theme":"dark","hooks":{"Stop":[{"command":"echo keep"}]}}"#
    let result = try HookSettingsInstaller.previewInstall(existingSettingsJSON: existing, hookBinaryPath: "/opt/cc/cc-sentinel-hook")

    XCTAssertTrue(result.previewJSON.contains("\"theme\""))
    XCTAssertTrue(result.previewJSON.contains("echo keep"))
    XCTAssertTrue(result.previewJSON.contains("cc-sentinel-hook"))
    XCTAssertTrue(result.previewJSON.contains("cc-sentinel-managed"))
}
```

- [ ] **Step 2: Implement installer / 实现安装器**

Installer rules:

```text
Read ~/.claude/settings.json.
If missing, treat as empty object.
Before writing, create ~/.claude/settings.json.cc-sentinel-backup-YYYYMMDD-HHMMSS.
Add managed hook entries with marker "cc-sentinel-managed": true.
Never remove unmarked hook entries.
Uninstall removes only entries where "cc-sentinel-managed" is true.
Return a preview string before apply.
```

- [ ] **Step 3: Verify and commit / 验证并提交**

Run:

```bash
swift test --filter HookSettingsInstallerTests
git add Sources/CCSentinelCore/HookSettingsInstaller.swift Tests/CCSentinelCoreTests/HookSettingsInstallerTests.swift
git commit -m "feat: safely install Claude hooks"
```

Expected: installer tests pass.

---

### Task 8: Bilingual Localization / 中英文 UI 本地化

**Files:**
- Create: `Sources/CCSentinelCore/LocalizationKeys.swift`
- Create: `Sources/CCSentinelApp/Resources/en.lproj/Localizable.strings`
- Create: `Sources/CCSentinelApp/Resources/zh-Hans.lproj/Localizable.strings`
- Create: `Tests/CCSentinelCoreTests/LocalizationCoverageTests.swift`

- [ ] **Step 1: Define required keys / 定义必需文案键**

Create keys:

```swift
public enum L10nKey: String, CaseIterable {
    case appName = "app.name"
    case statusIdle = "status.idle"
    case statusRunning = "status.running"
    case statusWaitingApproval = "status.waiting_approval"
    case statusDegraded = "status.degraded"
    case sessionsTitle = "sessions.title"
    case autoApprovalPolicy = "auto_approval.policy"
    case autoApprovedToday = "auto_approval.today"
    case autoApprovedTotal = "auto_approval.total"
    case installHooks = "actions.install_hooks"
    case uninstallHooks = "actions.uninstall_hooks"
    case pauseMonitoring = "actions.pause_monitoring"
    case clearStale = "actions.clear_stale"
}
```

- [ ] **Step 2: Add English strings / 添加英文文案**

`Sources/CCSentinelApp/Resources/en.lproj/Localizable.strings`:

```text
"app.name" = "CC Sentinel";
"status.idle" = "Idle";
"status.running" = "Running";
"status.waiting_approval" = "Waiting Approval";
"status.degraded" = "Degraded";
"sessions.title" = "Sessions";
"auto_approval.policy" = "Auto approval policy";
"auto_approval.today" = "Today auto-approved";
"auto_approval.total" = "Total auto-approved";
"actions.install_hooks" = "Install hooks";
"actions.uninstall_hooks" = "Uninstall hooks";
"actions.pause_monitoring" = "Pause monitoring";
"actions.clear_stale" = "Clear stale";
```

- [ ] **Step 3: Add Simplified Chinese strings / 添加简体中文文案**

`Sources/CCSentinelApp/Resources/zh-Hans.lproj/Localizable.strings`:

```text
"app.name" = "CC Sentinel";
"status.idle" = "空闲";
"status.running" = "运行中";
"status.waiting_approval" = "等待审批";
"status.degraded" = "状态降级";
"sessions.title" = "会话";
"auto_approval.policy" = "自动审批策略";
"auto_approval.today" = "今日自动同意";
"auto_approval.total" = "总共自动同意";
"actions.install_hooks" = "安装 hooks";
"actions.uninstall_hooks" = "卸载 hooks";
"actions.pause_monitoring" = "暂停监控";
"actions.clear_stale" = "清理过期";
```

- [ ] **Step 4: Test coverage / 测试文案覆盖**

`LocalizationCoverageTests` loads both `.strings` files and asserts every `L10nKey.allCases` key exists in both languages.

- [ ] **Step 5: Verify and commit / 验证并提交**

Run:

```bash
swift test --filter LocalizationCoverageTests
git add Sources/CCSentinelCore/LocalizationKeys.swift Sources/CCSentinelApp/Resources Tests/CCSentinelCoreTests/LocalizationCoverageTests.swift
git commit -m "feat: add bilingual UI strings"
```

Expected: every user-facing key has English and Simplified Chinese text.

---

### Task 9: Menu Bar UI / 状态栏界面

**Files:**
- Create: `Sources/CCSentinelApp/AppDelegate.swift`
- Create: `Sources/CCSentinelApp/MenuBarController.swift`
- Create: `Sources/CCSentinelApp/StatusPopoverView.swift`
- Create: `Sources/CCSentinelApp/SettingsView.swift`
- Modify: `Sources/CCSentinelApp/CCSentinelApp.swift`

- [ ] **Step 1: Implement status item lifecycle / 实现状态栏生命周期**

`AppDelegate` creates an `NSStatusItem`, attaches a SwiftUI popover, and starts `EventReceiver`.

UI states:

```text
idle -> graphite icon, no animation
running -> green icon, subtle sweep animation
waitingApproval -> amber icon with red attention dot
degraded -> red icon
autoApprovalEnabled -> red switch plus visible counter section
```

- [ ] **Step 2: Implement popover layout / 实现弹窗布局**

`StatusPopoverView` renders:

```text
Header: app name, aggregate subtitle, language-aware strings
Summary: aggregate status and detail
Sessions: source badge, cwd, status, last tool, last event
State controls: pause monitoring, clear stale, copy details
Auto approval stats: today count, total count, last audit event
Settings links: install hooks, uninstall hooks, privacy
```

- [ ] **Step 3: Add manual UI verification / 添加人工 UI 验证步骤**

Run:

```bash
swift run CCSentinelApp
```

Expected:

```text
Menu bar item appears.
Click opens popover.
Switching macOS language preference between English and Simplified Chinese changes UI strings after relaunch.
No user-visible string remains hard-coded in `StatusPopoverView.swift`.
```

- [ ] **Step 4: Commit / 提交**

Run:

```bash
git add Sources/CCSentinelApp
git commit -m "feat: add menu bar status UI"
```

---

### Task 10: Auto-Approval Policy Foundation And Statistics / 自动审批策略基础与统计

**Files:**
- Create: `Sources/CCSentinelCore/ApprovalPolicy.swift`
- Create: `Sources/CCSentinelCore/AutoApprovalStats.swift`
- Create: `Tests/CCSentinelCoreTests/ApprovalPolicyTests.swift`
- Create: `Tests/CCSentinelCoreTests/AutoApprovalStatsTests.swift`
- Modify: `Sources/CCSentinelApp/StatusPopoverView.swift`

- [ ] **Step 1: Write policy tests / 编写策略测试**

```swift
func testDefaultPolicyAsksForEveryTool() {
    let decision = ApprovalPolicy.default.evaluate(tool: "Bash", command: "pnpm test", cwd: "/repo", workspace: "/repo")
    XCTAssertEqual(decision, .ask)
}

func testLowRiskReadCanBeAllowedWhenUserOptedIn() {
    var policy = ApprovalPolicy.default
    policy.allowWorkspaceReads = true
    let decision = policy.evaluate(tool: "Read", command: "README.md", cwd: "/repo", workspace: "/repo")
    XCTAssertEqual(decision, .allow)
}

func testGitPushIsDeniedByDefault() {
    let decision = ApprovalPolicy.default.evaluate(tool: "Bash", command: "git push origin main", cwd: "/repo", workspace: "/repo")
    XCTAssertEqual(decision, .deny)
}
```

- [ ] **Step 2: Write stats tests / 编写统计测试**

```swift
func testRecordingAutoApprovalIncrementsTodayAndTotal() {
    var stats = AutoApprovalStats()
    stats.record(toolName: "Read", summary: "README.md", at: Date(timeIntervalSince1970: 1_800_000_000))

    XCTAssertEqual(stats.todayCount(now: Date(timeIntervalSince1970: 1_800_000_100)), 1)
    XCTAssertEqual(stats.totalCount, 1)
    XCTAssertEqual(stats.lastEvent?.toolName, "Read")
}
```

- [ ] **Step 3: Implement policy / 实现策略**

Rules:

```text
Default: ask
Read inside workspace: allow only when allowWorkspaceReads is true
Edit inside workspace: allow only when allowWorkspaceEdits is true
Package installs: ask
Network commands: ask
git push: deny
rm -rf, chmod -R, sudo, workspace-external writes: deny
```

- [ ] **Step 4: Implement stats / 实现统计**

`AutoApprovalStats` stores audit events with `toolName`, `summary`, `workspace`, and `approvedAt`. It exposes `todayCount(now:)`, `totalCount`, and `lastEvent`.

- [ ] **Step 5: Wire UI counters / 接入 UI 统计**

`StatusPopoverView` displays:

```text
今日自动同意 / Today auto-approved
总共自动同意 / Total auto-approved
最近一次记录 / Last auto allow
```

The section remains visible even when policy is off, with counts set by stored audit data.

- [ ] **Step 6: Verify and commit / 验证并提交**

Run:

```bash
swift test --filter ApprovalPolicyTests
swift test --filter AutoApprovalStatsTests
git add Sources Tests
git commit -m "feat: add auto approval policy stats"
```

Expected: policy defaults to safe decisions; counters increment only when a recorded auto approval exists.

---

### Task 11: Documentation And Acceptance QA / 文档与验收 QA

**Files:**
- Create: `docs/installation.zh-CN.md`
- Create: `docs/installation.en.md`
- Create: `docs/privacy.zh-CN.md`
- Create: `docs/privacy.en.md`
- Create: `docs/qa-checklist.md`

- [ ] **Step 1: Write bilingual install docs / 编写双语安装文档**

Docs must include:

```text
What hooks are installed
Where backups are stored
How to uninstall
What data is stored locally
How to pause monitoring
How to disable auto approval policy
```

- [ ] **Step 2: Write QA checklist / 编写 QA 清单**

`docs/qa-checklist.md` must include these acceptance checks:

```text
CLI session appears after SessionStart.
VS Code wrapper session appears with source=vscode.
PermissionRequest changes menu bar state within 1 second.
PostToolUse clears waiting approval.
Two concurrent sessions are displayed independently.
Stale timeout marks sessions stale.
Installer creates backup and preserves unrelated settings.
Uninstall removes only CC Sentinel-managed hook entries.
English and Simplified Chinese strings both render.
Auto approval is off by default.
Today and total auto-approval counters match audit events.
```

- [ ] **Step 3: Run full verification / 运行完整验证**

Run:

```bash
swift test
swift build
swift run CCSentinelApp
```

Expected:

```text
All XCTest cases pass.
All targets build.
App launches and shows menu bar item.
Manual QA checklist is completed with notes in docs/qa-checklist.md.
```

- [ ] **Step 4: Commit / 提交**

Run:

```bash
git add docs Sources Tests Package.swift
git commit -m "docs: add bilingual installation and QA guide"
```

---

## Acceptance Criteria Mapping / 验收标准映射

- CLI hooks active session: Tasks 3, 4, 5.
- VS Code extension session source: Task 6.
- Approval-needed state within 1 second: Tasks 4, 5, 9.
- Approval state clears after tool completion/failure: Task 4.
- Multiple concurrent sessions: Tasks 2, 4, 9.
- Stale session cleanup: Tasks 2, 4, 11.
- Safe hook backup and merge: Task 7.
- Managed uninstall only: Task 7.
- Automatic approval disabled by default: Task 10.
- Today/total auto-approval statistics: Task 10.
- English and Simplified Chinese support: Task 8 and Task 11.

## Self-Review / 自检

- Spec coverage: MVP monitoring, hooks, VS Code wrapper, process fallback posture, installer safety, session state, approval detection, privacy, bilingual UI, and auto-approval stats are covered by Tasks 2-11.
- Placeholder scan: This plan contains concrete files, commands, expected outcomes, and starter code for test-first implementation.
- Type consistency: `NormalizedEvent`, `ClaudeSession`, `SessionStore`, `AggregateStatus`, `ApprovalPolicy`, and `AutoApprovalStats` names are introduced before later tasks use them.
- Scope control: Remote machines, SSH, cloud IDE support, unrestricted auto approval, and optional VS Code companion extension are outside this implementation plan.

## Execution Options / 执行方式

1. **Subagent-Driven (recommended) / 子任务代理执行（推荐）**  
   Dispatch one fresh subagent per task, review each diff, then continue.

2. **Inline Execution / 当前会话内执行**  
   Execute tasks in this session using `superpowers:executing-plans`, with checkpoints after each milestone.
