#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
./build-local.sh
mkdir -p dist
/usr/bin/ditto -c -k --sequesterRsrc --keepParent 'build/local/Mail Widgets.app' 'dist/Mail Widgets.zip'
printf 'Packaged %s/dist/Mail Widgets.zip\n' "$PWD"
