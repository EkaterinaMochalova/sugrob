#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP=build/SugrobLivePreview.app
mkdir -p "$APP/Contents/MacOS"
for arch in arm64 x86_64; do
 swiftc -O -target "$arch-apple-macos13" main.swift -o "build/preview-$arch"
done
lipo -create build/preview-arm64 build/preview-x86_64 -output "$APP/Contents/MacOS/SugrobLivePreview"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>SugrobLivePreview</string><key>CFBundleIdentifier</key><string>local.sugrob.livepreview</string><key>CFBundleName</key><string>Sugrob Live Preview</string><key>CFBundleShortVersionString</key><string>0.1</string><key>CFBundlePackageType</key><string>APPL</string><key>LSMinimumSystemVersion</key><string>13.0</string></dict></plist>
PLIST
codesign --force --sign - "$APP"
