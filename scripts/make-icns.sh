#!/bin/zsh
# Regenerates Resources/AppIcon.icns and docs/icon.png from scripts/make-icon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

swift scripts/make-icon.swift "$tmp/icon.png"
iconset="$tmp/AppIcon.iconset"
mkdir "$iconset"
for px in 16 32 128 256 512; do
    sips -z $px $px "$tmp/icon.png" --out "$iconset/icon_${px}x${px}.png" >/dev/null
    sips -z $((px * 2)) $((px * 2)) "$tmp/icon.png" --out "$iconset/icon_${px}x${px}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o Resources/AppIcon.icns
sips -z 256 256 "$tmp/icon.png" --out docs/icon.png >/dev/null
echo "Icon written to Resources/AppIcon.icns and docs/icon.png"
