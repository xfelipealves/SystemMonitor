#!/bin/sh
# Installs the latest SystemMonitor release into /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/xfelipealves/SystemMonitor/main/install.sh | sh
#
# Files downloaded with curl are not quarantined, so macOS opens the app without the
# "unidentified developer" warning that a browser download triggers.
set -eu

URL="https://github.com/xfelipealves/SystemMonitor/releases/latest/download/SystemMonitor.zip"
APP="/Applications/SystemMonitor.app"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "Downloading SystemMonitor..."
curl -fsSL "$URL" -o "$tmp/SystemMonitor.zip"
ditto -x -k "$tmp/SystemMonitor.zip" "$tmp"

pkill -x SystemMonitor 2>/dev/null && sleep 1 || true
rm -rf "$APP"
mv "$tmp/SystemMonitor.app" "$APP"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

open "$APP"
echo "SystemMonitor installed in $APP and running in the menu bar."
