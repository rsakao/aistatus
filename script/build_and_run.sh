#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="AIStatus"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ASSET_INFO_PLIST="$DIST_DIR/.asset-info.plist"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

cd "$ROOT_DIR"
swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$ROOT_DIR/Resources/Info.plist" "$INFO_PLIST"
xcrun actool \
  --compile "$APP_RESOURCES" \
  --app-icon AppIcon \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --target-device mac \
  --output-partial-info-plist "$ASSET_INFO_PLIST" \
  "$ROOT_DIR/Resources/Assets.xcassets"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 0.0.0-dev" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 1" "$INFO_PLIST"

# Re-sign after staging because SwiftPM signs the binary before it is copied
# into the final bundle layout.
codesign --force --deep --sign - "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
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
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
