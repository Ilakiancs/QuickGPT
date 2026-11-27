#!/usr/bin/env bash
# Builds QuickGPT.app for one CPU architecture.
#
#   scripts/build-app.sh <arm64|x86_64> <output-dir> [version]
#
# Produces <output-dir>/QuickGPT.app. With a version, the bundle's CFBundleShortVersionString is
# checked against it so a release can never ship with a mismatched Info.plist.
# Used by `make build`, `make release` and the GitHub release workflow, so there's one recipe.
set -euo pipefail

ARCH="${1:?usage: build-app.sh <arm64|x86_64> <output-dir> [version]}"
OUT="${2:?usage: build-app.sh <arm64|x86_64> <output-dir> [version]}"
VERSION="${3:-}"
APP_NAME=QuickGPT

case "$ARCH" in
  arm64|x86_64) ;;
  *) echo "error: unsupported arch '$ARCH' (use arm64 or x86_64)" >&2; exit 1 ;;
esac

cd "$(dirname "$0")/.."

PLIST_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
if [[ -n "$VERSION" && "$VERSION" != "$PLIST_VERSION" ]]; then
  echo "error: version $VERSION doesn't match Resources/Info.plist ($PLIST_VERSION); bump the plist first" >&2
  exit 1
fi

echo "==> Building $APP_NAME $PLIST_VERSION for $ARCH"
swift build -c release --arch "$ARCH"
BIN_DIR=$(swift build -c release --arch "$ARCH" --show-bin-path)

APP="$OUT/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
# SwiftPM resource bundles must sit at the app root: that's where the generated Bundle.module
# accessor looks. Without the KeyboardShortcuts one, the Shortcuts settings tab crashes.
cp -R "$BIN_DIR"/*.bundle "$APP/"

ACTUAL=$(lipo -archs "$APP/Contents/MacOS/$APP_NAME")
if [[ "$ACTUAL" != "$ARCH" ]]; then
  echo "error: built binary is '$ACTUAL', expected '$ARCH'" >&2
  exit 1
fi
echo "==> $APP ($ACTUAL)"
