# Mail Widgets

A local macOS app and native WidgetKit extension for Apple Mail. Uses SwiftUI, SF Symbols, system typography, semantic colors, and the standard widget background.

## Features

- Large widget: ten compact two-line message rows, with the subject below the sender. Extra-large: two columns of five.
- Each widget independently selects one or more account inboxes, merged newest first. Leave Inboxes empty for all inboxes.
- Each widget has an **Only unread** switch; turn it off for the newest mail including read messages.
- Medium widget: three newest messages, with tight sender/subject pairs and additional separation between messages.
- Sender, subject, scoped “x unread” count, and last successful update time. Medium and extra-large layouts also show received dates.
- Native SwiftUI/App Intents configuration through **Edit “Mail”**.
- Click a message to open it in Apple Mail.
- Optional launchd background refresh: a short-lived per-user LaunchAgent runs approximately once a minute, even with the visible app quit.
- Without background refresh, the companion app checks once a minute while running and after wake.
- Separate **Refresh in background** and **Open app at login** switches, plus menu-bar Refresh and Quit commands.
- Read-only collection: no body downloads, read-status writes, sending, or deletion.
- Visible setup/error/cached states. macOS controls the actual widget refresh schedule.

## Build

The Xcode project has an app target and an embedded WidgetKit extension:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project UnreadMail.xcodeproj -scheme UnreadMail -configuration Debug \
  -derivedDataPath build build
```

For Apple Silicon with Command Line Tools, without requiring the full Xcode build system:

```sh
./build-local.sh
```

The local script also uses the App Intents metadata processor bundled with `/Applications/Xcode.app`; it does not invoke `xcodebuild`.

Output: `build/local/Mail Widgets.app`. This is locally ad-hoc signed, not notarized or intended for distribution. No Apple Developer account is required for compilation.

## Install and use

Copy the app to `~/Applications`, launch it, click **Connect Apple Mail**, and allow the requested Automation access to Mail. Enable **Refresh in background** to keep collection running after quitting the app. If macOS requests approval, enable Mail Widgets under **System Settings → General → Login Items & Extensions**. Apple Mail must remain running. With background refresh off, keep the companion app running; closing its window keeps the menu-bar app alive.

Control-click the desktop, choose **Edit Widgets**, search **Mail Widgets**, and add **Large** for all ten messages. Control-click each widget and choose **Edit “Mail”** to select inboxes and set **Only unread**. Add more instances to keep different selections side by side.

## Data and permissions

The host uses JavaScript for Automation (`osascript`) to read Mail's inbox metadata. It needs Automation access to Mail, not Full Disk Access. Mail must be running and syncing to receive new messages. Junk and deleted messages are excluded.

For this personal ad-hoc build, the unsandboxed host publishes an atomic, user-readable-only snapshot in the sandboxed widget's own container:

`~/Library/Containers/local.alexbp.UnreadMail.Widget/Data/Library/Application Support/UnreadMail/snapshot.json`

macOS may request permission for this container access. A signed distributable version should use a provisioned team-prefixed App Group instead. The app does not send metadata to any server. The cache contains each inbox’s ten newest unread headers and ten newest headers overall, plus an aggregate top ten, inbox labels, unread totals and status. These lists can overlap. Message bodies and attachments are never collected.

A refresh failure preserves the last successful messages and timestamp and labels them cached. The widget requests another timeline after five minutes; the collector also requests a widget refresh after collection. Neither timing guarantees an immediate widget redraw.

## Background service

The app installs `~/Library/LaunchAgents/local.alexbp.UnreadMail.Refresh.plist` using the standard per-user launchd mechanism. It requires no root access and is loaded after login. Its `StartInterval` is 60 seconds; each run reads Mail, saves the cache, requests a WidgetKit timeline reload, then exits. It does not run while the Mac is asleep or the user is logged out. The OS can delay interval ticks; WidgetKit still controls visible redraw timing.

This local ad-hoc build uses a conventional LaunchAgent because bundled `SMAppService.agent` registration rejected a rebuilt executable with an AMFI launch-constraint error. Normal code signing and Automation permissions remain in effect. The app uses Service Management’s legacy-plist status API to reflect macOS background-item approval. A distributable version should use a stable signing identity and a bundled agent.

The job launches the app executable in `--refresh-agent` mode with no windows or menu bar. Using the same app bundle retains its Automation identity. The UI and agent use a nonblocking file lock to prevent simultaneous mail collection. Failed collection preserves the last successful messages and timestamp. The visible app reads the shared cache, and its periodic collector is disabled while the agent is enabled.

Inspect the installed service:

```sh
launchctl print gui/$(id -u)/local.alexbp.UnreadMail.Refresh
```

Disable or enable it with the app's **Refresh in background** switch. For terminal use:

```sh
"$HOME/Applications/Mail Widgets.app/Contents/MacOS/UnreadMail" --background-status
"$HOME/Applications/Mail Widgets.app/Contents/MacOS/UnreadMail" --disable-background
"$HOME/Applications/Mail Widgets.app/Contents/MacOS/UnreadMail" --enable-background
```

Disable the service before moving/replacing the installed app; enable it again afterwards to register its installed executable path.

## Tests

```sh
xcrun swiftc Sources/Shared/Snapshot.swift Tests/main.swift -o /tmp/unreadmail-tests
/tmp/unreadmail-tests
```

The collector also has tests for successful refresh, error preservation, Mail-closed handling, concurrent-run exclusion, lock release, and private file permissions:

```sh
DEVELOPER_DIR=/Library/Developer/CommandLineTools xcrun swiftc Sources/Shared/Snapshot.swift Sources/App/MailReader.swift Sources/App/MailRefresh.swift Tests/RefreshTests.swift -o /tmp/mail-refresh-tests
/tmp/mail-refresh-tests
```

Snapshot tests cover newest-first ordering, the ten-row limit, independent and combined inbox selections, unread/all modes, scoped counts, missing and empty inboxes, legacy cache decoding, sender/subject handling, deep-link lookup, JSON storage, and corrupt-cache recovery.

## Remove

Quit Mail Widgets and remove the widget through its context menu. Disable **Refresh in background** and **Open app at login** in the app before moving the app to Trash. Remove the widget's cache directory above if you also want to discard the saved headers.
