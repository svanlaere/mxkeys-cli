$ErrorActionPreference = 'Stop'

$TaskName = 'MX Keys Battery'
$InstallDir = Join-Path $env:LOCALAPPDATA 'MXKeysBattery'

Write-Host 'Uninstalling MX Keys Battery...'
Write-Host ''

# Remove the scheduled task if it exists.
$Task = Get-ScheduledTask `
    -TaskName $TaskName `
    -ErrorAction SilentlyContinue

if ($null -ne $Task) {
    Unregister-ScheduledTask `
        -TaskName $TaskName `
        -Confirm:$false
}

# Remove a legacy Startup-folder shortcut if one exists.
$StartupShortcut = Join-Path `
    $env:APPDATA `
    'Microsoft\Windows\Start Menu\Programs\Startup\MX Keys Battery.lnk'

if (Test-Path $StartupShortcut -PathType Leaf) {
    Remove-Item `
        -Path $StartupShortcut `
        -Force
}

# Remove the per-user installation directory.
if (Test-Path $InstallDir -PathType Container) {
    Remove-Item `
        -Path $InstallDir `
        -Recurse `
        -Force
}

Write-Host 'MX Keys Battery has been uninstalled.'