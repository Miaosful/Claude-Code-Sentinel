#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STORE_PATH="${CC_SENTINEL_SIM_STORE_PATH:-/tmp/cc-sentinel-simulated-store.json}"
AUTO_SETTINGS_PATH="${CC_SENTINEL_SIM_AUTO_SETTINGS_PATH:-/tmp/cc-sentinel-simulated-auto-settings.json}"
AUTO_STATS_PATH="${CC_SENTINEL_SIM_AUTO_STATS_PATH:-/tmp/cc-sentinel-simulated-auto-stats.json}"
PORT="${CC_SENTINEL_PORT:-47291}"
ENDPOINT="http://127.0.0.1:${PORT}/events"
FALLBACK_PATH="${CC_SENTINEL_SIM_FALLBACK_PATH:-/tmp/cc-sentinel-simulated-fallback.jsonl}"
SESSION_ID="${CC_SENTINEL_SESSION_ID:-simulated-session}"

cd "$ROOT_DIR"

SWIFT_BUILD_FLAGS=()
if [[ -n "${CC_SENTINEL_SWIFT_BUILD_FLAGS:-}" ]]; then
    IFS=' ' read -r -a SWIFT_BUILD_FLAGS <<< "$CC_SENTINEL_SWIFT_BUILD_FLAGS"
fi
if [[ ${#SWIFT_BUILD_FLAGS[@]} -gt 0 ]]; then
    swift build "${SWIFT_BUILD_FLAGS[@]}"
else
    swift build
fi

rm -f "$STORE_PATH" "$FALLBACK_PATH" "$AUTO_SETTINGS_PATH" "$AUTO_STATS_PATH"

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
    local expected="$3"

    printf '\n== %s ==\n' "$name"
    printf '%s' "$body" | \
        CC_SENTINEL_ENDPOINT="$ENDPOINT" \
        CC_SENTINEL_FALLBACK_PATH="$FALLBACK_PATH" \
        .build/debug/cc-sentinel-hook
    wait_for_status "$expected"
}

wait_for_status() {
    local expected="$1"
    local dump=""
    for _ in {1..20}; do
        dump="$(CC_SENTINEL_STORE_PATH="$STORE_PATH" .build/debug/cc-sentinel-dump-state)"
        if [[ "$dump" == *"aggregate_status: ${expected}"* ]]; then
            printf '%s\n' "$dump"
            return 0
        fi
        sleep 0.1
    done

    printf '%s\n' "$dump"
    printf '\nExpected aggregate_status: %s\n' "$expected" >&2
    if [[ -f "$FALLBACK_PATH" ]]; then
        printf '\nFallback events:\n' >&2
        cat "$FALLBACK_PATH" >&2
    fi
    return 1
}

send_event "SessionStart" \
"{\"hook_event_name\":\"SessionStart\",\"session_id\":\"${SESSION_ID}\",\"source\":\"vscode\",\"cwd\":\"${ROOT_DIR}\"}" \
"running"

send_event "PermissionRequest" \
"{\"hook_event_name\":\"PermissionRequest\",\"session_id\":\"${SESSION_ID}\",\"source\":\"vscode\",\"cwd\":\"${ROOT_DIR}\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"pnpm test\"},\"permission_mode\":\"default\"}" \
"waiting_approval"

send_event "PostToolUse" \
"{\"hook_event_name\":\"PostToolUse\",\"session_id\":\"${SESSION_ID}\",\"source\":\"vscode\",\"cwd\":\"${ROOT_DIR}\",\"tool_name\":\"Bash\"}" \
"running"

cat > "$AUTO_SETTINGS_PATH" <<JSON
{
  "enabled" : true,
  "policy" : {
    "allowWorkspaceEdits" : false,
    "allowWorkspaceReads" : true
  },
  "workspace" : "$ROOT_DIR"
}
JSON

printf '\n== PermissionRequest Auto Approval ==\n'
auto_output="$(
    printf '%s' "{\"hook_event_name\":\"PermissionRequest\",\"session_id\":\"${SESSION_ID}\",\"source\":\"vscode\",\"cwd\":\"${ROOT_DIR}\",\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"${ROOT_DIR}/Package.swift\"}}" | \
        CC_SENTINEL_ENDPOINT="$ENDPOINT" \
        CC_SENTINEL_FALLBACK_PATH="$FALLBACK_PATH" \
        CC_SENTINEL_AUTO_APPROVAL_SETTINGS_PATH="$AUTO_SETTINGS_PATH" \
        CC_SENTINEL_AUTO_APPROVAL_STATS_PATH="$AUTO_STATS_PATH" \
        .build/debug/cc-sentinel-hook
)"
printf '%s\n' "$auto_output"
printf 'Auto approval stats: '
cat "$AUTO_STATS_PATH"
printf '\n'

printf '\nStore path: %s\n' "$STORE_PATH"
printf 'Auto approval settings path: %s\n' "$AUTO_SETTINGS_PATH"
printf 'Auto approval stats path: %s\n' "$AUTO_STATS_PATH"
