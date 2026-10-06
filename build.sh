#!/bin/zsh
# Builds a universal (Apple Silicon + Intel) SystemMonitor.app into ./build.
#
#   ./build.sh            build the app
#   ./build.sh zip        build and package build/SystemMonitor.zip for a release
#   ./build.sh install    build, copy to /Applications and open
set -euo pipefail
cd "$(dirname "$0")"

APP=build/SystemMonitor.app
MIN_MACOS=14.0

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

binaries=()
for arch in arm64 x86_64; do
    swift build --configuration release --triple "$arch-apple-macosx$MIN_MACOS"
    binaries+=(".build/$arch-apple-macosx/release/SystemMonitor")
done
lipo -create "${binaries[@]}" -output "$APP/Contents/MacOS/SystemMonitor"

cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"  # ad-hoc signature; Apple Silicon refuses unsigned binaries
echo "Built $PWD/$APP"

case "${1:-}" in
    zip)
        ditto -c -k --keepParent "$APP" build/SystemMonitor.zip
        echo "Packaged $PWD/build/SystemMonitor.zip"
        ;;
    install)
        pkill -x SystemMonitor || true
        sleep 1
        rm -rf /Applications/SystemMonitor.app
        cp -R "$APP" /Applications/
        open /Applications/SystemMonitor.app
        echo "Installed /Applications/SystemMonitor.app"
        ;;
esac
