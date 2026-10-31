$ErrorActionPreference = 'Stop'

$TaskName = 'MX Keys Battery'
$InstallDir = Join-Path $env:LOCALAPPDATA 'MXKeysBattery'

# install.ps1 lives in:
#   installer\windows\powershell
#
# mxkeys.exe lives in the project root, three levels above.
$ProjectRoot = Split-Path (
    Split-Path (
        Split-Path $PSScriptRoot -Parent
    ) -Parent
) -Parent

$SourceExe = Join-Path $ProjectRoot 'mxkeys.exe'
$InstalledExe = Join-Path $InstallDir 'mxkeys.exe'
$Launcher = Join-Path $InstallDir 'run-hidden.vbs'

Write-Host 'Installing MX Keys Battery...'
Write-Host ''

# Verify that the compiled Windows executable exists.
if (-not (Test-Path $SourceExe -PathType Leaf)) {
    throw "mxkeys.exe was not found: $SourceExe"
}

# Create the per-user installation directory.
New-Item `
    -ItemType Directory `
    -Path $InstallDir `
    -Force | Out-Null

# Copy the executable.
Copy-Item `
    -Path $SourceExe `
    -Destination $InstalledExe `
    -Force

# Create an invisible launcher.
#
# mxkeys.exe remains a normal console application so commands such as
# --status and --list-hid can still be used interactively. WScript runs
# the automatic battery check without displaying a console window.
@'
Set shell = CreateObject("WScript.Shell")
shell.Run """" & CreateObject("WScript.Shell").ExpandEnvironmentStrings("%LOCALAPPDATA%\MXKeysBattery\mxkeys.exe") & """", 0, False
'@ | Set-Content `
    -Path $Launcher `
    -Encoding ASCII

# Remove the old Startup-folder shortcut if an earlier installation
# used that mechanism.
$StartupShortcut = Join-Path `
    $env:APPDATA `
    'Microsoft\Windows\Start Menu\Programs\Startup\MX Keys Battery.lnk'

if (Test-Path $StartupShortcut -PathType Leaf) {
    Remove-Item `
        -Path $StartupShortcut `
        -Force
}

# Create the scheduled-task action.
#
# Task Scheduler launches WScript, which starts mxkeys.exe invisibly.
$Action = New-ScheduledTaskAction `
    -Execute "$env:SystemRoot\System32\wscript.exe" `
    -Argument "`"$Launcher`""

# Run once whenever the current user logs on.
$Trigger = New-ScheduledTaskTrigger `
    -AtLogOn `
    -User $env:USERNAME

# Run inside the interactive user session without elevation.
# This allows desktop notifications to be displayed.
$Principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Limited

# Register or replace the task.
Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Principal $Principal `
    -Description 'Check MX Keys S battery level at Windows logon.' `
    -Force | Out-Null

Write-Host 'MX Keys Battery installed successfully.'
Write-Host ''
Write-Host 'The battery check will run automatically when you log on.'
Write-Host ''

& $InstalledExe --status