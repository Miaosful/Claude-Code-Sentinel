# CC Sentinel QA Checklist

Date: 2026-06-24

## Automated Checks

- [x] `swift run CCSentinelCoreTestRunner`
- [x] `swift build`

## Acceptance Checks

- [x] CLI session can be represented after `SessionStart` normalization.
- [x] VS Code wrapper lifecycle events normalize with `source=vscode`.
- [x] `PermissionRequest` changes session and aggregate state to waiting approval.
- [x] `PostToolUse` clears waiting approval state.
- [x] Multiple concurrent sessions are represented independently in `SessionStore`.
- [x] Stale timeout marks old active sessions as stale.
- [x] Installer preview preserves unrelated settings and existing hooks.
- [x] Installer apply writes a timestamped backup before changing settings.
- [x] Uninstall preview removes only CC Sentinel-managed hook entries.
- [x] Uninstall apply writes a backup and removes only managed hook entries.
- [x] English and Simplified Chinese localization keys are covered.
- [x] Auto approval is off by default through `ApprovalPolicy.default`.
- [x] Today and total auto-approval counters match audit events.
- [x] Session store persists to and loads from JSON.

## Manual Smoke Checks

- [x] `cc-sentinel-hook` writes fallback JSONL when receiver is unavailable.
- [x] `cc-sentinel-wrapper` passes through `/bin/echo hello` and writes start/end lifecycle fallback events.
- [x] `CCSentinelApp` builds and launches briefly from SwiftPM.

## Remaining MVP Gaps

- UI-driven install/uninstall actions.
- Rich visual polish and final menu bar animation states.
