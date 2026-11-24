#!/bin/bash
# Собирает build/Sugrob.app. Нужны только Command Line Tools: xcode-select --install
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Sugrob.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

# Одна сборка для Apple Silicon и Intel.
for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos13" main.swift Weather.swift Atmosphere.swift LiveCamera.swift InlineCamera.swift Dashboard.swift CityLibrary.swift -o "build/Sugrob-$arch"
done
lipo -create build/Sugrob-arm64 build/Sugrob-x86_64 -output "$APP/Contents/MacOS/Sugrob"
rm build/Sugrob-arm64 build/Sugrob-x86_64

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>Sugrob</string>
	<key>CFBundleIdentifier</key><string>local.sugrob</string>
	<key>CFBundleIconFile</key><string>Sugrob</string>
	<key>CFBundleName</key><string>Sugrob</string>
	<key>CFBundleDisplayName</key><string>Сугроб</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.6.36</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
	<key>LSUIElement</key><true/>
	<key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

mkdir -p "$APP/Contents/Resources/AtmosphereAssets"
cp app-icon/Sugrob.icns "$APP/Contents/Resources/"
cp live-cameras.json "$APP/Contents/Resources/"
cp assets/*.png assets/*.mp3 "$APP/Contents/Resources/AtmosphereAssets/"


codesign --force --sign - "$APP"
echo "Готово: $APP"
