# AppleMailWidgets

Your latest Apple Mail messages in a native desktop widget.

## Requirements

- macOS 14 or later.
- An Apple Silicon Mac.
- Accounts set up in Apple Mail.

Current build: not yet notarized. Public releases will be on GitHub Releases.

## Set up

1. Unzip `AppleMailWidgets.zip`.
2. Move `AppleMailWidgets.app` to Applications.
3. Open the app and click **Connect Apple Mail**.
4. Allow access to Mail when macOS asks.
5. Turn on **Refresh in background**.

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

## Remove

1. Turn off **Refresh in background**.
2. Remove your desktop widgets.
3. Quit AppleMailWidgets and move it to Trash.
