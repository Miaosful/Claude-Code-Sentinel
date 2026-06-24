# CC Sentinel Installation

## Installed Components

CC Sentinel includes three local components:

- `CCSentinelApp`: the macOS menu bar app.
- `cc-sentinel-hook`: the Claude Code hook event forwarder.
- `cc-sentinel-wrapper`: the process wrapper for VS Code Claude Code sessions.

## Hook Installation

The installer previews and merges `~/.claude/settings.json`, adding CC Sentinel-managed hooks for:

- `SessionStart`
- `PermissionRequest`
- `PostToolUse`
- `PostToolUseFailure`
- `Stop`
- `SessionEnd`
- `Notification`

Every CC Sentinel-managed entry is marked with `cc-sentinel-managed: true`.

## Backup And Uninstall

Before writing Claude settings, the installer should create a timestamped backup:

```text
~/.claude/settings.json.cc-sentinel-backup-YYYYMMDD-HHMMSS
```

Uninstall removes only entries marked with `cc-sentinel-managed: true`; user hooks are preserved.

## Pause And Auto Approval

Monitoring can be paused from the menu bar popover. Auto approval is disabled by default and should only allow low-risk actions covered by explicit policy.

