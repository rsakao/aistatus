#!/usr/bin/env bash
set -euo pipefail

APP_NAME="AIStatus"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-}"
INSTALLER_SIGN_IDENTITY="${INSTALLER_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
ALLOW_UNSIGNED="${ALLOW_UNSIGNED:-0}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]]; then
  echo "VERSION must be a semantic version such as 1.0.0" >&2
  exit 2
fi

if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "BUILD_NUMBER must be a positive integer" >&2
  exit 2
fi

if [[ "$ALLOW_UNSIGNED" != "0" && "$ALLOW_UNSIGNED" != "1" ]]; then
  echo "ALLOW_UNSIGNED must be 0 or 1" >&2
  exit 2
fi

if [[ "$ALLOW_UNSIGNED" != "1" && ( -z "$APP_SIGN_IDENTITY" || -z "$INSTALLER_SIGN_IDENTITY" || -z "$NOTARY_PROFILE" ) ]]; then
  echo "Public packages require APP_SIGN_IDENTITY, INSTALLER_SIGN_IDENTITY, and NOTARY_PROFILE." >&2
  echo "For local structure testing only, explicitly set ALLOW_UNSIGNED=1." >&2
  exit 2
fi

if [[ -n "$NOTARY_PROFILE" && ( -z "$APP_SIGN_IDENTITY" || -z "$INSTALLER_SIGN_IDENTITY" ) ]]; then
  echo "Notarization requires APP_SIGN_IDENTITY and INSTALLER_SIGN_IDENTITY" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release-package"
DIST_DIR="$ROOT_DIR/dist/release"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
PKG_FILENAME="$APP_NAME-$VERSION-universal.pkg"
PKG_PATH="$DIST_DIR/$PKG_FILENAME"
PKG_CHECKSUM_PATH="$PKG_PATH.sha256"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ASSET_INFO_PLIST="$DIST_DIR/.asset-info.plist"
ENTITLEMENTS="$ROOT_DIR/Resources/AIStatus.entitlements"

cd "$ROOT_DIR"
swift build \
  --configuration release \
  --scratch-path "$BUILD_DIR" \
  --arch arm64 \
  --arch x86_64

BUILD_BINARY="$(swift build \
  --configuration release \
  --scratch-path "$BUILD_DIR" \
  --arch arm64 \
  --arch x86_64 \
  --show-bin-path)/$APP_NAME"

rm -rf "$DIST_DIR"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod 755 "$APP_BINARY"
cp "$ROOT_DIR/Resources/Info.plist" "$INFO_PLIST"
xcrun actool \
  --compile "$APP_RESOURCES" \
  --app-icon AppIcon \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --target-device mac \
  --output-partial-info-plist "$ASSET_INFO_PLIST" \
  "$ROOT_DIR/Resources/Assets.xcassets"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$INFO_PLIST"
xattr -cr "$APP_BUNDLE"

if [[ -n "$APP_SIGN_IDENTITY" ]]; then
  codesign \
    --force \
    --options runtime \
    --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$APP_SIGN_IDENTITY" \
    "$APP_BUNDLE"
else
  echo "Warning: APP_SIGN_IDENTITY is unset; creating a local test package with an ad hoc app signature." >&2
  codesign \
    --force \
    --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign - \
    "$APP_BUNDLE"
fi

# Remove nonessential extended attributes while preserving the code signature.
xattr -cr "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
lipo "$APP_BINARY" -verify_arch arm64 x86_64

if [[ -n "$INSTALLER_SIGN_IDENTITY" ]]; then
  COPYFILE_DISABLE=1 productbuild \
    --component "$APP_BUNDLE" /Applications \
    --sign "$INSTALLER_SIGN_IDENTITY" \
    "$PKG_PATH"
else
  echo "Warning: INSTALLER_SIGN_IDENTITY is unset; the local test package will not be trusted by Gatekeeper." >&2
  COPYFILE_DISABLE=1 productbuild --component "$APP_BUNDLE" /Applications "$PKG_PATH"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$PKG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$PKG_PATH"
  xcrun stapler validate "$PKG_PATH"
  spctl --assess --type install --verbose=2 "$PKG_PATH"
fi

(
  cd "$DIST_DIR"
  shasum -a 256 "$PKG_FILENAME" >"$PKG_FILENAME.sha256"
)

echo "Built $PKG_PATH"
echo "Checksum $PKG_CHECKSUM_PATH"
if [[ -z "$NOTARY_PROFILE" ]]; then
  echo "This package is for local validation only. Do not publish it until it is Developer ID signed and notarized." >&2
fi
