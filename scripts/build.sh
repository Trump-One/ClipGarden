#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
APP="$PWD/build/剪贴花园.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$PWD/.build-cache"
cp Resources/Info.plist "$APP/Contents/Info.plist"
SDK_PATH="$(xcrun --sdk macosx26.5 --show-sdk-path 2>/dev/null || xcrun --sdk macosx --show-sdk-path)"
xcrun swiftc -sdk "$SDK_PATH" -swift-version 5 -parse-as-library -O -target arm64-apple-macosx14.0 \
  -module-cache-path "$PWD/.build-cache" -module-name ClipGarden \
  Sources/*.swift -framework AppKit -framework SwiftUI -framework Carbon -lsqlite3 \
  -o "$APP/Contents/MacOS/ClipGarden"
if [[ -f Resources/AppIcon.icns ]]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built: %s\n' "$APP"
