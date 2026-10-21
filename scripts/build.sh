#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SPARKLE_FRAMEWORK:?Set SPARKLE_FRAMEWORK to Sparkle.framework (2.10.0)}"
APP="$PWD/../Extension Parade.app"
mkdir -p "$APP/Contents/"{MacOS,Resources,Frameworks} .build
cp -R Sources/ExtensionParade/Resources/Icons "$APP/Contents/Resources/"
cp Sources/ExtensionParade/Resources/Sparkle-LICENSE "$APP/Contents/Resources/"
cp Sources/ExtensionParade/Resources/Icons/07-atom.icns "$APP/Contents/Resources/AppIcon.icns"
ditto "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"
for ARCH in arm64 x86_64; do
  swiftc -module-cache-path "$PWD/.build/ModuleCache" Sources/ExtensionParade/main.swift -O -target "$ARCH-apple-macos13.0" -F "$(dirname "$SPARKLE_FRAMEWORK")" -framework Sparkle -framework AppKit -framework ServiceManagement -Xlinker -rpath -Xlinker @executable_path/../Frameworks -o ".build/ExtensionParade-$ARCH"
done
lipo -create .build/ExtensionParade-arm64 .build/ExtensionParade-x86_64 -output "$APP/Contents/MacOS/ExtensionParade"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
echo "$APP"
