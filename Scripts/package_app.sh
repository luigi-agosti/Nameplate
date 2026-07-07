#!/usr/bin/env bash
set -euo pipefail
CONF=${1:-debug}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

source "$ROOT/version.env"

# SwiftUI macros need the full Xcode toolchain; plain CommandLineTools fails.
if [[ "$(xcode-select -p)" == *CommandLineTools* && -d /Applications/Xcode.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app
fi

swift build -c "$CONF"
BIN_PATH=$(swift build -c "$CONF" --show-bin-path)

APP="$ROOT/Nameplate.app"
APP_ENTITLEMENTS="$ROOT/Nameplate.entitlements"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

BUNDLE_ID="com.steipete.nameplate"
LOWER_CONF=$(printf "%s" "$CONF" | tr '[:upper:]' '[:lower:]')
if [[ "$LOWER_CONF" == "debug" ]]; then
  BUNDLE_ID="com.steipete.nameplate.debug"
fi
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Nameplate</string>
    <key>CFBundleDisplayName</key><string>Nameplate</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>Nameplate</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleIconFile</key><string>Icon</string>
    <key>NSHumanReadableCopyright</key><string>© 2026 Peter Steinberger. MIT License.</string>
    <key>NameplateGitCommit</key><string>${GIT_COMMIT}</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key><string>${BUNDLE_ID}</string>
            <key>CFBundleURLSchemes</key>
            <array><string>nameplate</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

cp "$BIN_PATH/Nameplate" "$APP/Contents/MacOS/Nameplate"
chmod +x "$APP/Contents/MacOS/Nameplate"

if [[ -f "$ROOT/Icon.icns" ]]; then
  cp "$ROOT/Icon.icns" "$APP/Contents/Resources/Icon.icns"
fi

chmod -R u+w "$APP"
xattr -cr "$APP"
find "$APP" -name '._*' -delete

CODESIGN_ID="${APP_IDENTITY:-Developer ID Application: Peter Steinberger (Y5PE65HELJ)}"
SIGN_FLAGS=(--force --options runtime)
if [[ "$CODESIGN_ID" != "-" ]]; then
  SIGN_FLAGS+=(--timestamp)
fi
codesign "${SIGN_FLAGS[@]}" --entitlements "$APP_ENTITLEMENTS" --sign "$CODESIGN_ID" "$APP"

echo "Created $APP"
