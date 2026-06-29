# CC Sentinel

English | [简体中文](README.md)

CC Sentinel is a local macOS menu bar app for monitoring Claude Code session state and making pending tool approvals easier to notice.

It is built for people who use the Claude Code CLI, the VS Code Claude Code extension, or multiple Claude Code sessions at the same time. CC Sentinel receives local Claude Code hook events and shows whether sessions are running, waiting for approval, or missing hook integration.

> This project is currently a development preview. It is not an official Anthropic project, and it does not send Claude Code events to external services.

## Features

- Menu bar status: idle, running, waiting for approval, or degraded.
- Session list: source, working directory, latest tool request, and approval summary.
- VS Code support: detects VS Code Claude Code sessions and falls back to local process detection before hooks report a session.
- Hook management: install, update, or uninstall CC Sentinel-managed Claude Code hooks from the menu bar popover.
- Local auto approval: disabled by default; currently only auto-allows low-risk workspace-scoped read requests.
- Local privacy boundary: events, settings, and counters stay on your machine; tool input summaries are redacted and truncated.
- Bilingual UI: Simplified Chinese, English, and system language mode.

## How It Works

CC Sentinel is made of several local components:

- `CCSentinelApp`: the macOS menu bar app and user interface.
- `cc-sentinel-hook`: the Claude Code hook command that forwards hook JSON to the local app.
- `cc-sentinel-wrapper`: a helper for identifying Claude Code processes launched by the VS Code extension.
- `CCSentinelCore`: session state, hook normalization, auto-approval policy, and persistence.

Hook events are the primary source of truth. When hooks have not reported a session yet but a Claude Code process is detected locally, the app shows a process fallback state. Approval state still depends on hook events.

## Requirements

- macOS 14 or later
- Swift 6 / Xcode Command Line Tools
- Claude Code

## Local Run

From the repository root:

```bash
script/build_and_run.sh
```

The script builds `CCSentinelApp` and `cc-sentinel-hook`, then stages a local app bundle at:

```text
dist/CCSentinelApp.app
```

You can also run the launch verification mode:

```bash
script/build_and_run.sh --verify
```

## Hook Installation

After launching CC Sentinel, open the menu bar popover and click "Install hooks". The installer merges `~/.claude/settings.json` and adds CC Sentinel-managed command hooks for Claude Code hook events.

Before writing settings, it creates a backup:

```text
~/.claude/settings.json.cc-sentinel-backup-YYYYMMDD-HHMMSS
```

Uninstall removes only CC Sentinel-managed hooks and preserves user-defined hooks.

More details:

- [Installation](docs/installation.en.md)
- [Privacy](docs/privacy.en.md)

## Auto Approval

Auto approval is disabled by default. When enabled, the current policy only auto-allows workspace-scoped `Read` requests and records daily and total approval counters.

These actions are not auto-approved by default:

- reads outside the workspace
- file edits
- Bash commands
- `sudo`
- `rm -rf`
- `git push`
- other high-risk operations or sensitive paths

Auto-approval settings and stats are stored by default at:

```text
~/Library/Application Support/CC Sentinel/auto-approval-settings.json
~/Library/Application Support/CC Sentinel/auto-approval-stats.json
```

## Development

Run the core test runner:

```bash
swift run CCSentinelCoreTestRunner
```

Build all SwiftPM targets:

```bash
swift build
```

Run the hook flow simulation:

```bash
scripts/simulate-hook-flow.sh
```

Dump current state:

```bash
swift run cc-sentinel-dump-state
```

## Project Layout

```text
Sources/
  CCSentinelApp/          macOS menu bar app
  CCSentinelCore/         core models, hook parsing, state store, and approval policy
  CCSentinelHook/         Claude Code hook forwarder
  CCSentinelWrapper/      VS Code Claude Code process wrapper
  CCSentinelDumpState/    state debugging utility
docs/                     installation, privacy, and QA docs
script/                   app build and launch script
scripts/                  development and simulation scripts
```

## Privacy

CC Sentinel runs locally. It does not store full raw events by default, and it does not send Claude Code events to external services. Tokens, API keys, and long commands are redacted or truncated before being shown in the UI.

See [Privacy](docs/privacy.en.md).

## Contributing

Issues and pull requests are welcome. Before submitting changes, run:

```bash
swift run CCSentinelCoreTestRunner
script/build_and_run.sh --verify
```

If your change touches hook installation, session state, or auto approval, please add tests or update `docs/qa-checklist.md`.

## License

Before publishing this repository as open source, add an explicit `LICENSE` file at the repository root. This README does not assume a license.

