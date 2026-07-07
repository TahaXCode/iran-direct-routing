<#
.SYNOPSIS
    Removes the Iran direct-routing rules added by Enable-IranDirect.ps1,
    sending all traffic (including Iranian) back through the VPN tunnel.
.NOTES
    Requires Administrator (self-elevates). Reads ir.cidr next to this script.
#>
param([switch]$Silent)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ListFile  = Join-Path $ScriptDir 'ir.cidr'

# --- Self-elevate to Administrator -----------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    if ($Silent) { throw 'This script must be run as Administrator.' }
    Start-Process powershell -Verb RunAs -ArgumentList `
        "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

if (-not (Test-Path $ListFile)) { throw "Iran IP list not found: $ListFile" }

# Physical adapter interface indexes (never touch the VPN interface)
$physIdx = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
             Select-Object -ExpandProperty InterfaceIndex)

$cidrs = Get-Content $ListFile |
         ForEach-Object { $_.Trim() } |
         Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}/\d{1,2}$' }

Write-Host "Removing $($cidrs.Count) Iran direct routes..." -ForegroundColor Cyan
$removed = 0
foreach ($cidr in $cidrs) {
    $routes = Get-NetRoute -DestinationPrefix $cidr -ErrorAction SilentlyContinue |
              Where-Object { $physIdx -contains $_.ifIndex }
    foreach ($r in $routes) {
        try { Remove-NetRoute -InputObject $r -Confirm:$false -ErrorAction Stop; $removed++ } catch {}
    }
}

Write-Host ''
Write-Host "Done. Removed $removed routes. All traffic goes through the VPN again." -ForegroundColor Green
if (-not $Silent) { Read-Host "`nPress Enter to close" }
