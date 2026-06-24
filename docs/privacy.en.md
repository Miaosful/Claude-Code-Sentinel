# CC Sentinel Privacy

CC Sentinel runs locally and does not send Claude Code events to external services.

## Local Data

Stored local data may include:

- session ID
- session source: CLI, VS Code, or unknown
- current working directory
- hook event name and timestamp
- latest tool name
- redacted and truncated tool input summary
- auto-approval audit events and counters

## Sensitive Data Handling

- Full raw events are not stored by default.
- Tokens, API keys, and long commands are redacted or truncated before UI display.
- The fallback JSONL file is written only when the menu bar app is unavailable.
- Logs and fallback files should have a clear cleanup path.

## Auto Approval

Auto approval must be explicit opt-in. The default policy is ask; dangerous commands such as `git push`, `rm -rf`, `sudo`, and sensitive path access are denied by default.

