# CC Sentinel QA Checklist

Date: 2026-06-24

## Automated Checks

- [x] `swift run CCSentinelCoreTestRunner`
- [x] `swift build`
- [x] `script/build_and_run.sh --verify`
- [x] `scripts/simulate-hook-flow.sh`

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
- [x] Menu popover install/uninstall buttons call the hook settings installer.

## Manual Smoke Checks

- [x] `cc-sentinel-hook` writes fallback JSONL when receiver is unavailable.
- [x] `cc-sentinel-hook` posts to a running receiver, which persists `waiting_approval` in the session store without fallback.
- [x] `cc-sentinel-wrapper` passes through `/bin/echo hello` and writes start/end lifecycle fallback events.
- [x] `CCSentinelApp` builds as a project-local `.app` bundle and launches through `script/build_and_run.sh`.
- [x] A running `CCSentinelApp` receiver accepts `SessionStart`, `PermissionRequest`, and `PostToolUse`, then persists `running -> waiting_approval -> running`.
- [x] With opt-in auto-approval settings, a workspace-scoped `Read` permission request emits Claude Code's allow JSON and records an audit event.

## Remaining MVP Gaps

- Surfacing exact installer backup paths in the UI.
- Rich visual polish and final menu bar animation states.
