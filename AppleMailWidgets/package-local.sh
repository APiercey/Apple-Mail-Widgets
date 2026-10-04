#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
./build-local.sh
mkdir -p dist
/usr/bin/ditto -c -k --sequesterRsrc --keepParent 'build/local/AppleMailWidgets.app' 'dist/AppleMailWidgets.zip'
printf 'Packaged %s/dist/AppleMailWidgets.zip\n' "$PWD"
