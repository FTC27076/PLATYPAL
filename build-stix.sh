#!/bin/bash
# Builds Stix.app (the stick-figure version) next to this script. Requires Xcode Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"
APP="Stix.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -parse-as-library -framework Cocoa Stix.swift -o "$APP/Contents/MacOS/Stix"
cp Stix-Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP. Launch it with: open $APP"
