#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source_app="$PWD/build/local/AppleMailWidgets.app"
installed_app="$HOME/Applications/AppleMailWidgets.app"
agent_plist="$HOME/Library/LaunchAgents/com.applemailwidgets.AppleMailWidgets.Refresh.plist"
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
codesign --verify --deep --strict "$source_app"
restart_background=0
if [[ -f "$agent_plist" ]]; then
    restart_background=1
    "$source_app/Contents/MacOS/AppleMailWidgets" --disable-background
fi
pkill -x AppleMailWidgets || true
pkill -x AppleMailWidgetsWidget || true
for previous_app in "$installed_app"; do
    if [[ -d "$previous_app" ]]; then
        for extension in "$previous_app/Contents/PlugIns/"*.appex; do
            [[ -d "$extension" ]] && pluginkit -r "$extension" || true
        done
        "$lsregister" -u "$previous_app" || true
    fi
done
mkdir -p "$HOME/Applications"
staging=$(mktemp -d "$HOME/Applications/.applemailwidgets-install.XXXXXX")
trap 'rm -rf "$staging"' EXIT
ditto "$source_app" "$staging/AppleMailWidgets.app"
if [[ -d "$installed_app" ]]; then mv "$installed_app" "$staging/previous.app"; fi
mv "$staging/AppleMailWidgets.app" "$installed_app"
"$lsregister" -f "$installed_app"
pluginkit -a "$installed_app/Contents/PlugIns/AppleMailWidgetsWidget.appex"
codesign --verify --deep --strict "$installed_app"
if [[ "$restart_background" == 1 ]]; then
    "$installed_app/Contents/MacOS/AppleMailWidgets" --enable-background
fi
if [[ "${1:-}" != "--no-open" ]]; then open "$installed_app"; fi
printf 'Installed %s\n' "$installed_app"
