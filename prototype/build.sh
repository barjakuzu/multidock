#!/bin/bash
# Builds MultiDock.app next to this script. Needs Xcode Command Line Tools (xcode-select --install).
set -e
cd "$(dirname "$0")"

# .noindex keeps the build copy out of Spotlight, so only the installed app shows up
mkdir -p build.noindex
APP=build.noindex/MultiDock.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp AppIcon.icns "$APP/Contents/Resources/"

SDK="${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk}"
swiftc -O -sdk "$SDK" main.swift -o "$APP/Contents/MacOS/MultiDock" -framework AppKit

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>MultiDock</string>
  <key>CFBundleIdentifier</key><string>io.github.barjakuzu.multidock</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleName</key><string>MultiDock</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

# A stable certificate (scripts/make-signing-cert.sh) keeps macOS permissions across rebuilds; ad-hoc doesn't
SIGN_ID="${SIGN_ID:-MultiDock Local Signing}"
if security find-identity -v -p codesigning | grep -q "\"$SIGN_ID\""; then
  codesign --force --sign "$SIGN_ID" "$APP"
else
  echo "No \"$SIGN_ID\" certificate, signing ad-hoc (run scripts/make-signing-cert.sh to keep permissions across rebuilds)"
  codesign --force --sign - "$APP"
fi
echo "Built $(pwd)/$APP"
