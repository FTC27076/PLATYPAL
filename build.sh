#!/bin/bash
# Builds Platypal.app next to this script. Requires Xcode Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"
APP="Platypal.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -parse-as-library -framework Cocoa Platypal.swift -o "$APP/Contents/MacOS/Platypal"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP. Launch it with: open $APP"
