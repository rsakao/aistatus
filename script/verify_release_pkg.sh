#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 path/to/AIStatus.pkg" >&2
  exit 2
fi

PKG_PATH="$1"
if [[ ! -f "$PKG_PATH" || "$PKG_PATH" != *.pkg ]]; then
  echo "A .pkg file is required" >&2
  exit 2
fi

pkgutil --check-signature "$PKG_PATH"
PAYLOAD_FILES="$(pkgutil --payload-files "$PKG_PATH")"
for required_file in \
  "./AIStatus.app/Contents/Info.plist" \
  "./AIStatus.app/Contents/MacOS/AIStatus" \
  "./AIStatus.app/Contents/Resources/AppIcon.icns" \
  "./AIStatus.app/Contents/Resources/Assets.car"; do
  if ! printf '%s\n' "$PAYLOAD_FILES" | grep -Fqx "$required_file"; then
    echo "Missing installer payload file: $required_file" >&2
    exit 1
  fi
done

if xcrun stapler validate "$PKG_PATH" >/dev/null 2>&1; then
  spctl --assess --type install --verbose=2 "$PKG_PATH"
  echo "Signature, notarization ticket, and installer assessment are valid."
else
  echo "The package has no valid notarization ticket and must not be published." >&2
  exit 1
fi
