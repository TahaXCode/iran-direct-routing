<#
.SYNOPSIS
    Registers a scheduled task so the Iran direct routes are re-applied
    automatically at every startup and logon (routes live in the active
    routing table and are cleared on reboot). Runs silently as SYSTEM,
    so no UAC prompt appears each time.
#>
$ErrorActionPreference = 'Stop'
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnablePath = Join-Path $ScriptDir 'Enable-IranDirect.ps1'
$TaskName   = 'Windscribe-Iran-Direct'

# --- Self-elevate ----------------------------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Start-Process powershell -Verb RunAs -ArgumentList `
        "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

if (-not (Test-Path $EnablePath)) { throw "Enable-IranDirect.ps1 not found next to this script." }

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$EnablePath`" -Silent"

$triggers = @(
    (New-ScheduledTaskTrigger -AtStartup),
    (New-ScheduledTaskTrigger -AtLogOn)
)

$taskPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' `
    -LogonType ServiceAccount -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $triggers `
    -Principal $taskPrincipal -Settings $settings -Force `
    -Description 'Re-applies Iran direct-routing rules that bypass the Windscribe VPN.' | Out-Null

Write-Host "Scheduled task '$TaskName' installed." -ForegroundColor Green
Write-Host 'Iran routes will now be re-applied automatically at boot and logon.' -ForegroundColor Green
Write-Host 'Running it once now...' -ForegroundColor Cyan
Start-ScheduledTask -TaskName $TaskName
Read-Host "`nPress Enter to close"
