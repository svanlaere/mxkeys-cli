# MX Keys CLI

A small Free Pascal/Lazarus utility for checking the battery level of a **Logitech MX Keys S connected through a Logi Bolt receiver**.

The program runs once, checks the keyboard battery and exits. By default it only shows a notification when the battery is at or below 10% and the keyboard is discharging.

No Logitech software, HIDAPI, Solaar, daemon or continuously running background process is required.

HID++ protocol handling is separated from the operating-system-specific transport units.

## Usage

### Check battery status

```text
mxkeys --status
```

Example:

```text
Device: MX Keys S
Battery: 40%
State: discharging
Slot: 1
Transport: /dev/hidraw2
```

On Windows the transport description will look similar to:

```text
Transport: Windows HID (Usage Page $FF00, Usage $0002, input 20, output 20)
```

### Normal use

```text
mxkeys
```

The default warning threshold is **10%**.

When the battery is above the threshold, the program produces no output or notification and simply exits.

When the battery is at or below the threshold and the keyboard is discharging, a desktop notification is shown.

### Override the threshold

```text
mxkeys --threshold 15
```

This changes the threshold for that run only.

For example, to test the normal low-battery notification path while the keyboard is at 40%:

```text
mxkeys --threshold 50
```

### Test the notification

```text
mxkeys --test-notification
```

This shows a notification regardless of the current battery percentage.

### HID diagnostics

```text
mxkeys --list-hid
```

Lists relevant HID interfaces for diagnostic purposes.

## Linux / Kubuntu

The Linux backend discovers the Logi Bolt C548 receiver dynamically and selects the vendor HID collection advertising HID++ report IDs `0x10` and `0x11`.

It does **not** hard-code `/dev/hidrawN`.

### hidraw permissions

Access to the HID++ hidraw device may require a udev rule.

Create:

```text
/etc/udev/rules.d/70-mxkeys.rules
```

with:

```text
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c548", TAG+="uaccess"
```

Reload the rules:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

The program should then be able to access the Bolt HID++ interface as the logged-in desktop user without `sudo`.

### Install for the current user

A simple location for the executable is:

```bash
mkdir -p ~/.local/bin
cp mxkeys ~/.local/bin/mxkeys
chmod +x ~/.local/bin/mxkeys
```

Test it:

```bash
~/.local/bin/mxkeys --status
```

### Start automatically with KDE Plasma

Create:

```text
~/.config/autostart/mxkeys.desktop
```

with:

```ini
[Desktop Entry]
Type=Application
Name=MX Keys Battery
Comment=Check MX Keys S battery level
Exec=/home/YOUR_USERNAME/.local/bin/mxkeys
Terminal=false
X-KDE-autostart-after=panel
```

Replace `YOUR_USERNAME` with your Linux username.

At login the utility checks the battery once and exits. It does not remain running in the background.

Linux notifications use the standard desktop notification system through `notify-send`.

## Windows 11

The Windows backend uses the native Windows HID and SetupAPI interfaces.

It dynamically enumerates the Logi Bolt receiver and selects the HID++ collection using:

```text
Usage Page: 0xFF00
Usage:      0x0002
Input:      20 bytes
Output:     20 bytes
```

HID communication uses bounded overlapped I/O so a missing HID response cannot leave the program waiting indefinitely.

No Logitech software or additional HID library is required.

### Install for the current user

For example, place the executable in:

```text
%LOCALAPPDATA%\MXKeysBattery\mxkeys.exe
```

From PowerShell:

```powershell
New-Item -ItemType Directory -Force "$env:LOCALAPPDATA\MXKeysBattery" | Out-Null
Copy-Item ".\mxkeys.exe" "$env:LOCALAPPDATA\MXKeysBattery\mxkeys.exe"
```

Test it:

```powershell
& "$env:LOCALAPPDATA\MXKeysBattery\mxkeys.exe" --status
```

### Start automatically without a console window

Open the Windows Startup folder:

```text
Win+R
shell:startup
```

Create a shortcut with this target:

```text
powershell.exe -NoProfile -WindowStyle Hidden -Command "Start-Process -WindowStyle Hidden -FilePath \"$env:LOCALAPPDATA\MXKeysBattery\mxkeys.exe\""
```

The **Start in** directory can be:

```text
C:\Users\YOUR_USERNAME\AppData\Local\MXKeysBattery
```

The shortcut uses PowerShell only to start the console application invisibly. `mxkeys.exe` itself still remains a normal CLI program, so commands such as `--status` continue to work normally from PowerShell or Command Prompt.

Windows notifications are also displayed using the Windows PowerShell/.NET notification facilities available on a normal Windows 11 installation.

## Protocol

`mxkeys_hidpp.pas` contains the shared Logitech HID++ 2.0 implementation.

It:

1. probes receiver slots 1 through 6;
2. resolves the Device Name feature (`0x0005`);
3. verifies that the device is `MX Keys S`;
4. resolves Unified Battery (`0x1004`) through ROOT at runtime;
5. reads the battery percentage and charging state.

Identifying the device by name prevents another paired Logitech device with battery support from being mistaken for the keyboard.

## Source layout

```text
mxkeys.lpr
mxkeys_hidpp.pas
mxkeys_transport.pas
mxkeys_linux.pas
mxkeys_windows.pas
mxkeys_config.pas
mxkeys_notify.pas
mxkeys_notify_linux.pas
mxkeys_notify_windows.pas
```

The shared HID++ code does not contain Linux or Windows transport details. `mxkeys_transport.pas` selects the appropriate backend at compile time.

## Lazarus project

Open `mxkeys.lpi` in Lazarus:

```text
Project → Open Project
```

The project uses `mxkeys.lpr` as its main program and is built as a console/CLI application.

The same shared HID++ implementation is used on Windows and Linux.

## Scope

This utility was written specifically for an **MX Keys S connected through a Logi Bolt receiver**.

It is intentionally small and does not attempt to replace Logitech Options+, Solaar or other device-management software. It checks the battery, warns when necessary, and exits.