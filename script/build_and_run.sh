#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="CCSentinelApp"
BUNDLE_ID="app.ccsentinel.CCSentinelApp"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
APP_RESOURCE_BUNDLE="$APP_BUNDLE/CCSentinel_CCSentinelApp.bundle"
INFO_PLIST="$APP_CONTENTS/Info.plist"
BUILD_FLAGS=()

if [[ -n "${CC_SENTINEL_SWIFT_BUILD_FLAGS:-}" ]]; then
    IFS=' ' read -r -a BUILD_FLAGS <<< "$CC_SENTINEL_SWIFT_BUILD_FLAGS"
fi

cd "$ROOT_DIR"

if [[ "$MODE" != "package" && "$MODE" != "--package" ]]; then
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi

if [[ ${#BUILD_FLAGS[@]} -gt 0 ]]; then
    swift build --product "$APP_NAME" "${BUILD_FLAGS[@]}"
else
    swift build --product "$APP_NAME"
fi
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"
BUILD_BIN_DIR="$(swift build --show-bin-path)"
BUILD_RESOURCE_BUNDLE="$BUILD_BIN_DIR/CCSentinel_CCSentinelApp.bundle"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
if [[ -d "$BUILD_RESOURCE_BUNDLE" ]]; then
    cp -R "$BUILD_RESOURCE_BUNDLE" "$APP_RESOURCE_BUNDLE"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>CC Sentinel</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
    local open_args=(-n)
    if [[ -n "${CC_SENTINEL_APP_SUPPORT_DIR:-}" ]]; then
        open_args+=(--env "CC_SENTINEL_APP_SUPPORT_DIR=$CC_SENTINEL_APP_SUPPORT_DIR")
    fi
    if [[ -n "${CC_SENTINEL_OPEN_POPOVER_ON_LAUNCH:-}" ]]; then
        open_args+=(--env "CC_SENTINEL_OPEN_POPOVER_ON_LAUNCH=$CC_SENTINEL_OPEN_POPOVER_ON_LAUNCH")
    fi
    /usr/bin/open "${open_args[@]}" "$APP_BUNDLE"
}

case "$MODE" in
    run)
        open_app
        ;;
    --debug|debug)
        lldb -- "$APP_BINARY"
        ;;
    --logs|logs)
        open_app
        /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
        ;;
    --telemetry|telemetry)
        open_app
        /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
        ;;
    --verify|verify)
        open_app
        sleep 1
        pgrep -x "$APP_NAME" >/dev/null
        ;;
    --package|package)
        printf 'Packaged %s\n' "$APP_BUNDLE"
        ;;
    *)
        echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--package]" >&2
        exit 2
        ;;
esac
