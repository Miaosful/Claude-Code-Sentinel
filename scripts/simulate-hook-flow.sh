#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STORE_PATH="${CC_SENTINEL_SIM_STORE_PATH:-/tmp/cc-sentinel-simulated-store.json}"
PORT="${CC_SENTINEL_PORT:-47291}"
ENDPOINT="http://127.0.0.1:${PORT}/events"
FALLBACK_PATH="${CC_SENTINEL_SIM_FALLBACK_PATH:-/tmp/cc-sentinel-simulated-fallback.jsonl}"
SESSION_ID="${CC_SENTINEL_SESSION_ID:-simulated-session}"

cd "$ROOT_DIR"

swift build

rm -f "$STORE_PATH" "$FALLBACK_PATH"

CC_SENTINEL_STORE_PATH="$STORE_PATH" \
CC_SENTINEL_PORT="$PORT" \
.build/debug/cc-sentinel-debug-receiver &
RECEIVER_PID="$!"

cleanup() {
    kill "$RECEIVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

sleep 0.4

send_event() {
    local name="$1"
    local body="$2"

    printf '\n== %s ==\n' "$name"
    printf '%s' "$body" | \
        CC_SENTINEL_ENDPOINT="$ENDPOINT" \
        CC_SENTINEL_FALLBACK_PATH="$FALLBACK_PATH" \
        .build/debug/cc-sentinel-hook
    sleep 0.2
    CC_SENTINEL_STORE_PATH="$STORE_PATH" .build/debug/cc-sentinel-dump-state
}

send_event "SessionStart" \
"{\"hook_event_name\":\"SessionStart\",\"session_id\":\"${SESSION_ID}\",\"source\":\"vscode\",\"cwd\":\"${ROOT_DIR}\"}"

send_event "PermissionRequest" \
"{\"hook_event_name\":\"PermissionRequest\",\"session_id\":\"${SESSION_ID}\",\"source\":\"vscode\",\"cwd\":\"${ROOT_DIR}\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"pnpm test\"},\"permission_mode\":\"default\"}"

send_event "PostToolUse" \
"{\"hook_event_name\":\"PostToolUse\",\"session_id\":\"${SESSION_ID}\",\"source\":\"vscode\",\"cwd\":\"${ROOT_DIR}\",\"tool_name\":\"Bash\"}"

printf '\nStore path: %s\n' "$STORE_PATH"
