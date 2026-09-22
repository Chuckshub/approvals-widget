#!/bin/zsh
# Builds the SwiftUI menu bar app and packages it into a proper .app bundle
# (there's no Xcode project - this is a Swift Package Manager executable
# hand-assembled into a bundle so LSUIElement/Info.plist actually apply).
set -euo pipefail
HERE="${0:A:h}"
APP_NAME="ApprovalsWidget"
PKG_DIR="$HERE/MenuBarApp"
APP_DIR="$HERE/$APP_NAME.app"
BIN_NAME="ApprovalsWidget"
ICON_SRC="$HERE/AppIcon.icns"

echo "Building release binary..."
(cd "$PKG_DIR" && swift build -c release)

BIN_PATH="$PKG_DIR/.build/release/$BIN_NAME"
[[ -x "$BIN_PATH" ]] || { echo "ERROR: built binary not found at $BIN_PATH"; exit 1 }

echo "Assembling app bundle at $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
[[ -f "$ICON_SRC" ]] && cp "$ICON_SRC" "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>Approvals</string>
    <key>CFBundleIdentifier</key>
    <string>com.charlie.approvals-widget</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "Ad-hoc signing..."
codesign --force --deep -s - "$APP_DIR"

echo "Done: $APP_DIR"
