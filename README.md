# AppleMailWidgets

Apple Email in a widget.

It can:
- Show unreads or the latest recevived.
- Multiple and different inboxes per widget
- Auto refresh in the background.

## Preview

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/large-dark.png">
  <img src="docs/screenshots/large-light.png" alt="Large Mail widget showing ten fictional messages" width="344">
</picture>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/medium-dark.png">
  <img src="docs/screenshots/medium-light.png" alt="Medium Mail widget showing three fictional messages" width="344">
</picture>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/extra-large-dark.png">
  <img src="docs/screenshots/extra-large-light.png" alt="Extra Large Mail widget showing ten fictional messages in two columns" width="720">
</picture>

## Requirements
Only installing from the source is possible, at the moment. Xcode and required dependencies.

## Install from source

   ```sh
   git clone https://github.com/APiercey/Apple-Mail-Widgets.git
   cd Apple-Mail-Widgets/AppleMailWidgets
   ./build-local.sh && ./install-local.sh
   ```

The app opens from `~/Applications/AppleMailWidgets.app`.

## How to use
First, open the application. You will need to click "Connect Apple Mail" to get permission to look at the inbox.

Afterwards, you are able to add a widget directly on the desktop.

If you right click on the widget, you can see further options to customize.

- Select one or more inboxes, or choose **All Inboxes**.
- After updating, choose inboxes again if the widget asks you to.
- Set **Last X days**: **1** for today, **2** for today and yesterday. Leave blank for any date.
- Days start at local midnight. Minimum 1, with no set maximum.
- The unread count is the total for your selected inboxes, across all dates.
