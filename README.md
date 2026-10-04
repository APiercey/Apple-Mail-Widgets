# AppleMailWidgets

Your latest Apple Mail messages in a native desktop widget.

## Requirements

- macOS 14 or later.
- An Apple Silicon Mac.
- Accounts set up in Apple Mail.
- Xcode in `/Applications/Xcode.app`. Tested with Xcode 27.
- Apple's Command Line Tools.

No paid Apple Developer account is needed. Build and install on your own Mac.

## Install from source

1. Install Xcode, open it, and complete its setup.
2. Install Command Line Tools in Terminal:

   ```sh
   xcode-select --install
   ```

3. Run:

   ```sh
   git clone https://github.com/APiercey/Apple-Mail-Widgets.git
   cd Apple-Mail-Widgets/AppleMailWidgets
   ./build-local.sh && ./install-local.sh
   ```

The app opens from `~/Applications/AppleMailWidgets.app`.

## Connect Mail

1. Click **Connect Apple Mail**.
2. Allow access to Mail when macOS asks.
3. Turn on **Refresh in background**.

## Add a widget

1. Control-click the desktop.
2. Choose **Edit Widgets**.
3. Find **AppleMailWidgets**.
4. Choose a size and add the **Mail** widget.

## Choose your mail

1. Control-click the widget and choose **Edit “Mail”**.
2. Select inboxes. Leave the selection empty for all inboxes.
3. Turn **Only unread** off to include read messages.

- Each widget can use different inboxes.
- Messages from selected inboxes are mixed, newest first.
- Medium shows up to 3 messages. Large and Extra Large show up to 10.
- Click a message to open it in Apple Mail.

## Refresh

- Keep Apple Mail running.
- Background refresh checks about once a minute.
- AppleMailWidgets can be quit when background refresh is on.
- macOS decides when the widget redraws.
- Use **Refresh now** in the app for a manual check.

## Privacy

- Mail metadata stays on your Mac.
- Message bodies and attachments are not collected.

## Update

From the same source folder:

```sh
git pull --ff-only
./build-local.sh && ./install-local.sh
```

## Remove

1. Turn off **Refresh in background**.
2. Remove your desktop widgets.
3. Quit AppleMailWidgets and move it to Trash.
