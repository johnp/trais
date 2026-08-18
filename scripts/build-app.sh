#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_NAME=trais
BUNDLE_ID=de.vda0.trais
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/.build/trais.iconset"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/trais" "$MACOS_DIR/trais"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
swift "$ROOT_DIR/scripts/generate-icon.swift" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/trais.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>trais</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleIconFile</key>
    <string>trais.icns</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>trais</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

plutil -lint "$CONTENTS_DIR/Info.plist"

SIGNING_IDENTITY=${TRAIS_CODESIGN_IDENTITY:-}
AVAILABLE_IDENTITIES=$(security find-identity -v -p codesigning 2>/dev/null || true)

if [ -z "$SIGNING_IDENTITY" ]; then
    SIGNING_IDENTITY=$(printf '%s\n' "$AVAILABLE_IDENTITIES" | awk -F '"' '/"Apple Development:/{print $2; exit}')
fi
if [ -z "$SIGNING_IDENTITY" ]; then
    SIGNING_IDENTITY=$(printf '%s\n' "$AVAILABLE_IDENTITIES" | awk -F '"' '/"Developer ID Application:/{print $2; exit}')
fi
if [ -z "$SIGNING_IDENTITY" ]; then
    SIGNING_IDENTITY=$(printf '%s\n' "$AVAILABLE_IDENTITIES" | awk -F '"' '/^[[:space:]]*[0-9]+\)/{print $2; exit}')
fi

if [ -n "$SIGNING_IDENTITY" ]; then
    echo "Signing with $SIGNING_IDENTITY"
else
    SIGNING_IDENTITY=-
    echo "No valid signing identity found; using ad-hoc signing"
fi

codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_DIR"
codesign --verify --strict "$APP_DIR"

echo "Built $APP_DIR"
