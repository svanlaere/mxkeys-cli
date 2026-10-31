#!/usr/bin/env bash

set -e

APP_NAME="MX Keys Battery"

INSTALL_BINARY="$HOME/.local/bin/mxkeys"
AUTOSTART_FILE="$HOME/.config/autostart/mxkeys.desktop"
UDEV_RULE="/etc/udev/rules.d/70-mxkeys.rules"

echo "Uninstalling $APP_NAME..."
echo

# Remove the installed executable.
if [[ -f "$INSTALL_BINARY" ]]; then
    rm -f "$INSTALL_BINARY"
fi

# Remove the XDG autostart entry.
if [[ -f "$AUTOSTART_FILE" ]]; then
    rm -f "$AUTOSTART_FILE"
fi

# Remove the udev rule.
if [[ -f "$UDEV_RULE" ]]; then
    sudo rm -f "$UDEV_RULE"

    sudo udevadm control --reload-rules
    sudo udevadm trigger
fi

echo
echo "$APP_NAME has been uninstalled."