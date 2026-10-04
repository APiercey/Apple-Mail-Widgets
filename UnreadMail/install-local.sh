#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source_app="$PWD/build/local/Mail Widgets.app"
installed_app="$HOME/Applications/Mail Widgets.app"
agent_plist="$HOME/Library/LaunchAgents/local.alexbp.UnreadMail.Refresh.plist"
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
codesign --verify --deep --strict "$source_app"
restart_background=0
if [[ -f "$agent_plist" ]]; then
    restart_background=1
    "$installed_app/Contents/MacOS/UnreadMail" --disable-background
fi
pkill -x UnreadMail || true
pkill -x UnreadMailWidget || true
if [[ -d "$installed_app" ]]; then
    pluginkit -r "$installed_app/Contents/PlugIns/UnreadMailWidget.appex" || true
fi
mkdir -p "$HOME/Applications"
staging=$(mktemp -d "$HOME/Applications/.mailwidgets-install.XXXXXX")
trap 'rm -rf "$staging"' EXIT
ditto "$source_app" "$staging/Mail Widgets.app"
if [[ -d "$installed_app" ]]; then mv "$installed_app" "$staging/previous.app"; fi
mv "$staging/Mail Widgets.app" "$installed_app"
"$lsregister" -f "$installed_app"
pluginkit -a "$installed_app/Contents/PlugIns/UnreadMailWidget.appex"
codesign --verify --deep --strict "$installed_app"
if [[ "$restart_background" == 1 ]]; then
    "$installed_app/Contents/MacOS/UnreadMail" --enable-background
fi
if [[ "${1:-}" != "--no-open" ]]; then open "$installed_app"; fi
printf 'Installed %s\n' "$installed_app"
