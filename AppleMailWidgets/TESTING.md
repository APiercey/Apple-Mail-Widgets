# Verification — 4 October 2026

Tested locally on macOS 26.7.1, Apple Silicon.

## Last X days (5 October 2026)

- Added an optional native integer field to each widget. Minimum 1, no product maximum. Blank preserves existing behavior. Days use local calendar boundaries, with 1 meaning today.
- Filtering uses cached headers after inbox selection. Mail collection and total unread counts are unchanged. The timeline includes an entry for the next local midnight.
- Configuration tests passed for local midnight, two-day windows, both DST transitions, inbox isolation, unread/all modes, unset values, invalid values, and Int.max. Existing snapshot tests passed.
- Built, signature-verified, and installed. Extracted App Intents metadata declares an optional number field with minimum 1. Native intent decoding preserved unset, 1, 2, and 1,000,000. WidgetKit logs confirmed successful reloads after installation.
- The UI automation could not target the Mail widget editor, so direct typing into the field remains unverified.

## Inbox selection and loading repair

- Native logs showed AppEntity identifiers failing to resolve in the local ad-hoc build. Replaced entity selections with stable string IDs and named options. Missing selections now ask for setup instead of showing every account.
- Measured the larger inbox read at 22.22 seconds, exceeding the 20-second timeout. The unread count took about 8 milliseconds. Bulk metadata reads reduced that inbox read to 2.12 seconds and matched the independently checked newest ten message IDs.
- Added fixture tests for string selections, account isolation, unread/all modes, missing selections, account renames/removal, legacy caches, newest-message ordering, deleted/junk exclusions, and concurrent mailbox changes. New tests and existing snapshot tests passed.
- Fixed quiet installation to launch the app through Launch Services. Registration alone left the replaced app launch-disabled and prevented App Intents from loading. Verified the corrected installer and installed signatures.
- Backed up local desktop widget settings and recovered the existing selections while preserving positions and sizes. This local recovery is not part of the installer. Other existing installations may need to select inboxes again.
- Verified fresh WidgetKit render archives: Large contained ten messages from its selected account and none from the other account. Medium and Extra Large used All Inboxes. Native logs confirmed successful string-parameter decoding and rendering for all three sizes.
- Picker clicks were not automated. Native configuration decoding and actual rendered widget contents were verified directly. WidgetKit still controls redraw timing.

## AppleMailWidgets project rename

- Final identity change: host `com.applemailwidgets.AppleMailWidgets`, extension `.Widget`, agent `.Refresh`, widget kind `AppleMailWidgetsWidget`, URL scheme `applemailwidgets`, and cache directory `Application Support/AppleMailWidgets`.
- Clean rebuild, signature verification, snapshot/filtering tests, collector tests, and routing tests passed. Scanned project text and ZIP entries for former product names and personal identifier prefixes: no matches.
- Disabled the previous background service, replaced the installed bundle, and enabled the new service. Confirmed the extension is registered under its new identifier. Existing desktop widgets must be recreated and Mail access granted for the new identity.
- Live collection under the new identity is pending the user's connection/permission step. UI automation could inventory the running new identity but could not bind to it after the identity change; no fresh setup screenshot was verified in this pass.

- Renamed the project directory, Xcode project and targets, Swift entry-point files, app/extension executables, display names, and ZIP to AppleMailWidgets naming. Widget display title remains Mail.
- All current bundle/service identifiers, widget kind, cache paths, and URL registration use AppleMailWidgets. There is no product-identity compatibility layer; the previous development identity is intentionally replaced.
- Built and signature-verified the renamed app and extension, inspected the ZIP's names and absence of mail cache, and installed at AppleMailWidgets.app.
- Verified the settings window and menu display AppleMailWidgets, background refresh stays enabled, and the LaunchAgent points to the renamed executable. The earlier app bundle is no longer installed.

## Multiple accounts during initial sync

- Diagnosed a stale one-account snapshot with a reader timeout. Apple Mail exposed both Work and Personal; a full filtered unread count alone took about 30 seconds on Personal.
- Separated enabled-account discovery from per-inbox reads, bounded reads to 20 seconds per inbox, used Mail's reported unread count, and restricted initial header queries to recent dates with progressively wider fallback ranges.
- Added passing collector tests for new pending inboxes remaining selectable, healthy-account updates during partial failures, preserving failed-account headers and timestamps, account renames, scoped error states, cache roundtrips, recovery, and account removal. Existing snapshot/filtering tests also passed.
- During testing, Mail temporarily stopped answering even account-list requests. The installed collector subsequently recovered and saved both live accounts with ready status, ten unread and ten recent headers each. Verified descending order, unread flags, account IDs, and per-inbox timestamps without printing message contents.
- Rebuilt and signature-verified the installed app and ZIP; restored enabled background refresh. The picker reads this two-account cache, but reopening the native picker was not automated in this test.

## Passed

- Built the companion app and sandboxed WidgetKit extension with the installed Swift command-line toolchain.
- Verified the installed app and embedded extension with `codesign --verify --deep --strict`.
- Registered the extension with PlugInKit and verified it appears as **AppleMailWidgets** in the native macOS widget gallery.
- Connected the installed app to the user's live Apple Mail inbox: 415 unread messages, exactly ten displayed, descending received dates.
- Inspected the companion app's live list through macOS accessibility.
- Added the **Large** widget to the desktop and visually inspected the actual WidgetKit-rendered result. All ten rows, the header, total count, and update timestamp fit inside the rounded system background.
- Corrected clipping found during visual QA using size-dependent row heights.
- Observed successive successful collection timestamps, and exercised the app's Refresh button. Total unread count remained 415 throughout collection tests.
- Verified the cached JSON file is mode 0600 and contains metadata only, including up to ten unread and ten recent headers per inbox.
- Automated tests passed for sorting, top-ten selection, total count, empty subject, sender formatting, URL generation, JSON roundtrip, and malformed-cache recovery.

## Configuration and layout update

- Built and installed the renamed **AppleMailWidgets** app, with the new product name.
- Verified the live native widget shows **Mail**, **415 unread**, inbox scope, and the updated system-styled layout. Inspected both the large single-line layout and the extra-large two-column layout. Adjusted footer allocation to retain system content margins.
- Live reader discovered one configured account inbox and returned both its ten newest unread messages and ten newest messages overall; the latter included two read messages.
- Extended fixture tests passed for independent widget selections, multiple merged inboxes, global newest-first top ten, unread/all switching, scoped unread counts, missing/empty inboxes, v1 cache compatibility, and opening cached read messages.
- Extracted native App Intents metadata into the installed extension; it describes the inbox entity picker and default-enabled Only unread parameter.
- Native Edit Widget interactions could not be completed through the UI automation: Notification Center repeatedly selected a different widget window and coordinate actions returned windowNotFoundAtPosition. Picker/toggle interaction remains unverified end to end.
- Only one live account is configured on this Mac. Multiple-account combinations were verified using fixtures.

## Build findings

Xcode 27 is installed, but `xcodebuild` is blocked by its unaccepted license. No license was accepted on the user's behalf. The separate Command Line Tools successfully built and signed the app.

A command-line WidgetKit build must link with `-e _NSExtensionMain`. Without this, it registers but exits immediately when the gallery queries it. The local build script includes the corrected entry point.

The local build assigns a fresh bundle build number, so macOS can distinguish updates. The installed build resides at `~/Applications/AppleMailWidgets.app`.

## Limits of this verification

- WidgetKit refresh latency is system-controlled; no fixed redraw interval is promised.
- Message links were checked for safe construction, but live message opening was not exercised, to avoid marking a user's unread message as read.
- Launch at Login remains off and was not enabled during testing.
- Permission-denied and Mail-closed UI branches exist, but access was not revoked and the user's Mail app was not quit to trigger them.
- The Xcode project has not been built through `xcodebuild` because of the license blocker. The installed command-line build was tested end to end.
- This is a local ad-hoc build. Distribution/notarization and provisioned App Group transport are outside this build.

## Follow-up layout adjustment

- Large now puts subjects beneath senders while retaining all ten messages.
- Medium uses a zero-point sender/subject stack gap and smaller gaps around the list to give each of its three rows more space.
- Row height is calculated from the actual space remaining between the header and footer, preventing the old fixed estimate from squeezing Medium rows.
- Built and signed successfully; inspected SwiftUI renders at Medium (344 × 164) and Large (344 × 344) dimensions with representative fixture messages. All rows, the count, and footer fit. Installed the updated build.

## Background collector

- Added a per-user launchd job with RunAtLoad and a 60-second StartInterval. Each run exits after collection and a WidgetCenter refresh request.
- Verified live collection with the visible app quit and no new Automation permission grant.
- Verified the app can open during a background run; the headless entry point avoids initializing NSApplication.
- Verified the native Refresh in background checkbox unloads the job and removes its plist, then restores it when enabled. Open app at login remains off.
- Collector tests passed for success, preserving the last good cache on failure or Mail closed, cross-process lock contention, lock release, and 0600 cache permissions.
- Bundled SMAppService registration initially worked but rejected a subsequent local ad-hoc build with an AMFI launch-constraint violation. Removed that registration and used the documented conventional user LaunchAgent installation. No system security settings or other apps' background registrations were changed.
- Logout/login and sleep/wake were not forced during testing. LaunchAgent interval timing and WidgetKit rendering remain OS-scheduled.

- Final installed LaunchAgent completed two successive automatic runs with exit code 0 while the visible app was quit. Cache timestamps advanced from 19:52:52 to 19:53:57; no collector process remained between runs.

## Settings, packaging, and stale-widget repair

- Diagnosed the actual widget failure in chronod logs: the old extension process survived repeated installations, and new timelines were rejected with “Bundle version did not match; LaunchServices DB may need to be rebuilt”. Mail collection itself continued successfully.
- Added `install-local.sh` to stop the old collector/widget, replace the app atomically, register the new bundle/extension, and restore requested background refresh. Verified chronod reports Reload success for Medium, Large, and Extra Large after installation.
- Fixed misleading legacy service status: inspect the actual launchd job and configured executable path. Added tests for active, unloaded, relocated, approval-required, and off states.
- Removed MenuBarExtra and the app's message list. Visually checked the compact settings window, including wrapped instructions and the enabled background control.
- Added `package-local.sh`. Verified the ZIP contains the app executable/collector, Mail script, and widget extension; excludes snapshot/lock files; and passes deep strict signature verification after extraction.
- Current ZIP is a local Apple Silicon build, not a notarized distribution build. Installation on a separate clean Mac has not been tested.

- With the final settings app quit, the second scheduled agent run updated the cache at 20:05:05 and exited 0. chronod then reported Reload success for all three configured widget sizes at 20:05:05.821–20:05:05.961. No app UI process was running.

## Widget click routing

- Replaced automatic SwiftUI WindowGroup startup with an AppKit launch delegate that handles widget URL events before creating settings UI.
- Message links now contain the RFC Message-ID as well as the legacy numeric ID; routing tests passed for cache-independent links, reserved characters, legacy cached links, missing messages, background/inbox clicks, explicit setup links, and malformed IDs.
- Snapshot/filtering regression tests passed. Built, installed, and refreshed the ZIP with the same code.
- Invoked a real installed widget message URL for an already-read cached message with the visible app quit. LaunchServices accepted the URL and the routing process exited; no settings app process remained. Background collection remained registered.
- Final visual confirmation of the selected message in Apple Mail was blocked because the Mac was locked. This does not constitute a verified native widget-click UI test.
