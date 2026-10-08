#!/bin/bash
# Compila y arma "Monti Mac2Win.app" (no necesita Xcode, solo las Command Line Tools).
# Uso: ./build.sh [versión]   (por defecto 1.0.0)
set -euo pipefail
cd "$(dirname "$0")"
VERSION="${1:-1.0.0}"

swift build -c release

APP="Monti Mac2Win.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/LanDrop "$APP/Contents/MacOS/"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Monti Mac2Win</string>
  <key>CFBundleDisplayName</key><string>Monti Mac2Win</string>
  <key>CFBundleIdentifier</key><string>local.landrop</string>
  <key>CFBundleExecutable</key><string>LanDrop</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "Listo: $(pwd)/$APP"
