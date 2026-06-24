# CC Sentinel Requirements

Date: 2026-06-24
Status: Draft for review

## 1. Purpose

CC Sentinel is a macOS menu bar utility for monitoring Claude Code activity across local Claude Code CLI sessions and Claude Code sessions launched from the VS Code extension. It gives users a lightweight, always-visible signal for whether Claude Code is idle, running, waiting for approval, or operating with automatic approval policies.

The product should avoid fragile UI scraping. Its primary data source should be Claude Code lifecycle hooks, with VS Code process wrapping and process detection used only as supporting signals.

## 2. Problem Statement

Claude Code can run in multiple places at once: a standalone terminal, a VS Code integrated terminal, or the VS Code Claude Code extension. Users currently need to switch context to see whether Claude Code is still working, has finished, or is blocked on a permission approval prompt.

This is especially painful when Claude Code is running in the background or inside a hidden VS Code tab. The user wants a macOS status indicator that answers:

- Is Claude Code active?
- Is any session waiting for approval?
- Which project or session needs attention?
- Can low-risk approval prompts be handled automatically under a user-controlled policy?

## 3. Goals

- Show a macOS menu bar status for Claude Code activity.
- Support both Claude Code CLI and VS Code extension sessions where Claude Code hooks are available.
- Track multiple sessions independently by `session_id`.
- Detect permission approval prompts using Claude Code hooks.
- Show session source, current workspace, last tool, and approval state in a menu.
- Provide an installer that can add, update, and remove CC Sentinel hook configuration safely.
- Keep monitoring reliable without reading or controlling VS Code UI internals.
- Defer automatic approval to a controlled second phase with explicit safety boundaries.

## 4. Non-Goals

- Do not scrape VS Code UI, terminal screen text, or accessibility trees as the primary monitoring method.
- Do not promise perfect monitoring for Claude Code versions or environments where hooks are disabled or unavailable.
- Do not silently modify user Claude Code settings without preview, backup, and uninstall support.
- Do not enable unrestricted automatic approval by default.
- Do not replace Claude Code's permission system.
- Do not support remote machines, SSH sessions, or cloud IDEs in the MVP.

## 5. Target Users

- Developers who run Claude Code for long-running coding tasks.
- Users who work across several repositories and VS Code windows.
- Users who want a clear visual signal when Claude Code needs approval.
- Advanced users who may later want policy-based automatic approval for low-risk operations.

## 6. Product Surface

### 6.1 Menu Bar Indicator

The menu bar item should communicate the aggregate state:

- Idle: no known active Claude Code session.
- Running: at least one active session is running.
- Waiting for approval: at least one session is blocked on a permission request.
- Auto-approval enabled: automatic approval policy is active for at least one session or globally.
- Degraded: hook events are stale, local event service is unavailable, or state may be incomplete.

The visual representation can use different icons, colors, or subtle animation. Exact branding and artwork are outside this requirements document.

### 6.2 Menu Contents

Clicking the menu bar item should show:

- Overall status.
- Active session count.
- Session list grouped by source: CLI, VS Code, or unknown.
- For each session:
  - source
  - `session_id`
  - `cwd`
  - current status
  - permission mode if known
  - latest tool name if known
  - latest approval request summary if present
  - last event timestamp
- Actions:
  - open project folder
  - copy session details
  - open Claude settings file
  - install or update hooks
  - uninstall hooks
  - pause monitoring
  - clear stale sessions

## 7. Data Sources

### 7.1 Claude Code Hooks

Claude Code hooks are the primary data source. CC Sentinel should provide hook commands that receive Claude Code hook JSON on stdin and forward normalized events to the local event service.

Required hook events for MVP:

- `SessionStart`: create or refresh a session.
- `PermissionRequest`: mark a session as waiting for approval.
- `PostToolUse`: clear a matching approval wait state and record tool completion.
- `PostToolUseFailure`: clear a matching approval wait state and record failure.
- `Stop`: mark a turn as complete or idle when applicable.
- `SessionEnd`: remove or close a session.
- `Notification` with `permission_prompt`: optional secondary signal for attention, not the primary approval state.

The hook handler should preserve relevant fields where available:

- `session_id`
- `cwd`
- `transcript_path`
- `permission_mode`
- `tool_name`
- `tool_input`
- `tool_response`
- hook event name
- event timestamp

### 7.2 VS Code Claude Process Wrapper

The VS Code extension can be configured with a Claude process wrapper. CC Sentinel should provide a wrapper executable for source detection and lifecycle enhancement.

The wrapper should:

- report process start and process end
- tag sessions or events as likely `vscode`
- pass through all arguments to the real Claude binary
- avoid changing Claude Code behavior
- avoid interpreting approval state itself

The wrapper is not the source of truth for permission prompts.

### 7.3 Process Detection

Process detection should be a fallback only. It can help detect whether any Claude-related process exists, but it cannot reliably identify session state or permission state by itself.

Process detection may be used to:

- show degraded "Claude process detected but no hook events" status
- clean up stale sessions when the related process is gone
- help distinguish CLI and VS Code sources when combined with wrapper data

## 8. Event Service

CC Sentinel should run a local event service that receives normalized events from hook scripts and wrappers.

Acceptable transport options:

- localhost HTTP endpoint
- Unix domain socket
- append-only JSONL file as a fallback

Recommended MVP transport:

- localhost HTTP for simplicity, with a file fallback if the menu bar app is not running.

Requirements:

- accept events from hook commands quickly
- avoid blocking Claude Code execution
- validate event shape
- normalize and persist session state
- tolerate duplicate, missing, and out-of-order events
- redact or truncate sensitive tool input in UI where appropriate

## 9. Session State Model

State must be session-scoped, not global-only.

Each session should have:

- `session_id`
- `source`: `cli`, `vscode`, or `unknown`
- `cwd`
- `status`: `running`, `waiting_approval`, `idle`, `ended`, `stale`, or `error`
- `permission_mode`
- `last_tool_name`
- `last_tool_summary`
- `last_event_at`
- `waiting_since`
- `approval_request`

Aggregate menu bar state priority:

1. Any session `waiting_approval`: show approval-needed state.
2. Any session `running`: show running state.
3. Any stale or degraded signal: show degraded state.
4. Otherwise: show idle state.

## 10. Approval Detection

`PermissionRequest` should be the primary trigger for `waiting_approval`.

When CC Sentinel receives a `PermissionRequest` event:

- mark the session as `waiting_approval`
- record tool name and a safe summary of tool input
- update the menu bar icon immediately
- optionally send a macOS notification if enabled

The waiting state should clear when:

- a matching `PostToolUse` arrives
- a matching `PostToolUseFailure` arrives
- a `Stop` event indicates the current turn ended
- `SessionEnd` arrives
- the session exceeds a configurable stale timeout
- the user manually clears stale state

`Notification(permission_prompt)` can be used as a secondary signal when `PermissionRequest` is unavailable, but it should not override richer `PermissionRequest` state.

## 11. Automatic Approval

Automatic approval is not part of the MVP default behavior. It should be implemented only after passive monitoring is reliable.

When implemented, automatic approval must be policy-based:

- disabled by default
- visible in the menu bar when enabled
- scoped by workspace, source, tool, and risk level
- auditable through an event log
- reversible through a simple global off switch

Suggested policy decisions:

- Allow low-risk reads and workspace-local edits only when the user opts in.
- Ask for package installs, network commands, git push, destructive file operations, shell commands outside the workspace, and access to sensitive paths.
- Deny known dangerous patterns by default.

The tool should avoid unrestricted automatic approval. If it exposes a mode equivalent to skipping permissions, it must show strong warnings and recommend isolated environments such as containers or VMs.

## 12. Settings Installation

CC Sentinel should provide an installation flow for Claude Code integration.

Installer requirements:

- inspect existing `~/.claude/settings.json`
- preview changes before applying
- create a timestamped backup before writing
- merge hooks without deleting unrelated user settings
- support uninstall by removing only CC Sentinel-managed entries
- record an installation marker so future updates are safe
- explain what data is collected and where it is stored

MVP may support a manual install command before a polished UI installer exists.

## 13. Privacy and Security

CC Sentinel runs locally and should not send event data to external services.

Sensitive data handling:

- Store full raw events only if the user enables diagnostic logging.
- Redact or truncate command arguments and file contents in menu UI.
- Avoid displaying secrets from tool input.
- Keep local state under the user's Library/Application Support directory.
- Make logs easy to clear.

Security posture:

- Hooks and wrappers should be small and auditable.
- Event receiver should listen only on localhost or a Unix domain socket.
- Event receiver should reject malformed events.
- Automatic approval should require explicit opt-in.

## 14. MVP Scope

The first usable version should include:

- macOS menu bar app.
- Local event receiver.
- Hook script for Claude Code event forwarding.
- Safe installer for hook configuration.
- Session state store.
- Multi-session menu display.
- Approval-needed state based on `PermissionRequest`.
- Secondary notification handling for `permission_prompt`.
- Stale session cleanup.
- VS Code wrapper for source/lifecycle tagging.
- Manual pause, clear, and uninstall actions.

MVP should not include unrestricted automatic approval.

## 15. Later Phases

Phase 2:

- Policy-based automatic approval.
- Per-workspace approval profiles.
- More detailed audit log.
- Config UI for allow, ask, and deny rules.
- macOS notifications with action buttons where appropriate.

Phase 3:

- Richer VS Code integration through an optional companion extension if needed.
- Better session-to-window mapping.
- Menu bar animation and polished icon themes.
- Team or shared policy templates.
- Support for remote environments if Claude Code exposes reliable local events for them.

## 16. Open Questions

- Should the MVP be Swift/SwiftUI native, or should it use a cross-platform shell such as Tauri or Electron?
- Should the event transport be localhost HTTP or Unix domain socket for the first version?
- How much raw `tool_input` should be retained for audit versus redacted for privacy?
- Should source detection rely on `claudeProcessWrapper`, environment variables, process ancestry, or all three?
- What is the minimum acceptable behavior when hooks are not installed or fail?
- Should automatic approval be a paid/pro/advanced feature, or remain hidden behind an explicit advanced settings flag?

## 17. Acceptance Criteria

- When a Claude Code CLI session starts and hooks are installed, CC Sentinel shows an active session.
- When a VS Code extension session starts through the wrapper and hooks are installed, CC Sentinel shows a VS Code-sourced session.
- When Claude Code emits a `PermissionRequest`, the menu bar state changes to waiting for approval within one second under normal local conditions.
- When the related tool finishes or fails, the waiting state clears.
- Multiple concurrent sessions are shown independently.
- If hook events stop arriving, stale sessions are eventually marked stale instead of staying permanently active.
- Installing hooks backs up existing Claude settings and does not remove unrelated settings.
- Uninstalling removes only CC Sentinel-managed hook entries.
- Automatic approval is not enabled by default.

## 18. References

- Claude Code hooks: https://code.claude.com/docs/en/hooks
- Claude Code permissions: https://code.claude.com/docs/en/permissions
- Claude Code VS Code integration: https://code.claude.com/docs/en/vs-code
