<#
.SYNOPSIS
    Removes the 'Windscribe-Iran-Direct' scheduled task created by
    Install-AutoStart.ps1. (Does not remove any currently-active routes;
    run Disable-IranDirect.ps1 for that.)
#>
$ErrorActionPreference = 'Stop'
$TaskName = 'Windscribe-Iran-Direct'

$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Start-Process powershell -Verb RunAs -ArgumentList `
        "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Scheduled task '$TaskName' removed." -ForegroundColor Green
} else {
    Write-Host "Scheduled task '$TaskName' was not installed." -ForegroundColor Yellow
}
Read-Host "`nPress Enter to close"
