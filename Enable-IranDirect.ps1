<#
.SYNOPSIS
    Routes Iranian IP ranges DIRECTLY through your physical internet
    connection, bypassing the Windscribe VPN tunnel. All other traffic
    stays inside the tunnel. Lets you keep the VPN on permanently while
    Iranian sites (banking, gov, Aparat, Digikala, etc.) still work.

.DESCRIPTION
    Windscribe's own Split Tunneling does NOT support IKEv2, so this uses
    the Windows routing table instead. It adds a more-specific route for
    every Iranian CIDR block pointing at your real gateway. More-specific
    routes always win over the VPN's 0.0.0.0/0 default route, so Iranian
    traffic leaves through your ISP untouched.

    Reads the CIDR list from ir.cidr next to this script.
    Works with IKEv2 (or any Windscribe protocol).

.NOTES
    * Requires Administrator (self-elevates).
    * Windscribe's Firewall / kill-switch must be OFF while connected,
      otherwise it blocks the direct traffic. See README.md.
#>
param(
    [switch]$Silent,       # no pauses / no elevation prompt (used by the scheduled task)
    [int]$Metric = 1
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ListFile  = Join-Path $ScriptDir 'ir.cidr'

# --- Self-elevate to Administrator -----------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $isAdmin) {
    if ($Silent) { throw 'This script must be run as Administrator.' }
    Start-Process powershell -Verb RunAs -ArgumentList `
        "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# --- Find the physical (non-VPN) default gateway ---------------------------
function Get-PhysicalGateway {
    $physIdx = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
                 Where-Object { $_.Status -eq 'Up' } |
                 Select-Object -ExpandProperty InterfaceIndex)
    if (-not $physIdx) { throw 'No active physical network adapter found.' }
    $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
             Where-Object { $physIdx -contains $_.ifIndex -and $_.NextHop -ne '0.0.0.0' } |
             Sort-Object RouteMetric | Select-Object -First 1
    if (-not $route) { throw 'Could not find a physical default gateway. Connect to your network first.' }
    [PSCustomObject]@{ Gateway = $route.NextHop; IfIndex = [int]$route.ifIndex }
}

if (-not (Test-Path $ListFile)) {
    throw "Iran IP list not found: $ListFile  (run Update-IranList.ps1 first)"
}

$gw = Get-PhysicalGateway
Write-Host "Physical gateway : $($gw.Gateway)  (ifIndex $($gw.IfIndex))" -ForegroundColor Cyan

$cidrs = Get-Content $ListFile |
         ForEach-Object { $_.Trim() } |
         Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}/\d{1,2}$' }
Write-Host "Iran ranges      : $($cidrs.Count)" -ForegroundColor Cyan
Write-Host 'Adding direct routes (this takes ~30 seconds)...' -ForegroundColor Cyan

# Routes we already manage on this interface/gateway
$existing = @{}
Get-NetRoute -InterfaceIndex $gw.IfIndex -ErrorAction SilentlyContinue |
    Where-Object { $_.NextHop -eq $gw.Gateway } |
    ForEach-Object { $existing[$_.DestinationPrefix] = $true }

$added = 0; $skipped = 0; $failed = 0; $i = 0
foreach ($cidr in $cidrs) {
    $i++
    if ($existing.ContainsKey($cidr)) { $skipped++; continue }
    try {
        New-NetRoute -DestinationPrefix $cidr -InterfaceIndex $gw.IfIndex `
            -NextHop $gw.Gateway -RouteMetric $Metric -PolicyStore ActiveStore `
            -ErrorAction Stop | Out-Null
        $added++
    } catch { $failed++ }
    if (-not $Silent -and ($i % 250 -eq 0)) {
        Write-Host "  ...$i / $($cidrs.Count)" -ForegroundColor DarkGray
    }
}

Write-Host ''
Write-Host "Done. Added $added, already present $skipped, failed $failed." -ForegroundColor Green
Write-Host 'Iranian traffic now bypasses the VPN. Everything else stays tunneled.' -ForegroundColor Green
Write-Host ''
Write-Host 'REMINDER: Windscribe Firewall / kill-switch must be OFF for direct' -ForegroundColor Yellow
Write-Host '          traffic to pass. If Iranian sites still fail, that is why.' -ForegroundColor Yellow

if (-not $Silent) { Read-Host "`nPress Enter to close" }
