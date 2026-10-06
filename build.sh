#!/bin/zsh
# Builds a universal (Apple Silicon + Intel) SystemMonitor.app.
# Usage: ./build.sh            build into ./build
#        ./build.sh install    build and copy to /Applications
set -euo pipefail
cd "$(dirname "$0")"

APP=build/SystemMonitor.app
MIN_MACOS=14.0

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

for arch in arm64 x86_64; do
    swiftc -O -target "$arch-apple-macos$MIN_MACOS" Sources/*.swift -o "build/SystemMonitor-$arch"
done
lipo -create build/SystemMonitor-arm64 build/SystemMonitor-x86_64 -output "$APP/Contents/MacOS/SystemMonitor"
rm build/SystemMonitor-*

cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "Built $PWD/$APP"

if [[ "${1:-}" == "install" ]]; then
    pkill -x SystemMonitor || true
    rm -rf /Applications/SystemMonitor.app
    cp -R "$APP" /Applications/
    open /Applications/SystemMonitor.app
    echo "Installed to /Applications/SystemMonitor.app"
fi
