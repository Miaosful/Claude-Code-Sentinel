# CC Sentinel Installation

## Installed Components

CC Sentinel includes three local components:

- `CCSentinelApp`: the macOS menu bar app.
- `cc-sentinel-hook`: the Claude Code hook event forwarder.
- `cc-sentinel-wrapper`: the process wrapper for VS Code Claude Code sessions.

## Local Run

The development build can be launched through the project script:

```bash
script/build_and_run.sh
```

The script builds `CCSentinelApp`, stages a local `.app` bundle at `dist/CCSentinelApp.app`, and launches the menu bar app. Use this command for launch verification:

```bash
script/build_and_run.sh --verify
```

## Hook Installation

The installer previews and merges `~/.claude/settings.json`, adding CC Sentinel-managed hooks for:

- `SessionStart`
- `PermissionRequest`
- `PostToolUse`
- `PostToolUseFailure`
- `Stop`
- `SessionEnd`
- `Notification`

CC Sentinel-managed entries are written as Claude command hooks and are identified by the `cc-sentinel-hook` command name during upgrades and uninstall.

## Backup And Uninstall

Before writing Claude settings, the installer should create a timestamped backup:

```text
~/.claude/settings.json.cc-sentinel-backup-YYYYMMDD-HHMMSS
```

Uninstall removes only hook commands named `cc-sentinel-hook`; user hooks are preserved.

## Pause And Auto Approval

Monitoring can be paused from the menu bar popover. Auto approval is disabled by default, and the full policy lives in a local JSON config file. Importing a config backs up the current file and then replaces it as a whole. The default config is allow-only and covers workspace-scoped reads plus common low-risk inspection commands. Outside-workspace reads, edits, unlisted or compound Bash commands, `sudo`, `rm -rf`, `git push`, and other high-risk actions are not auto-approved.

Requests that are not auto-approved can be reviewed from the CC Sentinel panel with `Allow once`, `Reject once`, or `Allow similar next time`. `Reject once` is always a manual user decision; CC Sentinel does not auto-reject by policy.

Auto-approval config and stats are stored by default at:

```text
~/Library/Application Support/CC Sentinel/auto-approval-config.json
~/Library/Application Support/CC Sentinel/auto-approval-stats.json
~/Library/Application Support/CC Sentinel/pending-approvals/
~/Library/Application Support/CC Sentinel/approval-decisions/
```
