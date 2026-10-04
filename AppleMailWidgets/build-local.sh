#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
APP="$PWD/build/local/AppleMailWidgets.app"
EXT="$APP/Contents/PlugIns/AppleMailWidgetsWidget.appex"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$EXT/Contents/MacOS" "$EXT/Contents/Resources"
SDK=$(xcrun --show-sdk-path)
xcrun swiftc -parse-as-library -swift-version 5 -target arm64-apple-macos14.0 -sdk "$SDK" \
    -module-name AppleMailWidgetsWidget -whole-module-optimization -emit-const-values-path "$PWD/build/Widget.swiftconstvalues" -Xfrontend -const-gather-protocols-file -Xfrontend "$PWD/Config/ConstProtocols.json" \
    -application-extension -Xlinker -e -Xlinker _NSExtensionMain -D WIDGET_EXTENSION Sources/Shared/Snapshot.swift Sources/Widget/MailConfiguration.swift Sources/Widget/AppleMailWidgetsWidget.swift \
    -o "$EXT/Contents/MacOS/AppleMailWidgetsWidget"
xcrun swiftc -parse-as-library -swift-version 5 -target arm64-apple-macos14.0 -sdk "$SDK" \
    Sources/Shared/Snapshot.swift Sources/Shared/MailLink.swift Sources/App/MailReader.swift Sources/App/MailRefresh.swift Sources/App/AgentStatus.swift Sources/App/BackgroundRefresh.swift Sources/App/AppleMailWidgetsApp.swift Sources/App/SettingsApplication.swift \
    -o "$APP/Contents/MacOS/AppleMailWidgets"
xcrun swift Config/MakeIcon.swift "$PWD/build/AppIcon.iconset"
xcrun iconutil -c icns "$PWD/build/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cp Sources/App/ReadMail.js "$APP/Contents/Resources/"

/usr/bin/python3 - "$APP" "$EXT" <<'PY'
import pathlib,plistlib,sys,time
build_version = str(int(time.time()))
for path,name,exe,bid in [(sys.argv[1],'App','AppleMailWidgets','com.applemailwidgets.AppleMailWidgets'),(sys.argv[2],'Widget','AppleMailWidgetsWidget','com.applemailwidgets.AppleMailWidgets.Widget')]:
    with open(f'Config/{name}-Info.plist','rb') as f: data=plistlib.load(f)
    if name == 'App': data['CFBundleIconFile']='AppIcon'
    data.update(CFBundleExecutable=exe,CFBundleIdentifier=bid,CFBundleName='AppleMailWidgets',CFBundleDisplayName='AppleMailWidgets',CFBundleVersion=build_version,LSMinimumSystemVersion='14.0',CFBundleSupportedPlatforms=['MacOSX'])
    with open(path+'/Contents/Info.plist','wb') as f: plistlib.dump(data,f)
PY
printf '%s\n' "$PWD/Sources/Shared/Snapshot.swift" "$PWD/Sources/Widget/MailConfiguration.swift" "$PWD/Sources/Widget/AppleMailWidgetsWidget.swift" > build/Widget.SwiftFileList
printf '%s\n' "$PWD/build/Widget.swiftconstvalues" > build/Widget.ConstValuesList
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/appintentsmetadataprocessor \
    --module-name AppleMailWidgetsWidget --output "$EXT/Contents/Resources" \
    --toolchain-dir /Library/Developer/CommandLineTools --sdk-root "$SDK" \
    --xcode-version 27A266a --platform-family macOS --deployment-target 14.0 \
    --target-triple arm64-apple-macos14.0 --source-file-list "$PWD/build/Widget.SwiftFileList" \
    --swift-const-vals-list "$PWD/build/Widget.ConstValuesList"
codesign --force --sign - --entitlements Config/Widget.entitlements "$EXT"
codesign --force --sign - --options runtime --entitlements Config/App.entitlements "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built %s\n' "$APP"
