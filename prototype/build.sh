#!/bin/bash
# Builds MultiDock.app next to this script. Needs Xcode Command Line Tools (xcode-select --install).
set -e
cd "$(dirname "$0")"

APP=MultiDock.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

SDK="${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk}"
swiftc -O -sdk "$SDK" main.swift -o "$APP/Contents/MacOS/MultiDock" -framework AppKit

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>MultiDock</string>
  <key>CFBundleIdentifier</key><string>io.github.barjakuzu.multidock</string>
  <key>CFBundleName</key><string>MultiDock</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "Built $(pwd)/$APP"
