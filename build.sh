#!/bin/bash
# Builds "LCARS Ops.app" without Xcode/SPM — direct swiftc compile + hand-assembled bundle.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="LCARS Ops"
EXEC_NAME="LCARSOps"
BUNDLE_ID="io.github.martinbeusker.tricorder-file-manager"
SDK="$(xcrun --show-sdk-path)"
TARGET="arm64-apple-macos14.0"

BUILD="$ROOT/build"
APP="$BUILD/$APP_NAME.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"

echo "› cleaning"
rm -rf "$APP"
mkdir -p "$MACOS" "$RES/Fonts"

echo "› compiling Swift sources"
SRC=$(find "$ROOT/Sources/LCARSOps" -name '*.swift')
swiftc \
  -parse-as-library \
  -sdk "$SDK" \
  -target "$TARGET" \
  -O \
  -framework SwiftUI -framework AppKit \
  $SRC \
  -o "$MACOS/$EXEC_NAME"

echo "› bundling fonts"
cp "$ROOT/Resources/Fonts/"*.ttf "$RES/Fonts/"

echo "› building app icon"
if [ -f "$ROOT/Resources/AppIcon.png" ]; then
  ICONSET="$BUILD/AppIcon.iconset"
  rm -rf "$ICONSET"; mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z $s $s        "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_${s}x${s}.png"    >/dev/null
    sips -z $((s*2)) $((s*2)) "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$RES/AppIcon.icns"
  rm -rf "$ICONSET"
fi

echo "› writing Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>LCARS Ops File Manager</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$EXEC_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSMainNibFile</key><string></string>
  <key>ATSApplicationFontsPath</key><string>Fonts</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
</dict>
</plist>
PLIST

if [ -f "$RES/AppIcon.icns" ]; then :; fi

echo "› signing (ad-hoc)"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || echo "  (codesign skipped)"

echo "✓ built $APP"
