#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
fail() { printf 'Build setup: %s\n' "$1" >&2; exit 1; }
[[ "$(uname -s)" == Darwin ]] || fail 'Use a Mac to build this app.'
[[ "$(uname -m)" == arm64 ]] || fail 'Use an Apple Silicon Mac and run Terminal without Rosetta.'
[[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 14 ]] || fail 'macOS 14 or later is required.'
[[ -d "$DEVELOPER_DIR" ]] || fail 'Install Command Line Tools with: xcode-select --install. If DEVELOPER_DIR is set, check its path.'
METADATA_TOOL=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/appintentsmetadataprocessor
[[ -x "$METADATA_TOOL" ]] || fail 'Install Xcode in /Applications/Xcode.app, then open it and complete setup.'
SWIFT_COMPILER=$(xcrun --find swiftc 2>/dev/null) || fail 'Swift is unavailable. Finish installing Xcode and Command Line Tools.'
SDK=$(xcrun --show-sdk-path 2>/dev/null) || fail 'The macOS SDK is unavailable. Finish installing Xcode and Command Line Tools.'
[[ -d "$SDK" ]] || fail 'The macOS SDK path does not exist. Reinstall Command Line Tools.'
TOOLCHAIN=$(cd "$(dirname "$SWIFT_COMPILER")/../.." && pwd)
XCODE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print ProductBuildVersion' /Applications/Xcode.app/Contents/version.plist) || fail 'Cannot read the Xcode version. Finish installing Xcode.'
if [[ "${1:-}" == --check ]]; then printf 'Build tools are ready.\n'; exit 0; fi
[[ $# -eq 0 ]] || fail 'Usage: ./build-local.sh [--check]'
BUILD_VARIANT="${BUILD_VARIANT:-local}"
case "$BUILD_VARIANT" in local|release) ;; *) printf 'Invalid build variant\n' >&2; exit 1 ;; esac
WORK="$PWD/build/$BUILD_VARIANT"
APP="$WORK/AppleMailWidgets.app"
SWIFT_FLAGS=(-Onone)
if [[ "$BUILD_VARIANT" == release ]]; then SWIFT_FLAGS=(-O); fi
EXT="$APP/Contents/PlugIns/AppleMailWidgetsWidget.appex"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$EXT/Contents/MacOS" "$EXT/Contents/Resources"
xcrun swiftc "${SWIFT_FLAGS[@]}" -parse-as-library -swift-version 5 -target arm64-apple-macos14.0 -sdk "$SDK" \
    -module-name AppleMailWidgetsWidget -whole-module-optimization -emit-const-values-path "$WORK/Widget.swiftconstvalues" -Xfrontend -const-gather-protocols-file -Xfrontend "$PWD/Config/ConstProtocols.json" \
    -application-extension -Xlinker -e -Xlinker _NSExtensionMain -D WIDGET_EXTENSION Sources/Shared/Snapshot.swift Sources/Widget/MailConfiguration.swift Sources/Widget/AppleMailWidgetsWidget.swift \
    -o "$EXT/Contents/MacOS/AppleMailWidgetsWidget"
xcrun swiftc "${SWIFT_FLAGS[@]}" -parse-as-library -swift-version 5 -target arm64-apple-macos14.0 -sdk "$SDK" \
    Sources/Shared/Snapshot.swift Sources/Shared/MailLink.swift Sources/App/MailReader.swift Sources/App/MailRefresh.swift Sources/App/AgentStatus.swift Sources/App/BackgroundRefresh.swift Sources/App/AppleMailWidgetsApp.swift Sources/App/SettingsApplication.swift \
    -o "$APP/Contents/MacOS/AppleMailWidgets"
xcrun swift Config/MakeIcon.swift "$WORK/AppIcon.iconset"
xcrun iconutil -c icns "$WORK/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cp Sources/App/ReadMail.js "$APP/Contents/Resources/"

/usr/bin/python3 - "$APP" "$EXT" <<'PY'
import os,pathlib,plistlib,sys,time
build_version = os.environ.get("APP_BUILD_NUMBER", str(int(time.time())))
app_version = os.environ.get("APP_VERSION", "1.0")
for path,name,exe,bid in [(sys.argv[1],'App','AppleMailWidgets','com.applemailwidgets.AppleMailWidgets'),(sys.argv[2],'Widget','AppleMailWidgetsWidget','com.applemailwidgets.AppleMailWidgets.Widget')]:
    with open(f'Config/{name}-Info.plist','rb') as f: data=plistlib.load(f)
    if name == 'App': data['CFBundleIconFile']='AppIcon'
    data.update(CFBundleExecutable=exe,CFBundleIdentifier=bid,CFBundleName='AppleMailWidgets',CFBundleDisplayName='AppleMailWidgets',CFBundleVersion=build_version,CFBundleShortVersionString=app_version,LSMinimumSystemVersion='14.0',CFBundleSupportedPlatforms=['MacOSX'])
    with open(path+'/Contents/Info.plist','wb') as f: plistlib.dump(data,f)
PY
printf '%s\n' "$PWD/Sources/Shared/Snapshot.swift" "$PWD/Sources/Widget/MailConfiguration.swift" "$PWD/Sources/Widget/AppleMailWidgetsWidget.swift" > "$WORK/Widget.SwiftFileList"
printf '%s\n' "$WORK/Widget.swiftconstvalues" > "$WORK/Widget.ConstValuesList"
"$METADATA_TOOL" \
    --module-name AppleMailWidgetsWidget --output "$EXT/Contents/Resources" \
    --toolchain-dir "$TOOLCHAIN" --sdk-root "$SDK" \
    --xcode-version "$XCODE_VERSION" --platform-family macOS --deployment-target 14.0 \
    --target-triple arm64-apple-macos14.0 --source-file-list "$WORK/Widget.SwiftFileList" \
    --swift-const-vals-list "$WORK/Widget.ConstValuesList"
codesign --force --sign - --options runtime --entitlements Config/Widget.entitlements "$EXT"
codesign --force --sign - --options runtime --entitlements Config/App.entitlements "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built %s\n' "$APP"
