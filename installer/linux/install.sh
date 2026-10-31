#!/usr/bin/env bash

set -e

APP_NAME="MX Keys Battery"
BINARY_NAME="mxkeys"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

SOURCE_BINARY="$PROJECT_ROOT/$BINARY_NAME"

INSTALL_DIR="$HOME/.local/bin"
INSTALL_BINARY="$INSTALL_DIR/$BINARY_NAME"

AUTOSTART_DIR="$HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/mxkeys.desktop"

UDEV_RULE="/etc/udev/rules.d/70-mxkeys.rules"

echo "Installing $APP_NAME..."
echo

if [[ ! -f "$SOURCE_BINARY" ]]; then
    echo "Error: mxkeys was not found:"
    echo "$SOURCE_BINARY"
    exit 1
fi

if [[ ! -x "$SOURCE_BINARY" ]]; then
    echo "Error: mxkeys is not executable:"
    echo "$SOURCE_BINARY"
    exit 1
fi

if ! command -v notify-send >/dev/null 2>&1; then
    echo "Error: notify-send is required but was not found."
    echo "Install libnotify-bin (or your distribution's equivalent) and try again."
    exit 1
fi

# Install the executable.
mkdir -p "$INSTALL_DIR"
cp "$SOURCE_BINARY" "$INSTALL_BINARY"
chmod +x "$INSTALL_BINARY"

# Create the XDG autostart entry.
mkdir -p "$AUTOSTART_DIR"

cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=MX Keys Battery
Comment=Check MX Keys S battery level
Exec=$INSTALL_BINARY
Terminal=false
X-KDE-autostart-after=panel
EOF

# Install the udev rule.
#
# This is the only part of the installation that requires root access.
echo 'KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c548", TAG+="uaccess"' |
    sudo tee "$UDEV_RULE" >/dev/null

sudo udevadm control --reload-rules
sudo udevadm trigger

echo
echo "$APP_NAME installed successfully."
echo
echo "The battery check will run automatically when you log on."
echo

"$INSTALL_BINARY" --status