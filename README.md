# MX Keys CLI

A small Free Pascal/Lazarus utility for checking the battery level of a
**Logitech MX Keys S connected through a Logi Bolt receiver**.

The program runs once, checks the keyboard battery and exits. By default
it only shows a notification when the battery is at or below 10% and the
keyboard is discharging.

No Logitech software, HIDAPI, Solaar, daemon or continuously running
background process is required.

HID++ protocol handling is separated from the operating-system-specific
transport units.

## Usage

### Check battery status

``` text
mxkeys --status
```

Example:

``` text
Device: MX Keys S
Battery: 40%
State: discharging
```

For additional diagnostic information:

``` text
mxkeys --status --verbose
```

Example on Linux:

``` text
Device: MX Keys S
Battery: 40%
State: discharging
Slot: 1
Transport: /dev/hidraw2
```

On Windows the transport description will look similar to:

``` text
Transport: Windows HID (Usage Page $FF00, Usage $0002, input 20, output 20)
```

### Normal use

``` text
mxkeys
```

The default warning threshold is **10%**.

When the battery is above the threshold, the program produces no output
or notification and simply exits.

When the battery is at or below the threshold and the keyboard is
discharging, a desktop notification is shown.

### Override the threshold

``` text
mxkeys --threshold 15
```

This changes the threshold for that run only.

For example, to test the normal low-battery notification path while the
keyboard is at 40%:

``` text
mxkeys --threshold 50
```

### Test the notification

``` text
mxkeys --test-notification
```

This shows a notification regardless of the current battery percentage.

### HID diagnostics

``` text
mxkeys --list-hid
```

Lists relevant HID interfaces for diagnostic purposes.

## Linux

The Linux backend discovers the Logi Bolt C548 receiver dynamically and
selects the vendor HID collection advertising HID++ report IDs `0x10`
and `0x11`.

It does **not** hard-code `/dev/hidrawN`.

The Linux version is designed around standard Linux `hidraw`, udev, XDG
autostart and desktop notifications through `notify-send`.

It is currently tested on **Kubuntu with KDE Plasma**.

### Install

Build the Linux executable first, then run:

``` bash
./installer/linux/install.sh
```

The installer:

-   copies `mxkeys` to `~/.local/bin/mxkeys`;
-   creates an XDG autostart entry in `~/.config/autostart`;
-   installs the udev rule required to access the Logi Bolt HID++
    interface;
-   reloads the udev rules;
-   checks the current keyboard status.

The udev rule is the only part that requires `sudo`.

After installation the battery check runs automatically when you log on.
It checks the battery once and exits; it does not remain running in the
background.

### Uninstall

``` bash
./installer/linux/uninstall.sh
```

This removes the installed executable, autostart entry and udev rule.

### Manual installation

The installer performs the following setup.

The executable is installed as:

``` text
~/.local/bin/mxkeys
```

The XDG autostart entry is:

``` text
~/.config/autostart/mxkeys.desktop
```

The udev rule is:

``` text
/etc/udev/rules.d/70-mxkeys.rules
```

with:

``` text
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c548", TAG+="uaccess"
```

The rules can be reloaded manually with:

``` bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

The program should then be able to access the Bolt HID++ interface as
the logged-in desktop user without running the program itself with
`sudo`.

Linux notifications use the standard desktop notification system through
`notify-send`.

## Windows 11

The Windows backend uses the native Windows HID and SetupAPI interfaces.

It dynamically enumerates the Logi Bolt receiver and selects the HID++
collection using:

``` text
Usage Page: 0xFF00
Usage:      0x0002
Input:      20 bytes
Output:     20 bytes
```

HID communication uses bounded overlapped I/O so a missing HID response
cannot leave the program waiting indefinitely.

No Logitech software or additional HID library is required.

The Windows version is currently tested on **Windows 11**.

### Install

Build `mxkeys.exe` first, then run:

``` text
installer\windows\install.bat
```

The installer:

-   copies `mxkeys.exe` to `%LOCALAPPDATA%\MXKeysBattery`;
-   creates a small hidden launcher;
-   registers **MX Keys Battery** in Windows Task Scheduler for the
    current user;
-   runs a battery status check after installation.

The scheduled task runs when the user logs on. It launches the battery
check invisibly, so no console window is shown during the automatic
check.

The program checks the battery once and exits; it does not remain
running in the background.

No administrator privileges are required for the Windows installation.

### Uninstall

Run:

``` text
installer\windows\uninstall.bat
```

This removes the scheduled task and the files installed in
`%LOCALAPPDATA%\MXKeysBattery`.

The uninstaller also removes the legacy Startup-folder shortcut if one
exists from an older installation.

### PowerShell scripts

The batch files are simple frontends for the PowerShell installer and
uninstaller:

``` text
installer\windows\powershell\install.ps1
installer\windows\powershell\uninstall.ps1
```

They can also be inspected or run directly by users who prefer
PowerShell.

The installed CLI remains available at:

``` text
%LOCALAPPDATA%\MXKeysBattery\mxkeys.exe
```

For example:

``` powershell
& "$env:LOCALAPPDATA\MXKeysBattery\mxkeys.exe" --status
```

For diagnostic details:

``` powershell
& "$env:LOCALAPPDATA\MXKeysBattery\mxkeys.exe" --status --verbose
```

Windows notifications are displayed using the Windows PowerShell/.NET
notification facilities available on a normal Windows 11 installation.

## Protocol

`mxkeys_hidpp.pas` contains the shared Logitech HID++ 2.0
implementation.

It:

1.  probes receiver slots 1 through 6;
2.  resolves the Device Name feature (`0x0005`);
3.  verifies that the device is `MX Keys S`;
4.  resolves Unified Battery (`0x1004`) through ROOT at runtime;
5.  reads the battery percentage and charging state.

Identifying the device by name prevents another paired Logitech device
with battery support from being mistaken for the keyboard.

## Source layout

``` text
mxkeys.lpr
mxkeys.lpi
mxkeys_hidpp.pas
mxkeys_transport.pas
mxkeys_linux.pas
mxkeys_windows.pas
mxkeys_config.pas
mxkeys_notify.pas
mxkeys_notify_linux.pas
mxkeys_notify_windows.pas

installer/
├── linux/
│   ├── install.sh
│   └── uninstall.sh
└── windows/
    ├── install.bat
    ├── uninstall.bat
    └── powershell/
        ├── install.ps1
        └── uninstall.ps1
```

The shared HID++ code does not contain Linux or Windows transport
details. `mxkeys_transport.pas` selects the appropriate backend at
compile time.

## Lazarus project

Open `mxkeys.lpi` in Lazarus:

``` text
Project → Open Project
```

The project uses `mxkeys.lpr` as its main program and is built as a
console/CLI application.

The same shared HID++ implementation is used on Windows and Linux.

## Scope

This utility was written specifically for an **MX Keys S connected
through a Logi Bolt receiver**.

It is intentionally small and does not attempt to replace Logitech
Options+, Solaar or other device-management software.

It checks the battery, warns when necessary, and exits.

Linux support is currently tested on Kubuntu/KDE Plasma. Windows support
is currently tested on Windows 11. Other Linux distributions and desktop
environments may work when they provide the standard facilities used by
the application, but they have not currently been tested.
